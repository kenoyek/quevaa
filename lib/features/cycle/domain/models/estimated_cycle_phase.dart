enum EstimatedCyclePhase {
  menstrual,
  follicular,
  ovulatoryWindow,
  luteal,
  unknown,
}

extension EstimatedCyclePhaseLabel on EstimatedCyclePhase {
  String get label => switch (this) {
    EstimatedCyclePhase.menstrual => 'Estimated menstrual phase',
    EstimatedCyclePhase.follicular => 'Estimated follicular phase',
    EstimatedCyclePhase.ovulatoryWindow => 'Estimated ovulatory window',
    EstimatedCyclePhase.luteal => 'Estimated luteal phase',
    EstimatedCyclePhase.unknown => 'Phase unavailable',
  };

  String get shortName => switch (this) {
    EstimatedCyclePhase.menstrual => 'Menstrual',
    EstimatedCyclePhase.follicular => 'Follicular',
    EstimatedCyclePhase.ovulatoryWindow => 'Ovulatory',
    EstimatedCyclePhase.luteal => 'Luteal',
    EstimatedCyclePhase.unknown => 'Unavailable',
  };

  static EstimatedCyclePhase fromString(String? phase) {
    if (phase == null) return EstimatedCyclePhase.unknown;
    final lower = phase.toLowerCase();
    if (lower.contains('menstru')) return EstimatedCyclePhase.menstrual;
    if (lower.contains('follic')) return EstimatedCyclePhase.follicular;
    if (lower.contains('ovulat')) return EstimatedCyclePhase.ovulatoryWindow;
    if (lower.contains('luteal')) return EstimatedCyclePhase.luteal;
    return EstimatedCyclePhase.unknown;
  }
}
