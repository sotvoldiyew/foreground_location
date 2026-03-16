import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../constants/app_constants.dart';
import '../model/location_point.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin      = FlutterLocalNotificationsPlugin();
  bool  _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );

    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          kNotifChannel,
          kNotifChannelName,
          description:     'GPS kuzatuv fonda ishlayapti',
          importance:      Importance.low,
          playSound:       false,
          enableVibration: false,
          showBadge:       false,
        ),
      );

      await androidPlugin?.requestNotificationsPermission();
    }

    _initialized = true;
    debugPrint('🔔 NotificationService tayyor');
  }

  Future<void> showStart() async {
    if (!_initialized) await init();
    if (defaultTargetPlatform != TargetPlatform.android) return;

    await _plugin.show(
      kNotifId,
      '🟢 Joylashuv kuzatilmoqda',
      'GPS signal kutilmoqda...',
      NotificationDetails(
        android: AndroidNotificationDetails(
          kNotifChannel,
          kNotifChannelName,
          importance:  Importance.low,
          priority:    Priority.low,
          ongoing:     true,
          autoCancel:  false,
          showWhen:    false,
          onlyAlertOnce: true,
          icon:        '@mipmap/ic_launcher',
        ),
      ),
    );
    debugPrint('🔔 Start notification ko\'rsatildi');
  }

  Future<void> update(LocationPoint point, int count) async {
    if (!_initialized) await init();
    if (defaultTargetPlatform != TargetPlatform.android) return;

    await _plugin.show(
      kNotifId,
      '🟢 Joylashuv kuzatilmoqda',
      '${point.speedKmh.toStringAsFixed(0)} km/h  •  '
          '${point.headingLabel}  •  $count nuqta',
      NotificationDetails(
        android: AndroidNotificationDetails(
          kNotifChannel,
          kNotifChannelName,
          importance:  Importance.low,
          priority:    Priority.low,
          ongoing:     true,
          autoCancel:  false,
          showWhen:    false,
          onlyAlertOnce: true,
          icon:        '@mipmap/ic_launcher',
          styleInformation: BigTextStyleInformation(
            '📍 ${point.latitude.toStringAsFixed(5)}, '
                '${point.longitude.toStringAsFixed(5)}\n'
                '🧭 ${point.headingLabel}   '
                '🚀 ${point.speedKmh.toStringAsFixed(1)} km/h\n'
                '🗺️ $count ta nuqta yozildi',
            contentTitle: '🟢 Joylashuv kuzatilmoqda',
          ),
        ),
      ),
    );
  }

  Future<void> cancel() async {
    if (!_initialized) return;
    await _plugin.cancel(kNotifId);
    debugPrint('🔕 Notification bekor qilindi');
  }
}