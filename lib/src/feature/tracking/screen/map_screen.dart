// lib/src/feature/tracking/screen/map_screen.dart

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';

import '../../../common/constants/app_constants.dart';
import '../../../common/model/location_point.dart';
import '../bloc/tracking_bloc.dart';
import '../widget/bottom_panel.dart';
import '../widget/compass_widget.dart';
import '../widget/navigation_icon_painter.dart';
import '../widget/top_status_bar.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  YandexMapController? _mapCtrl;
  bool   _mapReady        = false;
  bool   _initialZoomDone = false;
  Point? _pendingPoint;

  // Icon — compass + GPS dan mustaqil
  Uint8List? _iconBytes;
  double     _iconHeading  = -999;
  bool       _iconBuilding = false;
  double     _liveHeading  = 0;
  double     _liveSpeedKmh = 0;

  StreamSubscription<Position>?     _gpsSub;
  StreamSubscription<CompassEvent>? _compassSub;

  @override
  void initState() {
    super.initState();
    _buildIcon(0);
    _init();
  }

  @override
  void dispose() {
    _gpsSub?.cancel();
    _compassSub?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }

    if (mounted) {
      context.read<TrackingBloc>().add(const TrackingInitialized());
    }

    // Kompas — icon uchun
    _compassSub = FlutterCompass.events?.listen((e) {
      if (!mounted || e.heading == null) return;
      final h = (e.heading! + 360) % 360;
      if (_liveSpeedKmh <= 3.0) {
        _liveHeading = h;
        _scheduleIconUpdate(h);
        if (mounted) setState(() {});
      }
    });

    // GPS stream — icon pozitsiyasi va bloc livePoint uchun
    _gpsSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy:       LocationAccuracy.high,
        distanceFilter: 0,
      ),
    ).listen((pos) {
      if (!mounted) return;

      _liveSpeedKmh = pos.speed < 0 ? 0 : pos.speed * 3.6;

      if (_liveSpeedKmh > 3.0 && pos.heading >= 0) {
        _liveHeading = pos.heading;
        _scheduleIconUpdate(pos.heading);
      }

      // Bloc ga livePoint — bottom_panel uchun
      if (pos.accuracy <= kMaxAccuracyMeters) {
        context.read<TrackingBloc>().add(
          TrackingGpsUpdated(LocationPoint(
            latitude:  pos.latitude,
            longitude: pos.longitude,
            heading:   pos.heading < 0 ? 0.0 : pos.heading,
            speed:     pos.speed   < 0 ? 0.0 : pos.speed,
            accuracy:  pos.accuracy,
            timestamp: DateTime.now(),
          )),
        );
      }

      // Birinchi yaxshi signal → zoom
      if (!_initialZoomDone && pos.accuracy <= 50) {
        _initialZoomDone = true;
        final pt = Point(latitude: pos.latitude, longitude: pos.longitude);
        if (_mapReady) {
          _moveTo(pt, zoom: 17);
        } else {
          _pendingPoint = pt;
        }
      }

      if (mounted) setState(() {});
    });
  }

  void _scheduleIconUpdate(double heading) {
    final diff     = ((_iconHeading - heading) % 360).abs();
    final realDiff = diff > 180 ? 360 - diff : diff;
    if (realDiff < 1.0 && _iconBytes != null) return;
    if (_iconBuilding) return;
    _buildIcon(heading);
  }

  Future<void> _buildIcon(double heading) async {
    _iconBuilding = true;
    try {
      final bytes = await buildNavigationIcon(
        heading:    heading,
        size:       96,
        arrowColor: const Color(0xFF1565C0),
      );
      if (!mounted) return;
      setState(() {
        _iconBytes   = bytes;
        _iconHeading = heading;
      });
    } finally {
      _iconBuilding = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      body: BlocConsumer<TrackingBloc, TrackingState>(
        listenWhen: (p, c) =>
        p.followUser   != c.followUser   ||
            p.currentPoint != c.currentPoint ||
            p.status       != c.status,
        listener: (ctx, state) {
          if (!_mapReady || !state.followUser) return;
          final cur = state.currentPoint;
          if (cur == null) return;
          _moveTo(
            Point(latitude: cur.latitude, longitude: cur.longitude),
            zoom:    17,
            azimuth: _liveHeading,
          );
        },
        builder: (context, state) {
          return Stack(children: [
            YandexMap(
              mapObjects: _buildMapObjects(state),
              onMapCreated: (ctrl) async {
                _mapCtrl  = ctrl;
                _mapReady = true;
                if (_pendingPoint != null) {
                  await _moveTo(_pendingPoint!, zoom: 17);
                  _pendingPoint = null;
                } else if (!_initialZoomDone) {
                  await _moveTo(
                    const Point(latitude: 41.2995, longitude: 69.2401),
                    zoom: 12,
                  );
                }
              },
              onCameraPositionChanged: (_, __, isGesture) {
                if (isGesture && state.followUser) {
                  context
                      .read<TrackingBloc>()
                      .add(const TrackingFollowToggled());
                }
              },
            ),

            Positioned(top: 0, left: 0, right: 0,
                child: TopStatusBar(state: state)),

            Positioned(
              top: 120, right: 16,
              child: CompassWidget(
                heading:  _liveHeading,
                speedKmh: _liveSpeedKmh,
              ),
            ),

            Positioned(
              bottom: 280, right: 16,
              child: _FollowButton(
                active: state.followUser,
                onTap: () => context
                    .read<TrackingBloc>()
                    .add(const TrackingFollowToggled()),
              ),
            ),

            Positioned(bottom: 0, left: 0, right: 0,
                child: BottomPanel(state: state)),

            if (state.hasError && state.errorMessage != null)
              Positioned(
                top: 110, left: 16, right: 16,
                child: _ErrorBanner(message: state.errorMessage!),
              ),

            if (state.isLoading)
              const Positioned.fill(child: _LoadingOverlay()),
          ]);
        },
      ),
    );
  }

  List<MapObject> _buildMapObjects(TrackingState state) {
    final objects = <MapObject>[];

    if (state.points.length >= 2) {
      objects.add(PolylineMapObject(
        mapId:    const MapObjectId('track'),
        polyline: Polyline(
          points: state.points
              .map((p) => Point(latitude: p.latitude, longitude: p.longitude))
              .toList(),
        ),
        strokeColor:  const Color(kPolylineColor),
        strokeWidth:  kPolylineWidth,
        outlineColor: const Color(kOutlineColor),
        outlineWidth: 1.5,
        dashLength:   0,
        gapLength:    0,
      ));

      final start = state.points.first;
      objects.add(PlacemarkMapObject(
        mapId:   const MapObjectId('start'),
        point:   Point(latitude: start.latitude, longitude: start.longitude),
        opacity: 1.0,
        icon: PlacemarkIcon.single(PlacemarkIconStyle(
          image: BitmapDescriptor.fromAssetImage('assets/icons/start.png'),
          scale: 1.2,
        )),
      ));
    }

    final cur = state.currentPoint;
    if (cur != null && _iconBytes != null) {
      objects.add(PlacemarkMapObject(
        mapId:   const MapObjectId('user'),
        point:   Point(latitude: cur.latitude, longitude: cur.longitude),
        opacity: 1.0,
        icon: PlacemarkIcon.single(PlacemarkIconStyle(
          image:  BitmapDescriptor.fromBytes(_iconBytes!),
          scale:  1.0,
          anchor: const Offset(0.5, 0.5),
        )),
      ));
    }

    return objects;
  }

  Future<void> _moveTo(Point point,
      {double zoom = 17, double azimuth = 0}) async {
    await _mapCtrl?.moveCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: point, zoom: zoom, azimuth: azimuth),
      ),
      animation: const MapAnimation(
        type: MapAnimationType.smooth, duration: kCameraAnimDuration,
      ),
    );
  }
}

class _FollowButton extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;
  const _FollowButton({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 50, height: 50,
        decoration: BoxDecoration(
          color:        active ? const Color(0xFF1565C0) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 8, offset: const Offset(0, 3),
          )],
        ),
        child: Icon(
          active ? Icons.navigation_rounded : Icons.location_searching_rounded,
          color: active ? Colors.white : const Color(0xFF1565C0), size: 26,
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.red.shade700,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 10)],
      ),
      child: Row(children: [
        const Icon(Icons.error_outline, color: Colors.white, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(message,
            style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4))),
      ]),
    );
  }
}

class _LoadingOverlay extends StatelessWidget {
  const _LoadingOverlay();
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black45,
      child: const Center(
        child: Card(
          elevation: 8,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(16))),
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              CircularProgressIndicator(strokeWidth: 3),
              SizedBox(height: 16),
              Text('Yuklanmoqda...',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            ]),
          ),
        ),
      ),
    );
  }
}