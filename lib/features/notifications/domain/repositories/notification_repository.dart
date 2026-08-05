import '../entities/notification_preferences.dart';
import '../entities/notification_schedule.dart';

abstract class NotificationRepository {
  Future<QuevaaNotificationPreferences> loadPreferences();
  Future<void> savePreferences(QuevaaNotificationPreferences preferences);
  Future<Map<int, String>> loadScheduleFingerprints();
  Future<void> upsertScheduleStates(List<QuevaaNotificationSchedule> schedules);
  Future<void> markSchedulesCancelled(Iterable<int> ids);
  Future<void> persistReconciliation(DateTime reconciledAt, String timezone);
}
