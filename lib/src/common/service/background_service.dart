import 'dart:math' as math;
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';

import '../constants/app_constants.dart';
import '../model/location_point.dart';
import 'location_storage.dart';

@pragma('vm:entry-point')
Future<void> onServiceStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  if (service is AndroidServiceInstance) {
    await service.setAsForegroundService();
    await service.setForegroundNotificationInfo(
      title:   '🟢 Joylashuv kuzatilmoqda',
      content: 'GPS signal kutilmoqda...',
    );
  }

  final dio = Dio(
    BaseOptions(
      baseUrl:        'https://enpfgyujmeedyqispbtj.supabase.co/functions/v1',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Authorization': 'Bearer sb_publishable_UlA1yHcU7DWeSEyC9HVH2w_-n0OBTzp',
        'apikey':        'sb_publishable_UlA1yHcU7DWeSEyC9HVH2w_-n0OBTzp',
        'Content-Type':  'application/json',
      },
    ),
  );

  bool shouldRun = true;

  service.on(kEvtStop).listen((_) async {
    debugPrint('⏹️ [BG] Stop');
    shouldRun = false;
    await LocationStorage.instance.setRunning(false);
    service.stopSelf();
  });

  final points = <LocationPoint>[];
  LocationPoint? lastSaved;

  debugPrint('🚀 [BG] Started');

  await for (final pos in Geolocator.getPositionStream(
    locationSettings: _buildLocationSettings(),
  )) {
    if (!shouldRun) break;

    if (pos.latitude == 0.0 && pos.longitude == 0.0) continue;
    if (pos.accuracy > kMaxAccuracyMeters) {
      debugPrint('⚠️ [BG] Yomon signal — skip');
      continue;
    }

    final speedKmh = pos.speed < 0 ? 0.0 : pos.speed * 3.6;
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
        lastSaved.latitude, lastSaved.longitude,
        point.latitude,     point.longitude,
      );
      if (dist < kMinDistanceMeters) {
        debugPrint('📌 [BG] Joyida (${dist.toStringAsFixed(1)}m) — skip');
        continue;
      }
    }

    lastSaved = point;
    points.add(point);
    if (points.length > kMaxPoints) points.removeAt(0);

    await LocationStorage.instance.save(List.of(points));

    try {
      final response = await dio.post<Map<String, dynamic>>(
        '/save-location',
        data: {
          'latitude':  point.latitude,
          'longitude': point.longitude,
          'head':      point.heading,
        },
      );
      final id = response.data?['data']?['id'];
      debugPrint('✅ [BG API] id=$id');
    } on DioException catch (e) {
      debugPrint('⚠️ [BG API] ${e.type}: ${e.message}');
    } catch (e) {
      debugPrint('❌ [BG API] $e');
    }

    service.invoke(kEvtLocationUpdate, point.toMap());

    if (service is AndroidServiceInstance) {
      await service.setForegroundNotificationInfo(
        title:   '🟢 Joylashuv kuzatilmoqda',
        content: '${speedKmh.toStringAsFixed(0)} km/h  •  '
            '${point.headingLabel}  •  ${points.length} nuqta',
      );
    }

    debugPrint('✅ [BG] [${points.length}] '
        '${point.latitude.toStringAsFixed(5)}, '
        '${point.longitude.toStringAsFixed(5)}');
  }

  debugPrint('🔚 [BG] GPS stream tugadi');
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
      notificationText:        'GPS yozilmoqda...',
      enableWakeLock:          true,
      enableWifiLock:          true,
      setOngoing:              true,
    ),
  );
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