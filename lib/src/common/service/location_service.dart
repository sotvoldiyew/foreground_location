// lib/src/common/service/location_service.dart

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';

import '../constants/app_constants.dart';
import '../model/location_point.dart';
import 'location_storage.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ANDROID BACKGROUND ISOLATE
// ─────────────────────────────────────────────────────────────────────────────

@pragma('vm:entry-point')
Future<void> onAndroidServiceStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  debugPrint('🚀 [BG] Android background isolate started');

  if (service is AndroidServiceInstance) {
    await service.setAsForegroundService();
    await service.setForegroundNotificationInfo(
      title: '🟢 Joylashuv kuzatilmoqda',
      content: 'GPS signal kutilmoqda...',
    );
    debugPrint('🔔 [BG] Foreground notification ko\'rsatildi');
  }

  bool shouldRun = true;

  service.on(kEvtStop).listen((_) async {
    debugPrint('⏹️ [BG] Stop event keldi');
    shouldRun = false;
    await LocationStorage.instance.setRunning(false);
    service.stopSelf();
  });

  await LocationStorage.instance.clear();
  final points   = <LocationPoint>[];
  LocationPoint? lastSaved;

  debugPrint('📡 [BG] GPS stream boshlanmoqda...');

  StreamSubscription<Position>? gpsSub;

  gpsSub = Geolocator.getPositionStream(
    locationSettings: AndroidSettings(
      accuracy:         LocationAccuracy.high,
      distanceFilter:   kDistanceFilterMeters,
      intervalDuration: const Duration(seconds: 1),
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationChannelName: kNotifChannelName,
        notificationTitle:       '🟢 Joylashuv kuzatilmoqda',
        notificationText:        'GPS yozilmoqda...',
        enableWakeLock:          true,
        enableWifiLock:          true,
        setOngoing:              true,
      ),
    ),
  ).listen(
        (pos) async {
      if (!shouldRun) {
        await gpsSub?.cancel();
        return;
      }

      final speedKmh = pos.speed < 0 ? 0.0 : pos.speed * 3.6;
      debugPrint('📡 [BG] GPS: ${pos.latitude.toStringAsFixed(5)}, '
          '${pos.longitude.toStringAsFixed(5)} '
          'acc=±${pos.accuracy.toStringAsFixed(0)}m '
          'spd=${speedKmh.toStringAsFixed(1)}km/h');

      if (pos.accuracy > kMaxAccuracyMeters) {
        debugPrint('⚠️ [BG] Yomon signal — skip');
        return;
      }

      final point = LocationPoint(
        latitude:  pos.latitude,
        longitude: pos.longitude,
        heading:   pos.heading < 0 ? 0.0 : pos.heading,
        speed:     pos.speed   < 0 ? 0.0 : pos.speed,
        accuracy:  pos.accuracy,
        timestamp: DateTime.now(),
      );

      if (lastSaved != null) {
        final dist = _haversine(
          lastSaved!.latitude, lastSaved!.longitude,
          point.latitude,      point.longitude,
        );
        if (dist < kMinDistanceMeters) {
          debugPrint('📌 [BG] Joyida (${dist.toStringAsFixed(1)}m) — skip');
          return;
        }
      }

      lastSaved = point;
      points.add(point);
      if (points.length > kMaxPoints) points.removeAt(0);

      await LocationStorage.instance.save(List.of(points));
      service.invoke(kEvtLocationUpdate, point.toMap());

      if (service is AndroidServiceInstance) {
        await service.setForegroundNotificationInfo(
          title: '🟢 Joylashuv kuzatilmoqda',
          content: '${speedKmh.toStringAsFixed(0)} km/h  •  '
              '${point.headingLabel}  •  ${points.length} nuqta',
        );
      }

      debugPrint('✅ [BG] [${points.length}] '
          '${point.latitude.toStringAsFixed(5)}, '
          '${point.longitude.toStringAsFixed(5)}');
    },
    onError: (e) => debugPrint('❌ [BG] GPS xato: $e'),
    cancelOnError: false,
  );

  debugPrint('👂 [BG] GPS stream tinglash boshlandi');
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  return true;
}

// ─────────────────────────────────────────────────────────────────────────────
// LocationService — UI (asosiy isolate)
// ─────────────────────────────────────────────────────────────────────────────

class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  final _ctrl = StreamController<List<LocationPoint>>.broadcast();
  Stream<List<LocationPoint>> get stream => _ctrl.stream;

  StreamSubscription<Position>? _iosSub;
  StreamSubscription?           _androidSub;

  final List<LocationPoint> _points = [];
  LocationPoint? _lastSaved;
  bool _running           = false;
  bool _androidConfigured = false;

  bool get isRunning => _running;
  List<LocationPoint> get points => List.unmodifiable(_points);

  Future<void> init() async {
    debugPrint('🔧 [UI] LocationService.init()');

    if (defaultTargetPlatform == TargetPlatform.android) {
      await _configureAndroid();

      // Android da service hali ishlayotgan bo'lsa to'xtatish
      // (oldingi session crash bo'lgan bo'lishi mumkin)
      final svc = FlutterBackgroundService();
      final alreadyRunning = await svc.isRunning();
      if (alreadyRunning) {
        debugPrint('⚠️ [UI] Init: service allaqachon ishlayapti — to\'xtatilmoqda');
        svc.invoke(kEvtStop);
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    // Storage ni tozalash — har safar app ochilganda "stopped" holatdan boshla
    await LocationStorage.instance.setRunning(false);
    debugPrint('🔧 [UI] Running flag = false (reset)');

    // Oldingi sessiya nuqtalarini yuklash (ko'rsatish uchun, kuzatuv emas)
    final saved = await LocationStorage.instance.load();
    if (saved.isNotEmpty) {
      _points.addAll(saved);
      if (!_ctrl.isClosed) _ctrl.add(List.unmodifiable(_points));
      debugPrint('🔄 [UI] ${_points.length} oldingi nuqta yuklandi (display uchun)');
    }

    debugPrint('🔧 [UI] LocationService.init() done — foydalanuvchi Boshlash bossin');
  }

  Future<void> _configureAndroid() async {
    if (_androidConfigured) return;
    await FlutterBackgroundService().configure(
      androidConfiguration: AndroidConfiguration(
        onStart:                         onAndroidServiceStart,
        isForegroundMode:                true,
        autoStart:                       false,
        notificationChannelId:           kNotifChannel,
        foregroundServiceNotificationId: kNotifId,
        initialNotificationTitle:        '🟢 Joylashuv kuzatilmoqda',
        initialNotificationContent:      'GPS tayyor',
        foregroundServiceTypes:          [AndroidForegroundType.location],
      ),
      iosConfiguration: IosConfiguration(autoStart: false),
    );
    _androidConfigured = true;
    debugPrint('🔧 [UI] Android service configured');
  }

  Future<bool> start() async {
    if (_running) {
      debugPrint('⚠️ [UI] Allaqachon ishlayapti');
      return true;
    }

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
    debugPrint('▶️ [UI] LocationService started');
    return true;
  }

  Future<void> stop() async {
    debugPrint('⏹️ [UI] stop()');
    _running = false;

    if (defaultTargetPlatform == TargetPlatform.android) {
      FlutterBackgroundService().invoke(kEvtStop);
      await _androidSub?.cancel();
      _androidSub = null;
      debugPrint('⏹️ [UI] Android service stop event yuborildi');
    } else {
      await _iosSub?.cancel();
      _iosSub = null;
      debugPrint('⏹️ [UI] iOS GPS stream to\'xtatildi');
    }

    await LocationStorage.instance.setRunning(false);
  }

  // ── iOS ───────────────────────────────────────────────────────────────────

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
    debugPrint('📡 [UI] iOS GPS stream boshlandi');
  }

  void _onIosPosition(Position pos) {
    final speedKmh = pos.speed < 0 ? 0.0 : pos.speed * 3.6;
    debugPrint('📡 [UI] iOS: ${pos.latitude.toStringAsFixed(5)}, '
        '${pos.longitude.toStringAsFixed(5)} '
        'acc=±${pos.accuracy.toStringAsFixed(0)}m '
        'spd=${speedKmh.toStringAsFixed(1)}km/h');

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

    _lastSaved = point;
    _points.add(point);
    if (_points.length > kMaxPoints) _points.removeAt(0);

    LocationStorage.instance.save(List.of(_points));
    if (!_ctrl.isClosed) _ctrl.add(List.unmodifiable(_points));

    debugPrint('✅ [UI] iOS [${_points.length}] '
        '${point.latitude.toStringAsFixed(5)}, '
        '${point.longitude.toStringAsFixed(5)}');
  }

  // ── Android ───────────────────────────────────────────────────────────────

  Future<void> _startAndroid() async {
    await _androidSub?.cancel();
    _androidSub = null;

    final svc = FlutterBackgroundService();
    final ok  = await svc.startService();
    debugPrint('🔧 [UI] startService() => $ok');

    await Future.delayed(const Duration(milliseconds: 800));

    final running = await svc.isRunning();
    debugPrint('🔧 [UI] isRunning after 800ms: $running');

    if (!running) {
      debugPrint('❌ [UI] Service ishga tushmadi!');
    }

    _androidSub = svc.on(kEvtLocationUpdate).listen((data) async {
      if (data == null) return;
      final pts = await LocationStorage.instance.load();
      if (pts.isEmpty) return;
      _points.clear();
      _points.addAll(pts);
      if (!_ctrl.isClosed) _ctrl.add(List.unmodifiable(_points));
      debugPrint('📨 [UI] ${_points.length} nuqta → UI');
    });

    debugPrint('👂 [UI] Android event listener tayyor');
  }

  void dispose() {
    _iosSub?.cancel();
    _androidSub?.cancel();
    _ctrl.close();
  }
}

// ─────────────────────────────────────────────────────────────────────────────

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
  debugPrint('✅ [UI] GPS ruxsati: $perm');
  return true;
}