import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';

import '../constants/app_constants.dart';
import '../model/location_point.dart';
import 'background_service.dart';
import 'location_storage.dart';

const double kMaxSpeedMps = 100.0;


class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  final _ctrl     = StreamController<List<LocationPoint>>.broadcast();
  Stream<List<LocationPoint>> get stream => _ctrl.stream;

  final _liveCtrl = StreamController<LocationPoint>.broadcast();
  Stream<LocationPoint> get liveStream => _liveCtrl.stream;

  StreamSubscription<Position>? _iosSub;
  StreamSubscription<Position>? _androidUiSub;
  StreamSubscription?           _bgServiceSub;

  final List<LocationPoint> _points = [];
  LocationPoint? _lastSaved;
  bool _running           = false;
  bool _androidConfigured = false;
  bool _initialized       = false;

  bool get isRunning => _running;
  List<LocationPoint> get points => List.unmodifiable(_points);

  Future<void> init() async {
    debugPrint('🔧 [UI] init()');

    if (defaultTargetPlatform == TargetPlatform.android) {
      await _configureAndroid();

      final svc            = FlutterBackgroundService();
      final alreadyRunning = await svc.isRunning();

      if (alreadyRunning) {
        debugPrint('✅ [UI] Service ishlayapti — davom ettirilmoqda');
        _running = true;

        final saved = await LocationStorage.instance.load();
        if (saved.isNotEmpty) {
          _points.clear();
          _points.addAll(saved);
          _lastSaved = _points.last;
          if (!_ctrl.isClosed) _ctrl.add(List.unmodifiable(_points));
          debugPrint('🔄 [UI] ${_points.length} saqlangan nuqta yuklandi');
        }

        _listenBgService(svc);
        _startAndroidUiStream();
        _initialized = true;
        return;
      }
    }

    await LocationStorage.instance.setRunning(false);
    final saved = await LocationStorage.instance.load();
    if (saved.isNotEmpty) {
      _points.addAll(saved);
      if (!_ctrl.isClosed) _ctrl.add(List.unmodifiable(_points));
      debugPrint('🔄 [UI] ${_points.length} saqlangan nuqta (stopped)');
    }

    _initialized = true;
  }

  Future<void> onResume() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    debugPrint('📱 [UI] onResume()');

    final svc     = FlutterBackgroundService();
    final running = await svc.isRunning();

    if (running && !_running) {
      debugPrint('🔄 [UI] Service hali ishlayapti — qayta ulamoqda');
      _running = true;

      final saved = await LocationStorage.instance.load();
      if (saved.isNotEmpty) {
        _points.clear();
        _points.addAll(saved);
        _lastSaved = _points.last;
        if (!_ctrl.isClosed) _ctrl.add(List.unmodifiable(_points));
      }

      _listenBgService(svc);
      _startAndroidUiStream();
    } else if (!running && _running) {
      debugPrint('⚠️ [UI] Service to\'xtagan — state reset');
      _running = false;
      await _bgServiceSub?.cancel();
      await _androidUiSub?.cancel();
      _bgServiceSub = null;
      _androidUiSub = null;
    }
  }

  bool _isJump(LocationPoint point) {
    if (_lastSaved == null) return false;
    final dist = _haversine(
      _lastSaved!.latitude, _lastSaved!.longitude,
      point.latitude,       point.longitude,
    );
    final timeDiff = point.timestamp
        .difference(_lastSaved!.timestamp)
        .inMilliseconds / 1000.0;
    if (timeDiff <= 0) return false;
    final speedMps = dist / timeDiff;
    if (speedMps > kMaxSpeedMps) {
      debugPrint('⚠️ GPS sakrash: ${speedMps.toStringAsFixed(1)} m/s — o\'tkazildi');
      return true;
    }
    return false;
  }

  void _listenBgService(FlutterBackgroundService svc) {
    _bgServiceSub?.cancel();
    _bgServiceSub = svc.on(kEvtLocationUpdate).listen((data) {
      if (data == null) return;
      try {
        final point = LocationPoint.fromMap(Map<String, dynamic>.from(data));

        if (point.latitude == 0.0 && point.longitude == 0.0) return;

        if (_points.isNotEmpty) {
          final last = _points.last;
          if (last.latitude  == point.latitude &&
              last.longitude == point.longitude) return;
        }

        if (_isJump(point)) return;

        _lastSaved = point;
        _points.add(point);
        if (_points.length > kMaxPoints) _points.removeAt(0);
        if (!_ctrl.isClosed) _ctrl.add(List.unmodifiable(_points));
        debugPrint('📍 [BG→UI] [${_points.length}] '
            '${point.latitude.toStringAsFixed(5)}, '
            '${point.longitude.toStringAsFixed(5)}');
      } catch (e) {
        debugPrint('❌ [UI] BG parse xato: $e');
      }
    });
    debugPrint('👂 [UI] BG service tinglash boshlandi');
  }

  void _startAndroidUiStream() {
    _androidUiSub?.cancel();
    _androidUiSub = Geolocator.getPositionStream(
      locationSettings: AndroidSettings(
        accuracy:         LocationAccuracy.high,
        distanceFilter:   0,
        intervalDuration: const Duration(milliseconds: 500),
      ),
    ).listen((pos) {
      if (!_running) return;
      if (pos.accuracy > kMaxAccuracyMeters) return;
      if (pos.latitude == 0.0 && pos.longitude == 0.0) return;

      final point = LocationPoint(
        latitude:  pos.latitude,
        longitude: pos.longitude,
        heading:   pos.heading < 0 ? 0.0 : pos.heading,
        speed:     pos.speed   < 0 ? 0.0 : pos.speed,
        accuracy:  pos.accuracy,
        timestamp: DateTime.now(),
      );

      if (!_liveCtrl.isClosed) _liveCtrl.add(point);
    });
    debugPrint('📡 [UI] Android live GPS stream boshlandi');
  }

  Future<void> _configureAndroid() async {
    if (_androidConfigured) return;
    await FlutterBackgroundService().configure(
      androidConfiguration: AndroidConfiguration(
        onStart:                         onServiceStart,
        isForegroundMode:                true,
        autoStart:                       false,
        autoStartOnBoot:                 false,
        notificationChannelId:           kNotifChannel,
        foregroundServiceNotificationId: kNotifId,
        initialNotificationTitle:        '🟢 Joylashuv kuzatilmoqda',
        initialNotificationContent:      '"Boshlash" ni bosing',
        foregroundServiceTypes:          [AndroidForegroundType.location],
      ),
      iosConfiguration: IosConfiguration(
        onForeground: onServiceStart,
        onBackground: onIosBackground,
        autoStart:    false,
      ),
    );
    _androidConfigured = true;
    debugPrint('🔧 [UI] Android configured');
  }

  Future<bool> start() async {
    if (_running) return true;

    final ok = await _requestPermissions();
    if (!ok) return false;

    _points.clear();
    _lastSaved = null;
    await LocationStorage.instance.clear();
    await LocationStorage.instance.setRunning(true);

    if (defaultTargetPlatform == TargetPlatform.android) {
      await _startAndroid();
    } else {
      await _startIos();
    }

    _running = true;
    debugPrint('▶️ [UI] Started');
    return true;
  }

  Future<void> stop() async {
    debugPrint('⏹️ [UI] stop()');
    _running = false;

    if (defaultTargetPlatform == TargetPlatform.android) {
      FlutterBackgroundService().invoke(kEvtStop);
      await _bgServiceSub?.cancel();
      await _androidUiSub?.cancel();
      _bgServiceSub = null;
      _androidUiSub = null;
    } else {
      await _iosSub?.cancel();
      _iosSub = null;
    }

    await LocationStorage.instance.setRunning(false);
    debugPrint('⏹️ [UI] Stopped');
  }

  Future<void> _startAndroid() async {
    final svc = FlutterBackgroundService();
    await svc.startService();
    debugPrint('🔧 [UI] startService() ok');
    _listenBgService(svc);
    _startAndroidUiStream();
  }

  Future<void> _startIos() async {
    await _iosSub?.cancel();
    _iosSub = Geolocator.getPositionStream(
      locationSettings: AppleSettings(
        accuracy:                          LocationAccuracy.bestForNavigation,
        distanceFilter:                    kDistanceFilterMeters,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator:   true,
        activityType:                      ActivityType.fitness,
      ),
    ).listen(
      _onIosPosition,
      onError: (e) => debugPrint('❌ [UI] iOS GPS xato: $e'),
      cancelOnError: false,
    );
    debugPrint('📡 [UI] iOS GPS boshlandi');
  }

  void _onIosPosition(Position pos) {
    if (!_running) return;
    if (pos.accuracy > kMaxAccuracyMeters) return;

    final point = LocationPoint(
      latitude:  pos.latitude,
      longitude: pos.longitude,
      heading:   pos.heading < 0 ? 0.0 : pos.heading,
      speed:     pos.speed   < 0 ? 0.0 : pos.speed,
      accuracy:  pos.accuracy,
      timestamp: DateTime.now(),
    );

    if (_lastSaved != null) {
      final dist = _haversine(
        _lastSaved!.latitude, _lastSaved!.longitude,
        point.latitude,       point.longitude,
      );
      if (dist < kMinDistanceMeters) return;
    }

    if (_isJump(point)) return;

    _lastSaved = point;
    _points.add(point);
    if (_points.length > kMaxPoints) _points.removeAt(0);

    LocationStorage.instance.save(List.of(_points));
    if (!_ctrl.isClosed) _ctrl.add(List.unmodifiable(_points));
    if (!_liveCtrl.isClosed) _liveCtrl.add(point);

    debugPrint('✅ [UI] iOS [${_points.length}] '
        '${point.latitude.toStringAsFixed(5)}, '
        '${point.longitude.toStringAsFixed(5)}');
  }

  void dispose() {
    _iosSub?.cancel();
    _bgServiceSub?.cancel();
    _androidUiSub?.cancel();
    _ctrl.close();
    _liveCtrl.close();
  }
}

double _haversine(double lat1, double lon1, double lat2, double lon2) {
  const R    = 6371000.0;
  final dLat = (lat2 - lat1) * math.pi / 180;
  final dLon = (lon2 - lon1) * math.pi / 180;
  final a    = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1 * math.pi / 180) *
          math.cos(lat2 * math.pi / 180) *
          math.sin(dLon / 2) * math.sin(dLon / 2);
  return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

Future<bool> _requestPermissions() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    debugPrint('❌ [UI] GPS o\'chirilgan');
    return false;
  }
  var perm = await Geolocator.checkPermission();
  if (perm == LocationPermission.denied) {
    perm = await Geolocator.requestPermission();
  }
  if (perm == LocationPermission.denied ||
      perm == LocationPermission.deniedForever) {
    debugPrint('❌ [UI] GPS ruxsati yo\'q: $perm');
    return false;
  }
  return true;
}