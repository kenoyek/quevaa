import '../../../../core/notifications/notification_constants.dart';
import '../enums/notification_privacy_mode.dart';

class QuevaaNotificationPreferences {
  final bool enabled;
  final bool permissionInvitationSeen;
  final bool permissionPreviouslyDeclined;
  final QuevaaNotificationPrivacyMode privacyMode;
  final int quietStartMinutes;
  final int quietEndMinutes;
  final int dailyCap;
  final bool soundEnabled;
  final bool vibrationEnabled;
  final String lastKnownTimezone;
  final DateTime? lastReconciliationAt;
  final int scheduleVersion;
  final Map<String, bool> categoryEnabled;
  final Map<String, int> categoryTimes;

  const QuevaaNotificationPreferences({
    required this.enabled,
    required this.permissionInvitationSeen,
    required this.permissionPreviouslyDeclined,
    required this.privacyMode,
    required this.quietStartMinutes,
    required this.quietEndMinutes,
    required this.dailyCap,
    required this.soundEnabled,
    required this.vibrationEnabled,
    required this.lastKnownTimezone,
    required this.lastReconciliationAt,
    required this.scheduleVersion,
    required this.categoryEnabled,
    required this.categoryTimes,
  });

  factory QuevaaNotificationPreferences.defaults() {
    return const QuevaaNotificationPreferences(
      enabled: false,
      permissionInvitationSeen: false,
      permissionPreviouslyDeclined: false,
      privacyMode: QuevaaNotificationPrivacyMode.discreet,
      quietStartMinutes: QuevaaNotificationConstants.defaultQuietStartMinutes,
      quietEndMinutes: QuevaaNotificationConstants.defaultQuietEndMinutes,
      dailyCap: QuevaaNotificationConstants.defaultDailyCap,
      soundEnabled: true,
      vibrationEnabled: true,
      lastKnownTimezone: QuevaaNotificationConstants.fallbackTimezone,
      lastReconciliationAt: null,
      scheduleVersion: QuevaaNotificationConstants.scheduleVersion,
      categoryEnabled: {
        'cycle': true,
        'conception': true,
        'medication': true,
        'tasks': true,
        'meals': true,
        'hydration': true,
        'workouts': true,
        'journal': true,
        'weeklyReview': true,
      },
      categoryTimes: {
        'dailyCycleCheckIn': 9 * 60,
        'ovulationTest': 12 * 60,
        'basalBodyTemperature': 6 * 60 + 30,
        'prenatalSupplement': 8 * 60,
        'breakfast': 8 * 60,
        'lunch': 13 * 60,
        'dinner': 19 * 60,
        'hydrationMorning': 10 * 60,
        'hydrationAfternoon': 15 * 60,
        'journal': 20 * 60,
        'weeklyReview': 17 * 60,
      },
    );
  }

  QuevaaNotificationPreferences copyWith({
    bool? enabled,
    bool? permissionInvitationSeen,
    bool? permissionPreviouslyDeclined,
    QuevaaNotificationPrivacyMode? privacyMode,
    int? quietStartMinutes,
    int? quietEndMinutes,
    int? dailyCap,
    bool? soundEnabled,
    bool? vibrationEnabled,
    String? lastKnownTimezone,
    DateTime? lastReconciliationAt,
    int? scheduleVersion,
    Map<String, bool>? categoryEnabled,
    Map<String, int>? categoryTimes,
  }) {
    return QuevaaNotificationPreferences(
      enabled: enabled ?? this.enabled,
      permissionInvitationSeen:
          permissionInvitationSeen ?? this.permissionInvitationSeen,
      permissionPreviouslyDeclined:
          permissionPreviouslyDeclined ?? this.permissionPreviouslyDeclined,
      privacyMode: privacyMode ?? this.privacyMode,
      quietStartMinutes: quietStartMinutes ?? this.quietStartMinutes,
      quietEndMinutes: quietEndMinutes ?? this.quietEndMinutes,
      dailyCap: dailyCap ?? this.dailyCap,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      lastKnownTimezone: lastKnownTimezone ?? this.lastKnownTimezone,
      lastReconciliationAt: lastReconciliationAt ?? this.lastReconciliationAt,
      scheduleVersion: scheduleVersion ?? this.scheduleVersion,
      categoryEnabled: categoryEnabled ?? this.categoryEnabled,
      categoryTimes: categoryTimes ?? this.categoryTimes,
    );
  }
}
