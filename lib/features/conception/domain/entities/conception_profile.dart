enum ConceptionGoalStatus { tryingToConceive, paused, earlyPregnancy }

class ConceptionProfile {
  final ConceptionGoalStatus status;
  final DateTime tryingStartDate;
  final DateTime lastPeriodStartDate;
  final List<DateTime> previousPeriodStartDates;
  final int typicalCycleLength;
  final int typicalPeriodDuration;
  final bool cyclesUsuallyRegular;
  final DateTime? contraceptionStoppedDate;
  final bool usesOvulationTests;
  final bool tracksBasalTemperature;
  final bool tracksCervicalMucus;
  final bool logsIntimacy;
  final bool intimacyExtraPrivacyEnabled;
  final bool prenatalReminderEnabled;
  final bool partnerSupportEnabled;
  final bool gentleModeEnabled;
  final bool hideCountdown;
  final String? healthConditions;
  final String? medications;
  final String? previousPregnancyContext;

  const ConceptionProfile({
    required this.status,
    required this.tryingStartDate,
    required this.lastPeriodStartDate,
    this.previousPeriodStartDates = const [],
    this.typicalCycleLength = 28,
    this.typicalPeriodDuration = 5,
    this.cyclesUsuallyRegular = true,
    this.contraceptionStoppedDate,
    this.usesOvulationTests = true,
    this.tracksBasalTemperature = true,
    this.tracksCervicalMucus = true,
    this.logsIntimacy = false,
    this.intimacyExtraPrivacyEnabled = true,
    this.prenatalReminderEnabled = true,
    this.partnerSupportEnabled = false,
    this.gentleModeEnabled = false,
    this.hideCountdown = false,
    this.healthConditions,
    this.medications,
    this.previousPregnancyContext,
  });

  int get tryingCycleCount {
    final days = DateTime.now().difference(tryingStartDate).inDays;
    return (days / typicalCycleLength).clamp(1, 999).ceil();
  }

  ConceptionProfile copyWith({
    ConceptionGoalStatus? status,
    DateTime? tryingStartDate,
    DateTime? lastPeriodStartDate,
    List<DateTime>? previousPeriodStartDates,
    int? typicalCycleLength,
    int? typicalPeriodDuration,
    bool? cyclesUsuallyRegular,
    DateTime? contraceptionStoppedDate,
    bool? usesOvulationTests,
    bool? tracksBasalTemperature,
    bool? tracksCervicalMucus,
    bool? logsIntimacy,
    bool? intimacyExtraPrivacyEnabled,
    bool? prenatalReminderEnabled,
    bool? partnerSupportEnabled,
    bool? gentleModeEnabled,
    bool? hideCountdown,
    String? healthConditions,
    String? medications,
    String? previousPregnancyContext,
  }) {
    return ConceptionProfile(
      status: status ?? this.status,
      tryingStartDate: tryingStartDate ?? this.tryingStartDate,
      lastPeriodStartDate: lastPeriodStartDate ?? this.lastPeriodStartDate,
      previousPeriodStartDates:
          previousPeriodStartDates ?? this.previousPeriodStartDates,
      typicalCycleLength: typicalCycleLength ?? this.typicalCycleLength,
      typicalPeriodDuration:
          typicalPeriodDuration ?? this.typicalPeriodDuration,
      cyclesUsuallyRegular: cyclesUsuallyRegular ?? this.cyclesUsuallyRegular,
      contraceptionStoppedDate:
          contraceptionStoppedDate ?? this.contraceptionStoppedDate,
      usesOvulationTests: usesOvulationTests ?? this.usesOvulationTests,
      tracksBasalTemperature:
          tracksBasalTemperature ?? this.tracksBasalTemperature,
      tracksCervicalMucus: tracksCervicalMucus ?? this.tracksCervicalMucus,
      logsIntimacy: logsIntimacy ?? this.logsIntimacy,
      intimacyExtraPrivacyEnabled:
          intimacyExtraPrivacyEnabled ?? this.intimacyExtraPrivacyEnabled,
      prenatalReminderEnabled:
          prenatalReminderEnabled ?? this.prenatalReminderEnabled,
      partnerSupportEnabled:
          partnerSupportEnabled ?? this.partnerSupportEnabled,
      gentleModeEnabled: gentleModeEnabled ?? this.gentleModeEnabled,
      hideCountdown: hideCountdown ?? this.hideCountdown,
      healthConditions: healthConditions ?? this.healthConditions,
      medications: medications ?? this.medications,
      previousPregnancyContext:
          previousPregnancyContext ?? this.previousPregnancyContext,
    );
  }
}
