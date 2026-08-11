import '../entities/app_notification.dart';
import '../entities/notification_preferences.dart';
import '../entities/notification_schedule.dart';

abstract class NotificationRepository {
  Future<QuevaaNotificationPreferences> loadPreferences();
  Future<void> savePreferences(QuevaaNotificationPreferences preferences);
  Future<Map<int, String>> loadScheduleFingerprints();
  Future<void> upsertScheduleStates(List<QuevaaNotificationSchedule> schedules);
  Future<void> upsertInboxEntries(List<QuevaaNotificationSchedule> schedules);
  Stream<List<AppNotification>> watchInbox({int limit = 80});
  Stream<int> watchUnreadCount();
  Future<int> unreadCount();
  Future<void> markInboxEntryRead(int notificationId);
  Future<void> markAllInboxRead();
  Future<void> markSchedulesCancelled(Iterable<int> ids);
  Future<void> persistReconciliation(DateTime reconciledAt, String timezone);
}
