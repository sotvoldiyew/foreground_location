// lib/src/common/service/background_service.dart

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:location_tracker/src/common/service/notification_service.dart';

import '../constants/app_constants.dart';
import '../model/location_point.dart';
import 'location_storage.dart';

@pragma('vm:entry-point')
Future<void> onServiceStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  // await NotificationService.instance.initForIsolate();

  if (service is AndroidServiceInstance) {
    await service.setAsForegroundService();
    service.on(kEvtSetForeground).listen((_) => service.setAsForegroundService());
    service.on(kEvtSetBackground).listen((_) => service.setAsBackgroundService());
  }

  bool shouldRun = true;
  service.on(kEvtStop).listen((_) async {
    shouldRun = false;
    await NotificationService.instance.cancel();
    await LocationStorage.instance.setRunning(false);
    service.stopSelf();
    debugPrint('⏹️ Service to\'xtatildi');
  });

  // Yangi sessiya — eski nuqtalarni o'chir
  await LocationStorage.instance.clear();
  final List<LocationPoint> points = [];
  LocationPoint? lastSaved;

  debugPrint('🚀 BgService boshlandi — yangi sessiya');

  await for (final pos in Geolocator.getPositionStream(
    locationSettings: _buildLocationSettings(),
  )) {
    if (!shouldRun) break;

    final speedKmh = pos.speed < 0 ? 0.0 : pos.speed * 3.6;
    debugPrint(
      '📡 GPS: lat=${pos.latitude.toStringAsFixed(6)} '
          'lng=${pos.longitude.toStringAsFixed(6)} '
          'acc=±${pos.accuracy.toStringAsFixed(1)}m '
          'spd=${speedKmh.toStringAsFixed(1)}km/h',
    );

    // Accuracy filtri
    if (pos.accuracy > kMaxAccuracyMeters) {
      debugPrint('⚠️ Yomon signal (${pos.accuracy.toStringAsFixed(1)}m) — skip');
      continue;
    }

    final point = LocationPoint(
      latitude:  pos.latitude,
      longitude: pos.longitude,
      heading:   pos.heading < 0 ? 0.0 : pos.heading,
      speed:     pos.speed   < 0 ? 0.0 : pos.speed,
      accuracy:  pos.accuracy,
      timestamp: DateTime.now(),
    );

    // Minimum masofa filtri
    if (lastSaved != null) {
      final dist = _haversine(
        lastSaved.latitude, lastSaved.longitude,
        point.latitude,     point.longitude,
      );
      if (dist < kMinDistanceMeters) {
        debugPrint('📌 Joyida (${dist.toStringAsFixed(1)}m) — skip');
        continue;
      }
    }

    lastSaved = point;
    points.add(point);
    if (points.length > kMaxPoints) {
      points.removeAt(0);
    }

    // Storage ga saqlash
    await LocationStorage.instance.save(points);

    // Notification yangilash
    // await NotificationService.instance.showTracking(point, points.length);

    // UI ga event yuborish — to'liq nuqtalar ro'yxati bilan
    service.invoke(kEvtLocationUpdate, {
      'count': points.length,
      'last':  point.toMap(),
    });

    debugPrint('✅ [${points.length}] ${point.latitude.toStringAsFixed(6)}, '
        '${point.longitude.toStringAsFixed(6)} | '
        '±${point.accuracy.toStringAsFixed(0)}m | '
        '${speedKmh.toStringAsFixed(1)}km/h');
  }

  debugPrint('🔚 GPS stream tugadi');
}

double _haversine(double lat1, double lon1, double lat2, double lon2) {
  const R    = 6371000.0;
  final dLat = (lat2 - lat1) * math.pi / 180;
  final dLon = (lon2 - lon1) * math.pi / 180;
  final a    = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1 * math.pi / 180) *
          math.cos(lat2 * math.pi / 180) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  return true;
}

LocationSettings _buildLocationSettings() {
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    return AppleSettings(
      accuracy:                          LocationAccuracy.bestForNavigation,
      distanceFilter:                    kDistanceFilterMeters,
      pauseLocationUpdatesAutomatically: false,
      showBackgroundLocationIndicator:   true,
      activityType:                      ActivityType.fitness,
    );
  }
  return AndroidSettings(
    accuracy:         LocationAccuracy.high,
    distanceFilter:   kDistanceFilterMeters,
    intervalDuration: const Duration(seconds: 1),
    foregroundNotificationConfig: const ForegroundNotificationConfig(
      notificationChannelName: kNotifChannelName,
      notificationTitle:       '🟢 Joylashuv kuzatilmoqda',
      notificationText:        'Fon rejimida ishlayapti...',
      enableWakeLock:          true,
      enableWifiLock:          true,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// BgService — UI tomonida ishlatiladi
// ─────────────────────────────────────────────────────────────────────────────

class BgService {
  BgService._();
  static final BgService instance = BgService._();

  final _flutter = FlutterBackgroundService();

  // Stream controller — bloc ga nuqtalar uzatadi
  final _ctrl = StreamController<List<LocationPoint>>.broadcast();
  Stream<List<LocationPoint>> get stream => _ctrl.stream;

  StreamSubscription? _eventSub;

  Future<void> init() async {
    await _flutter.configure(
      androidConfiguration: AndroidConfiguration(
        onStart:                         onServiceStart,
        isForegroundMode:                true,
        autoStart:                       false,
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
    debugPrint('🔧 BgService.init() tayyor');
  }

  Future<bool> start() async {
    final ok = await _requestPermissions();
    if (!ok) {
      debugPrint('❌ GPS ruxsati yo\'q');
      return false;
    }

    // Eski subscription bekor qilish
    await _eventSub?.cancel();
    _eventSub = null;

    await _flutter.startService();
    await LocationStorage.instance.setRunning(true);

    // Service ishga tushishi uchun kut, keyin tinglash
    await Future.delayed(const Duration(milliseconds: 600));
    _startListening();

    debugPrint('▶️ BgService.start() OK');
    return true;
  }

  Future<void> stop() async {
    _flutter.invoke(kEvtStop);
    await LocationStorage.instance.setRunning(false);
    await _eventSub?.cancel();
    _eventSub = null;
    debugPrint('⏹️ BgService.stop()');
  }

  Future<bool> get isRunning => _flutter.isRunning();

  /// App qayta ochilganda storage dan nuqtalarni yuklaydi
  Future<void> reloadPoints() async {
    final pts = await LocationStorage.instance.load();
    if (pts.isNotEmpty) {
      _ctrl.add(pts);
      debugPrint('🔄 reloadPoints: ${pts.length} nuqta');
    }
    // Tinglashni ham boshlash
    await _eventSub?.cancel();
    _eventSub = null;
    _startListening();
  }

  void _startListening() {
    if (_eventSub != null) return;

    _eventSub = _flutter.on(kEvtLocationUpdate).listen((data) async {
      if (data == null) {
        debugPrint('⚠️ Event null keldi');
        return;
      }
      // Storage dan to'liq ro'yxatni o'qish
      final pts = await LocationStorage.instance.load();
      debugPrint('📨 Event → storage: ${pts.length} nuqta → stream ga');
      if (!_ctrl.isClosed) {
        _ctrl.add(pts);
      }
    });

    debugPrint('👂 BgService tinglash boshlandi');
  }

  void dispose() {
    _eventSub?.cancel();
    _ctrl.close();
  }
}

Future<bool> _requestPermissions() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    debugPrint('❌ GPS o\'chirilgan');
    return false;
  }
  var perm = await Geolocator.checkPermission();
  if (perm == LocationPermission.denied) {
    perm = await Geolocator.requestPermission();
  }
  return perm != LocationPermission.denied &&
      perm != LocationPermission.deniedForever;
}