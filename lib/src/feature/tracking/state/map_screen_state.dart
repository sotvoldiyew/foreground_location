
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:location_tracker/src/feature/tracking/screen/map_screen.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';

import '../../../common/constants/app_constants.dart';
import '../../../common/model/location_point.dart';
import '../bloc/tracking_bloc.dart';
import '../widget/navigation_icon_painter.dart';

abstract class MapScreenState extends State<MapScreen> with WidgetsBindingObserver {

  static MapScreenState? _instance;
  static MapScreenState? get instance => _instance;

  YandexMapController? mapCtrl;
  bool   mapReady        = false;
  bool   initialZoomDone = false;
  Point? pendingPoint;

  Uint8List? iconBytes;
  double     iconHeading  = -999;
  bool       iconBuilding = false;

  double liveHeading  = 0;
  double liveSpeedKmh = 0;

 LocationPoint? livePoint;

 final Map<int, Uint8List> arrowIconCache = {};
  bool arrowIconBuilding = false;

  bool   isAnimating   = false;
  double cameraAzimuth = 0;

  StreamSubscription<Position>?     gpsSub;
  StreamSubscription<CompassEvent>? compassSub;

  @override
  void initState() {
    super.initState();
    _instance = this;
    WidgetsBinding.instance.addObserver(this);
    buildIcon(0);
    init();
  }

  @override
  void dispose() {
    if (_instance == this) _instance = null;
    WidgetsBinding.instance.removeObserver(this);
    gpsSub?.cancel();
    compassSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<TrackingBloc>().add(const TrackingInitialized());
    }
  }

  Future<void> init() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (mounted) {
      context.read<TrackingBloc>().add(const TrackingInitialized());
    }

    compassSub = FlutterCompass.events?.listen((e) {
      if (!mounted || e.heading == null) return;
      final h = (e.heading! + 360) % 360;
      if (liveSpeedKmh <= 3.0) {
        liveHeading = h;
        final corrected = (h - cameraAzimuth + 360) % 360;
        scheduleIconUpdate(corrected);
        if (mounted) setState(() {});
      }
    });

    gpsSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy:       LocationAccuracy.high,
        distanceFilter: 0,
      ),
    ).listen((pos) {
      if (!mounted) return;

      liveSpeedKmh = pos.speed < 0 ? 0.0 : pos.speed * 3.6;

      if (liveSpeedKmh > 3.0 && pos.heading >= 0) {
        liveHeading = pos.heading;
        final corrected = (pos.heading - cameraAzimuth + 360) % 360;
        scheduleIconUpdate(corrected);
      }

      if (pos.accuracy <= kMaxAccuracyMeters) {
        final point = LocationPoint(
          latitude:  pos.latitude,
          longitude: pos.longitude,
          heading:   pos.heading < 0 ? 0.0 : pos.heading,
          speed:     pos.speed   < 0 ? 0.0 : pos.speed,
          accuracy:  pos.accuracy,
          timestamp: DateTime.now(),
        );
        livePoint = point;
        context.read<TrackingBloc>().add(TrackingGpsUpdated(point));
      }

      if (!initialZoomDone && pos.accuracy <= 50) {
        initialZoomDone = true;
        final pt = Point(latitude: pos.latitude, longitude: pos.longitude);
        if (mapReady) {
          moveTo(pt, zoom: 17);
        } else {
          pendingPoint = pt;
        }
      }

      if (mounted) setState(() {});
    });
  }

 void scheduleIconUpdate(double heading) {
    final diff     = ((iconHeading - heading) % 360).abs();
    final realDiff = diff > 180 ? 360 - diff : diff;
    if (realDiff < 1.0 && iconBytes != null) return;
    if (iconBuilding) return;
    buildIcon(heading);
  }

  Future<void> buildIcon(double heading) async {
    iconBuilding = true;
    try {
      final bytes = await buildNavigationIcon(
        heading:    heading,
        size:       96,
        arrowColor: const Color(0xFF1565C0),
      );
      if (!mounted) return;
      setState(() {
        iconBytes   = bytes;
        iconHeading = heading;
      });
    } finally {
      iconBuilding = false;
    }
  }

  Future<void> buildArrowIcons(List<double> bearings) async {
    if (arrowIconBuilding) return;
    arrowIconBuilding = true;
    try {
      bool anyNew = false;
      for (final bearing in bearings) {
        final rounded = (bearing / 5).round() * 5;
        if (arrowIconCache.containsKey(rounded)) continue;
        final bytes = await buildArrowIcon(
          bearing:    rounded.toDouble(),
          size:       64,
          arrowColor: const Color(0xFF1565C0),
        );
        arrowIconCache[rounded] = bytes;
        anyNew = true;
      }
      if (anyNew && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() {});
        });
      }
    } finally {
      arrowIconBuilding = false;
    }
  }

  double calculateBearing(double lat1, double lon1, double lat2, double lon2) {
    final dLon = (lon2 - lon1) * math.pi / 180;
    final l1   = lat1 * math.pi / 180;
    final l2   = lat2 * math.pi / 180;
    final y    = math.sin(dLon) * math.cos(l2);
    final x    = math.cos(l1) * math.sin(l2) -
        math.sin(l1) * math.cos(l2) * math.cos(dLon);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  double haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const R    = 6371000.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;
    final a    = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLon / 2) * math.sin(dLon / 2);
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  Future<void> moveTo(Point point, {double zoom = 17, double azimuth = 0}) async {
    isAnimating = true;
    await mapCtrl?.moveCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: point, zoom: zoom, azimuth: azimuth),
      ),
      animation: const MapAnimation(
        type:     MapAnimationType.smooth,
        duration: kCameraAnimDuration,
      ),
    );
    Future.delayed(
      const Duration(milliseconds: 600),
      () => isAnimating = false,
    );
  }
}
