import 'package:timezone/timezone.dart' as tz;

import '../../../../core/notifications/notification_constants.dart';
import '../../../../core/notifications/notification_id.dart';
import '../entities/notification_preferences.dart';
import '../entities/notification_schedule.dart';
import '../entities/quevaa_notification.dart';
import '../enums/notification_priority.dart';
import '../enums/notification_type.dart';
import 'notification_policy_engine.dart';

class NotificationSourceSnapshot {
  final bool cycleTrackingPaused;
  final bool pregnancyMode;
  final bool conceptionModeActive;
  final tz.TZDateTime? estimatedPeriodStart;
  final tz.TZDateTime? fertileWindowStart;
  final tz.TZDateTime? fertileWindowEnd;
  final Set<String> loggedOvulationTestDays;
  final Set<String> loggedBbtDays;
  final Set<String> loggedPregnancyTestDays;
  final Set<String> completedTaskIds;
  final Set<String> completedWorkoutIds;
  final Set<String> journaledDays;
  final bool hydrationTargetReached;

  const NotificationSourceSnapshot({
    this.cycleTrackingPaused = false,
    this.pregnancyMode = false,
    this.conceptionModeActive = false,
    this.estimatedPeriodStart,
    this.fertileWindowStart,
    this.fertileWindowEnd,
    this.loggedOvulationTestDays = const {},
    this.loggedBbtDays = const {},
    this.loggedPregnancyTestDays = const {},
    this.completedTaskIds = const {},
    this.completedWorkoutIds = const {},
    this.journaledDays = const {},
    this.hydrationTargetReached = false,
  });
}

class SmartNotificationEngine {
  final NotificationPolicyEngine policyEngine;

  const SmartNotificationEngine({
    this.policyEngine = const NotificationPolicyEngine(),
  });

  List<QuevaaNotificationSchedule> buildDesiredSchedules({
    required QuevaaNotificationPreferences preferences,
    required NotificationSourceSnapshot snapshot,
    required tz.Location location,
    required tz.TZDateTime now,
  }) {
    final desired = <QuevaaNotificationSchedule>[];
    if (!snapshot.cycleTrackingPaused && !snapshot.pregnancyMode) {
      desired.addAll(_cycleSchedules(snapshot, location, now));
    }
    if (snapshot.conceptionModeActive && !snapshot.pregnancyMode) {
      desired.addAll(
        _conceptionSchedules(snapshot, preferences, location, now),
      );
    }
    desired.addAll(_wellnessSchedules(snapshot, preferences, location, now));

    return policyEngine.applyPolicies(
      desired: desired,
      preferences: preferences,
      now: now,
    );
  }

  static List<QuevaaNotificationSchedule> _cycleSchedules(
    NotificationSourceSnapshot snapshot,
    tz.Location location,
    tz.TZDateTime now,
  ) {
    final estimated = snapshot.estimatedPeriodStart;
    if (estimated == null) return const [];
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final monthName = months[estimated.month - 1];
    return [
      _schedule(
        type: QuevaaNotificationType.periodExpected,
        entityId: 'period-${estimated.year}-${estimated.month}',
        scheduledAt: _atTime(
          estimated.subtract(const Duration(days: 3)),
          9 * 60,
        ),
        title: 'Period update',
        body: 'Your period may begin around ${estimated.day} $monthName.',
        privacyTitle: 'Your Quevaa update is ready.',
        privacyBody: 'A planned cycle check-in is ready.',
        priority: QuevaaNotificationPriority.normal,
        location: location,
        now: now,
      ),
      _schedule(
        type: QuevaaNotificationType.periodToday,
        entityId: 'period-${estimated.year}-${estimated.month}',
        scheduledAt: _atTime(estimated, 9 * 60),
        title: 'How are you feeling today?',
        body: 'Open Quevaa when you are ready to check in.',
        privacyTitle: 'Your Quevaa update is ready.',
        privacyBody: 'A planned check-in is ready.',
        priority: QuevaaNotificationPriority.normal,
        location: location,
        now: now,
      ),
    ];
  }

  static List<QuevaaNotificationSchedule> _conceptionSchedules(
    NotificationSourceSnapshot snapshot,
    QuevaaNotificationPreferences preferences,
    tz.Location location,
    tz.TZDateTime now,
  ) {
    final fertileStart = snapshot.fertileWindowStart;
    final fertileEnd = snapshot.fertileWindowEnd;
    if (fertileStart == null || fertileEnd == null) return const [];

    final schedules = <QuevaaNotificationSchedule>[
      _schedule(
        type: QuevaaNotificationType.fertileWindowApproaching,
        entityId: 'fertile-${fertileStart.year}-${fertileStart.month}',
        scheduledAt: _atTime(
          fertileStart.subtract(const Duration(days: 1)),
          10 * 60,
        ),
        title: 'Your estimated fertile window may be approaching.',
        body: 'Log your observations to help Quevaa personalise this cycle.',
        privacyTitle: 'Your Quevaa update is ready.',
        privacyBody: 'A private wellness reminder is ready.',
        priority: QuevaaNotificationPriority.normal,
        location: location,
        now: now,
      ),
    ];

    for (
      var day = fertileStart;
      !day.isAfter(fertileEnd);
      day = day.add(const Duration(days: 1))
    ) {
      final dayKey = _dayKey(day);
      if (!snapshot.loggedOvulationTestDays.contains(dayKey)) {
        schedules.add(
          _schedule(
            type: QuevaaNotificationType.ovulationTest,
            entityId: 'lh-$dayKey',
            scheduledAt: _atTime(
              day,
              preferences.categoryTimes['ovulationTest'] ?? 12 * 60,
            ),
            title: 'Time to record your ovulation test.',
            body: 'Log your observations when you are ready.',
            privacyTitle: 'A planned check-in is ready.',
            privacyBody: 'Open Quevaa to continue.',
            priority: QuevaaNotificationPriority.normal,
            location: location,
            now: now,
          ),
        );
      }
      if (!snapshot.loggedBbtDays.contains(dayKey)) {
        schedules.add(
          _schedule(
            type: QuevaaNotificationType.basalBodyTemperature,
            entityId: 'bbt-$dayKey',
            scheduledAt: _atTime(
              day,
              preferences.categoryTimes['basalBodyTemperature'] ?? 390,
            ),
            title: 'Time to record your morning temperature.',
            body: 'Take it after waking and before normal activity.',
            privacyTitle: 'Your morning Quevaa check-in is ready.',
            privacyBody: 'Open Quevaa to continue.',
            priority: QuevaaNotificationPriority.normal,
            location: location,
            now: now,
          ),
        );
      }
    }

    schedules.add(
      _schedule(
        type: QuevaaNotificationType.prenatalSupplement,
        entityId: 'prenatal-daily',
        scheduledAt: _atTime(
          now.add(const Duration(days: 1)),
          preferences.categoryTimes['prenatalSupplement'] ?? 8 * 60,
        ),
        title: 'Supplement reminder',
        body: 'Your planned supplement check-in is ready.',
        privacyTitle: 'Your wellness reminder is ready.',
        privacyBody: 'Open Quevaa to continue.',
        priority: QuevaaNotificationPriority.high,
        location: location,
        now: now,
      ),
    );

    final testDay = fertileEnd.add(const Duration(days: 14));
    final testDayKey = _dayKey(testDay);
    if (!snapshot.loggedPregnancyTestDays.contains(testDayKey)) {
      schedules.add(
        _schedule(
          type: QuevaaNotificationType.pregnancyTest,
          entityId: 'pregnancy-test-$testDayKey',
          scheduledAt: _atTime(testDay, 9 * 60),
          title: 'You planned a private check-in for today.',
          body: 'Open Quevaa when you are ready.',
          privacyTitle: 'A planned check-in is ready.',
          privacyBody: 'Open Quevaa to continue.',
          priority: QuevaaNotificationPriority.normal,
          location: location,
          now: now,
        ),
      );
    }
    return schedules;
  }

  static List<QuevaaNotificationSchedule> _wellnessSchedules(
    NotificationSourceSnapshot snapshot,
    QuevaaNotificationPreferences preferences,
    tz.Location location,
    tz.TZDateTime now,
  ) {
    final tomorrow = now.add(const Duration(days: 1));
    final schedules = <QuevaaNotificationSchedule>[
      _schedule(
        type: QuevaaNotificationType.breakfast,
        entityId: 'meal-breakfast-${_dayKey(tomorrow)}',
        scheduledAt: _atTime(
          tomorrow,
          preferences.categoryTimes['breakfast'] ?? 8 * 60,
        ),
        title: 'Your meal suggestion is ready.',
        body: 'See today’s Nigerian meal recommendation.',
        privacyTitle: 'You have a wellness reminder.',
        privacyBody: 'Open Quevaa to continue.',
        priority: QuevaaNotificationPriority.low,
        location: location,
        now: now,
      ),
      _schedule(
        type: QuevaaNotificationType.workout,
        entityId: 'movement-${_dayKey(tomorrow)}',
        scheduledAt: _atTime(tomorrow, 17 * 60),
        title: 'Your movement plan is ready when you are.',
        body: 'Open Quevaa to review today’s plan.',
        privacyTitle: 'You have a wellness reminder.',
        privacyBody: 'Open Quevaa to continue.',
        priority: QuevaaNotificationPriority.low,
        location: location,
        now: now,
      ),
    ];
    if (!snapshot.hydrationTargetReached) {
      schedules.addAll([
        _schedule(
          type: QuevaaNotificationType.hydration,
          entityId: 'hydration-am-${_dayKey(tomorrow)}',
          scheduledAt: _atTime(
            tomorrow,
            preferences.categoryTimes['hydrationMorning'] ?? 10 * 60,
          ),
          title: 'Hydration check-in',
          body: 'A gentle water reminder is ready.',
          privacyTitle: 'You have a wellness reminder.',
          privacyBody: 'Open Quevaa to continue.',
          priority: QuevaaNotificationPriority.low,
          location: location,
          now: now,
        ),
        _schedule(
          type: QuevaaNotificationType.hydration,
          entityId: 'hydration-pm-${_dayKey(tomorrow)}',
          scheduledAt: _atTime(
            tomorrow,
            preferences.categoryTimes['hydrationAfternoon'] ?? 15 * 60,
          ),
          title: 'Hydration check-in',
          body: 'A gentle water reminder is ready.',
          privacyTitle: 'You have a wellness reminder.',
          privacyBody: 'Open Quevaa to continue.',
          priority: QuevaaNotificationPriority.low,
          location: location,
          now: now,
        ),
      ]);
    }
    if (!snapshot.journaledDays.contains(_dayKey(tomorrow))) {
      schedules.add(
        _schedule(
          type: QuevaaNotificationType.eveningReflection,
          entityId: 'journal-${_dayKey(tomorrow)}',
          scheduledAt: _atTime(
            tomorrow,
            preferences.categoryTimes['journal'] ?? 20 * 60,
          ),
          title: 'Would you like a quiet moment to reflect?',
          body: 'Your evening Quevaa check-in is ready.',
          privacyTitle: 'A planned check-in is ready.',
          privacyBody: 'Open Quevaa to continue.',
          priority: QuevaaNotificationPriority.low,
          location: location,
          now: now,
        ),
      );
    }
    return schedules;
  }

  static QuevaaNotificationSchedule _schedule({
    required QuevaaNotificationType type,
    required String entityId,
    required tz.TZDateTime scheduledAt,
    required String title,
    required String body,
    required String privacyTitle,
    required String privacyBody,
    required QuevaaNotificationPriority priority,
    required tz.Location location,
    required tz.TZDateTime now,
  }) {
    return QuevaaNotificationSchedule(
      timezoneName: location.name,
      notification: QuevaaNotification(
        id: QuevaaNotificationId.generate(
          type: type,
          entityId: entityId,
          occurrence: scheduledAt,
        ),
        type: type,
        scheduledAt: scheduledAt,
        title: title,
        body: body,
        privacySafeTitle: privacyTitle,
        privacySafeBody: privacyBody,
        route: type.defaultRoute,
        localRecordId: entityId,
        priority: priority,
        source: QuevaaNotificationConstants.debugSource,
        createdAt: now,
        updatedAt: now,
        scheduleVersion: QuevaaNotificationConstants.scheduleVersion,
      ),
    );
  }

  static tz.TZDateTime _atTime(tz.TZDateTime date, int minutes) {
    return tz.TZDateTime(
      date.location,
      date.year,
      date.month,
      date.day,
      minutes ~/ 60,
      minutes % 60,
    );
  }

  static String _dayKey(tz.TZDateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
