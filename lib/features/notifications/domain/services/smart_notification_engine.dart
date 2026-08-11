import 'package:timezone/timezone.dart' as tz;

import '../../../../core/notifications/notification_constants.dart';
import '../../../../core/notifications/notification_id.dart';
import '../../../../core/models/prediction_confidence.dart';
import '../../../dashboard/domain/readiness_calculator.dart';
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
  final tz.TZDateTime? estimatedOvulationDate;
  final PredictionConfidence predictionConfidence;
  final int? currentCycleDay;
  final String? estimatedPhase;
  final int? todayEnergyLevel;
  final int? todayPainLevel;
  final double? todaySleepHours;
  final String? mealSuggestion;
  final String? workoutSuggestion;
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
    this.estimatedOvulationDate,
    this.predictionConfidence = PredictionConfidence.low,
    this.currentCycleDay,
    this.estimatedPhase,
    this.todayEnergyLevel,
    this.todayPainLevel,
    this.todaySleepHours,
    this.mealSuggestion,
    this.workoutSuggestion,
    this.loggedOvulationTestDays = const {},
    this.loggedBbtDays = const {},
    this.loggedPregnancyTestDays = const {},
    this.completedTaskIds = const {},
    this.completedWorkoutIds = const {},
    this.journaledDays = const {},
    this.hydrationTargetReached = false,
  });

  bool get hasMeaningfulHealthState {
    return estimatedPeriodStart != null ||
        fertileWindowStart != null ||
        fertileWindowEnd != null ||
        estimatedOvulationDate != null ||
        currentCycleDay != null ||
        estimatedPhase != null ||
        todayEnergyLevel != null ||
        todayPainLevel != null ||
        todaySleepHours != null ||
        mealSuggestion != null ||
        workoutSuggestion != null ||
        conceptionModeActive ||
        loggedOvulationTestDays.isNotEmpty ||
        loggedBbtDays.isNotEmpty ||
        loggedPregnancyTestDays.isNotEmpty ||
        completedTaskIds.isNotEmpty ||
        completedWorkoutIds.isNotEmpty ||
        journaledDays.isNotEmpty ||
        hydrationTargetReached;
  }

  Map<String, Object?> toDebugMap({DateTime? today}) {
    return {
      if (today != null) 'today': today.toIso8601String(),
      'cycleTrackingPaused': cycleTrackingPaused,
      'pregnancyMode': pregnancyMode,
      'conceptionModeActive': conceptionModeActive,
      'estimatedPeriodStart': estimatedPeriodStart?.toIso8601String(),
      'fertileWindowStart': fertileWindowStart?.toIso8601String(),
      'fertileWindowEnd': fertileWindowEnd?.toIso8601String(),
      'estimatedOvulationDate': estimatedOvulationDate?.toIso8601String(),
      'predictionConfidence': predictionConfidence.name,
      'currentCycleDay': currentCycleDay,
      'estimatedPhase': estimatedPhase,
      'todayEnergyLevel': todayEnergyLevel,
      'todayPainLevel': todayPainLevel,
      'todaySleepHours': todaySleepHours,
      'mealSuggestion': mealSuggestion,
      'workoutSuggestion': workoutSuggestion,
      'hydrationTargetReached': hydrationTargetReached,
    };
  }
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
    if (!snapshot.hasMeaningfulHealthState) {
      throw StateError(
        'Notification reconciliation requires a real NotificationSourceSnapshot.',
      );
    }
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
    desired.addAll(
      _productivitySchedules(snapshot, preferences, location, now),
    );

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
    final periodLeadBody =
        snapshot.predictionConfidence == PredictionConfidence.low
        ? 'Your period may begin around this time based on your recent cycles.'
        : 'Your period may start in about 3 days.';
    final periodTomorrowBody =
        snapshot.predictionConfidence == PredictionConfidence.low
        ? 'Your period may begin around this time based on your recent cycles.'
        : 'Your period may start tomorrow.';
    return [
      _schedule(
        type: QuevaaNotificationType.periodExpected,
        entityId: 'period-${estimated.year}-${estimated.month}-minus3',
        scheduledAt: _atTime(
          estimated.subtract(const Duration(days: 3)),
          9 * 60,
        ),
        title: 'Period update',
        body: periodLeadBody,
        privacyTitle: 'Your Quevaa update is ready.',
        privacyBody: 'A planned cycle check-in is ready.',
        priority: QuevaaNotificationPriority.normal,
        location: location,
        now: now,
      ),
      _schedule(
        type: QuevaaNotificationType.periodExpected,
        entityId: 'period-${estimated.year}-${estimated.month}-minus1',
        scheduledAt: _atTime(
          estimated.subtract(const Duration(days: 1)),
          9 * 60,
        ),
        title: 'Period update',
        body: periodTomorrowBody,
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
        body: snapshot.predictionConfidence == PredictionConfidence.low
            ? 'Your period may begin around this time. Open Quevaa when you are ready to check in.'
            : 'Your period may start today. Open Quevaa when you are ready to check in.',
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
        body:
            'Your estimated fertile window may begin tomorrow. Log observations to help Quevaa personalise this cycle.',
        privacyTitle: 'Your Quevaa update is ready.',
        privacyBody: 'A private wellness reminder is ready.',
        priority: QuevaaNotificationPriority.normal,
        location: location,
        now: now,
      ),
    ];

    final ovulationDate = snapshot.estimatedOvulationDate;
    if (ovulationDate != null) {
      schedules.add(
        _schedule(
          type: QuevaaNotificationType.highFertilityCheckIn,
          entityId:
              'ovulation-${ovulationDate.year}-${ovulationDate.month}-${ovulationDate.day}',
          scheduledAt: _atTime(
            ovulationDate.subtract(const Duration(days: 1)),
            10 * 60,
          ),
          title: 'Estimated ovulation may be approaching.',
          body:
              'This may be near your estimated ovulation window. Log observations to help Quevaa personalise this cycle.',
          privacyTitle: 'Your Quevaa update is ready.',
          privacyBody: 'A private wellness reminder is ready.',
          priority: QuevaaNotificationPriority.normal,
          location: location,
          now: now,
        ),
      );
    }

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

  static List<QuevaaNotificationSchedule> _productivitySchedules(
    NotificationSourceSnapshot snapshot,
    QuevaaNotificationPreferences preferences,
    tz.Location location,
    tz.TZDateTime now,
  ) {
    final tomorrow = now.add(const Duration(days: 1));
    final readiness = ReadinessCalculator.calculate(
      selfReportedEnergy: snapshot.todayEnergyLevel,
      sleepHours: snapshot.todaySleepHours,
      painLevel: snapshot.todayPainLevel,
      estimatedPhase: snapshot.estimatedPhase ?? 'Unknown',
    );
    final lowReadiness =
        readiness.score == ReadinessScore.restore ||
        readiness.score == ReadinessScore.gentle;
    final strongReadiness =
        readiness.score == ReadinessScore.focused ||
        readiness.score == ReadinessScore.strong;
    return [
      _schedule(
        type: QuevaaNotificationType.productivityGuidance,
        entityId: 'productivity-${_dayKey(tomorrow)}',
        scheduledAt: _atTime(
          tomorrow,
          preferences.categoryTimes['dailyProductivity'] ?? 8 * 60 + 30,
        ),
        title: lowReadiness
            ? 'A lighter plan may fit today.'
            : strongReadiness
            ? 'Your focus window looks stronger today.'
            : 'Your steady plan is ready.',
        body: lowReadiness
            ? 'Your recent check-in points to a lower-pressure schedule today.'
            : strongReadiness
            ? 'Your current signals support deeper work if your schedule allows.'
            : 'Your current signals support steady, manageable progress.',
        privacyTitle: 'A planned Quevaa check-in is ready.',
        privacyBody: 'Open Quevaa to continue.',
        priority: QuevaaNotificationPriority.low,
        location: location,
        now: now,
      ),
    ];
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
        entityId: 'meal-daily-${_dayKey(tomorrow)}',
        scheduledAt: _atTime(
          tomorrow,
          preferences.categoryTimes['breakfast'] ?? 8 * 60,
        ),
        title: "Today's Quevaa meal ideas are ready.",
        body: snapshot.mealSuggestion == null
            ? 'Open Wellness to review your Nigerian meal recommendations.'
            : 'Open Wellness to review ${snapshot.mealSuggestion} and the rest of today’s meal ideas.',
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
        body: snapshot.workoutSuggestion == null
            ? 'Open Quevaa to review today’s plan.'
            : 'Today’s Quevaa movement idea: ${snapshot.workoutSuggestion}.',
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
