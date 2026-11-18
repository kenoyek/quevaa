import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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

  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> initialize({
    required void Function(NotificationResponse response) onTap,
  }) async {
    if (_initialized || !isSupported) return;

    const android = AndroidInitializationSettings('ic_stat_quevaa');
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

  Future<NotificationResponse?> launchResponse() async {
    if (!_initialized) return null;
    final details = await plugin.getNotificationAppLaunchDetails();
    return details?.didNotificationLaunchApp == true
        ? details?.notificationResponse
        : null;
  }

  Future<void> schedule(QuevaaNotificationSchedule schedule) async {
    _requireInitialization();
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

  static const scheduledTestNotificationId = -900000001;

  Future<void> sendTestNotification({bool scheduled = false}) async {
    _requireInitialization();
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        QuevaaNotificationChannels.test.id,
        QuevaaNotificationChannels.test.name,
        channelDescription: QuevaaNotificationChannels.test.description,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBanner: true,
        presentList: true,
        presentSound: true,
      ),
    );
    final id = scheduled ? scheduledTestNotificationId : 900000001;
    final payload = QuevaaNotificationPayload.forSchedule(
      notificationId: id,
      type: QuevaaNotificationType.dailyCycleCheckIn,
      route: '/notifications',
    ).encode();
    const title = 'Quevaa test reminder';
    const body = 'Your device delivered this private reminder.';
    if (scheduled) {
      await plugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.now(tz.local).add(const Duration(minutes: 1)),
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    } else {
      await plugin.show(id, title, body, details, payload: payload);
    }
  }

  Future<void> cancel(int id) async {
    if (_initialized) await plugin.cancel(id);
  }

  Future<void> cancelAll() async {
    if (_initialized) await plugin.cancelAll();
  }

  Future<List<PendingNotificationRequest>> pending() async =>
      _initialized ? plugin.pendingNotificationRequests() : [];

  void _requireInitialization() {
    if (!_initialized) throw StateError('Local notifications are unavailable.');
  }

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
