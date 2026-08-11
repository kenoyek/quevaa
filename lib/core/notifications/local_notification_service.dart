import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../features/notifications/domain/entities/notification_schedule.dart';
import '../../features/notifications/domain/enums/notification_type.dart';
import 'notification_channels.dart';
import 'notification_payload.dart';

@pragma('vm:entry-point')
void quevaaNotificationTapBackground(NotificationResponse response) {
  // Background actions intentionally avoid network and heavyweight services.
}

class QuevaaLocalNotificationService {
  QuevaaLocalNotificationService._();

  static final QuevaaLocalNotificationService instance =
      QuevaaLocalNotificationService._();

  final FlutterLocalNotificationsPlugin plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize({
    required void Function(NotificationResponse response) onTap,
  }) async {
    if (_initialized) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      defaultPresentAlert: true,
      defaultPresentBanner: true,
      defaultPresentList: true,
      defaultPresentSound: true,
      defaultPresentBadge: false,
    );
    const settings = InitializationSettings(android: android, iOS: darwin);

    await plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: onTap,
      onDidReceiveBackgroundNotificationResponse:
          quevaaNotificationTapBackground,
    );
    await _createAndroidChannels();
    _initialized = true;
  }

  Future<void> schedule(QuevaaNotificationSchedule schedule) async {
    final notification = schedule.notification;
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelFor(notification.type).id,
        _channelFor(notification.type).name,
        channelDescription: _channelFor(notification.type).description,
        importance: _channelFor(notification.type).importance,
        priority: Priority.defaultPriority,
        enableVibration: true,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBanner: true,
        presentList: true,
        presentSound: true,
        presentBadge: false,
      ),
    );

    await plugin.zonedSchedule(
      notification.id,
      notification.title,
      notification.body,
      notification.scheduledAt,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: QuevaaNotificationPayload.forSchedule(
        notificationId: notification.id,
        type: notification.type,
        route: notification.route,
        entityId: notification.localRecordId,
      ).encode(),
    );
  }

  Future<void> scheduleTestNotification() async {
    final now = tz.TZDateTime.now(tz.local);
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        QuevaaNotificationChannels.wellness.id,
        QuevaaNotificationChannels.wellness.name,
        channelDescription: QuevaaNotificationChannels.wellness.description,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBanner: true,
        presentList: true,
        presentSound: true,
      ),
    );
    await plugin.zonedSchedule(
      900000001,
      'Quevaa reminders are ready',
      'Your private on-device notifications are working.',
      now.add(const Duration(seconds: 5)),
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: QuevaaNotificationPayload.forSchedule(
        notificationId: 900000001,
        type: QuevaaNotificationType.dailyCycleCheckIn,
        route: '/notifications',
      ).encode(),
    );
  }

  Future<void> cancel(int id) => plugin.cancel(id);
  Future<void> cancelAll() => plugin.cancelAll();
  Future<List<PendingNotificationRequest>> pending() =>
      plugin.pendingNotificationRequests();

  Future<void> _createAndroidChannels() async {
    final android = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return;
    for (final channel in QuevaaNotificationChannels.all) {
      await android.createNotificationChannel(channel);
    }
  }

  static AndroidNotificationChannel _channelFor(QuevaaNotificationType type) {
    switch (type.categoryKey) {
      case 'cycle':
        return QuevaaNotificationChannels.cycle;
      case 'conception':
        return QuevaaNotificationChannels.conception;
      case 'medication':
        return QuevaaNotificationChannels.medication;
      case 'tasks':
        return QuevaaNotificationChannels.tasks;
      case 'journal':
      case 'weeklyReview':
        return QuevaaNotificationChannels.reflection;
      case 'meals':
      case 'hydration':
      case 'workouts':
      default:
        return QuevaaNotificationChannels.wellness;
    }
  }
}
