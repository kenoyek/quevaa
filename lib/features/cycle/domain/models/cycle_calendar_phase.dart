/// Phase state for a specific calendar date, derived from the canonical cycle engine.
/// Used for calendar cell background tinting.
enum CycleCalendarPhase {
  menstrual,
  follicular,
  fertileWindow,
  estimatedOvulation,
  luteal,
  unknown,
}

extension CycleCalendarPhaseLabel on CycleCalendarPhase {
  String get displayName => switch (this) {
        CycleCalendarPhase.menstrual => 'Estimated menstrual phase',
        CycleCalendarPhase.follicular => 'Estimated follicular phase',
        CycleCalendarPhase.fertileWindow => 'Estimated fertile window',
        CycleCalendarPhase.estimatedOvulation => 'Estimated ovulation',
        CycleCalendarPhase.luteal => 'Estimated luteal phase',
        CycleCalendarPhase.unknown => 'Phase unavailable',
      };

  String get shortName => switch (this) {
        CycleCalendarPhase.menstrual => 'Menstrual',
        CycleCalendarPhase.follicular => 'Follicular',
        CycleCalendarPhase.fertileWindow => 'Fertile window',
        CycleCalendarPhase.estimatedOvulation => 'Ovulation',
        CycleCalendarPhase.luteal => 'Luteal',
        CycleCalendarPhase.unknown => 'Unknown',
      };
}
