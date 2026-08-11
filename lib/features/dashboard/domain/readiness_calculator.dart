enum ReadinessScore { restore, gentle, steady, focused, strong }

enum ReadinessConfidence { low, current, personal }

class ReadinessFactor {
  final String label;
  final String detail;

  const ReadinessFactor(this.label, this.detail);
}

class ReadinessHistoryProfile {
  final int matchingCycleLogs;
  final double? typicalEnergy;
  final double? typicalPain;
  final double? typicalSleep;

  const ReadinessHistoryProfile({
    required this.matchingCycleLogs,
    this.typicalEnergy,
    this.typicalPain,
    this.typicalSleep,
  });

  bool get hasPersonalPattern => matchingCycleLogs >= 3;
}

class DailyReadinessResult {
  final ReadinessScore score;
  final int internalScore;
  final String label;
  final String title;
  final String description;
  final String primaryRecommendation;
  final List<ReadinessFactor> supportingFactors;
  final List<ReadinessFactor> limitingFactors;
  final ReadinessConfidence confidence;
  final String cycleContext;
  final String suggestedPace;
  final String bestFor;
  final String movementGuidance;
  final String historyInsight;

  const DailyReadinessResult({
    required this.score,
    required this.internalScore,
    required this.label,
    required this.title,
    required this.description,
    required this.primaryRecommendation,
    required this.supportingFactors,
    required this.limitingFactors,
    required this.confidence,
    required this.cycleContext,
    required this.suggestedPace,
    required this.bestFor,
    required this.movementGuidance,
    required this.historyInsight,
  });
}

class ReadinessCalculator {
  /// Planning-oriented readiness. This is not a medical score.
  ///
  /// Weights are deliberately simple and explainable:
  /// energy 30%, sleep 25%, pain 25% negative, stress 10% negative,
  /// mood/symptoms 10%, with a small cycle-context modifier capped at +/-6.
  /// Personal history contributes up to +/-7 only after enough similar logs.
  static DailyReadinessResult calculate({
    int? selfReportedEnergy,
    double? sleepHours,
    int? painLevel,
    String? mood,
    int? stressLevel,
    List<String> symptoms = const [],
    required String estimatedPhase,
    int? currentCycleDay,
    bool isPeriodActive = false,
    int loggedHistoryCount = 0,
    ReadinessHistoryProfile? historyProfile,
  }) {
    final supporting = <ReadinessFactor>[];
    final limiting = <ReadinessFactor>[];

    var score = 50.0;
    var knownSignals = 0;

    if (selfReportedEnergy != null) {
      knownSignals++;
      final energyScore = (selfReportedEnergy.clamp(1, 5) - 3) * 10.0;
      score += energyScore;
      if (selfReportedEnergy >= 4) {
        supporting.add(
          ReadinessFactor(
            'Energy ${selfReportedEnergy.clamp(1, 5)}/5',
            'Your check-in points to more available capacity.',
          ),
        );
      } else if (selfReportedEnergy <= 2) {
        limiting.add(
          ReadinessFactor(
            'Energy ${selfReportedEnergy.clamp(1, 5)}/5',
            'Lower energy suggests a lighter pace.',
          ),
        );
      } else {
        limiting.add(
          const ReadinessFactor(
            'Moderate energy',
            'Keep the day steady rather than overloaded.',
          ),
        );
      }
    }

    if (sleepHours != null) {
      knownSignals++;
      final sleep = sleepHours.clamp(0, 12);
      if (sleep >= 8) {
        score += 14;
        supporting.add(
          ReadinessFactor(
            '${sleep.toStringAsFixed(1)}h sleep',
            'Sleep is supporting your capacity today.',
          ),
        );
      } else if (sleep >= 7) {
        score += 8;
        supporting.add(
          ReadinessFactor(
            '${sleep.toStringAsFixed(1)}h sleep',
            'Your sleep looks solid enough for steady work.',
          ),
        );
      } else if (sleep >= 6) {
        score -= 3;
        limiting.add(
          ReadinessFactor(
            '${sleep.toStringAsFixed(1)}h sleep',
            'A little extra recovery room may help.',
          ),
        );
      } else {
        score -= 14;
        limiting.add(
          ReadinessFactor(
            '${sleep.toStringAsFixed(1)}h sleep',
            'Short sleep is a strong reason to simplify today.',
          ),
        );
      }
    }

    if (painLevel != null) {
      knownSignals++;
      final pain = painLevel.clamp(0, 5);
      score -= pain * 7.0;
      if (pain <= 1) {
        supporting.add(
          ReadinessFactor(
            pain == 0 ? 'No pain logged' : 'Low discomfort',
            'Pain is not a major limiter in this check-in.',
          ),
        );
      } else if (pain >= 4) {
        limiting.add(
          ReadinessFactor(
            _painLabel(pain),
            'High discomfort should meaningfully reduce today’s load.',
          ),
        );
      } else {
        limiting.add(
          ReadinessFactor(
            _painLabel(pain),
            'Discomfort is worth planning around.',
          ),
        );
      }
    }

    if (stressLevel != null) {
      knownSignals++;
      final stress = stressLevel.clamp(0, 5);
      score -= (stress - 2).clamp(0, 3) * 4.0;
      if (stress <= 1) {
        supporting.add(
          const ReadinessFactor(
            'Lower stress',
            'Less pressure supports a clearer plan.',
          ),
        );
      } else if (stress >= 4) {
        limiting.add(
          const ReadinessFactor(
            'Higher stress',
            'A calmer, more selective plan may fit better.',
          ),
        );
      }
    }

    final moodSignal = _moodSignal(mood);
    if (moodSignal != 0) {
      knownSignals++;
      score += moodSignal * 5;
      if (moodSignal > 0) {
        supporting.add(
          ReadinessFactor(mood!, 'Your mood check-in is supportive today.'),
        );
      } else {
        limiting.add(
          ReadinessFactor(
            mood!,
            'Your mood suggests keeping expectations compassionate.',
          ),
        );
      }
    }

    if (symptoms.isNotEmpty) {
      knownSignals++;
      final heavySymptoms = symptoms
          .where(
            (item) => [
              'cramps',
              'headache',
              'migraine',
              'fatigue',
              'nausea',
              'back pain',
            ].any((flag) => item.toLowerCase().contains(flag)),
          )
          .length;
      if (heavySymptoms > 0) {
        score -= (heavySymptoms * 4).clamp(0, 10);
        limiting.add(
          ReadinessFactor(
            '$heavySymptoms symptom signal${heavySymptoms == 1 ? '' : 's'}',
            'Logged symptoms are part of today’s pace recommendation.',
          ),
        );
      }
    }

    final cycleContext = _cycleContext(
      estimatedPhase: estimatedPhase,
      currentCycleDay: currentCycleDay,
      isPeriodActive: isPeriodActive,
    );
    final cycleModifier = _cycleModifier(
      estimatedPhase: estimatedPhase,
      currentCycleDay: currentCycleDay,
      isPeriodActive: isPeriodActive,
      painLevel: painLevel,
      selfReportedEnergy: selfReportedEnergy,
    );
    score += cycleModifier;
    if (cycleContext.isNotEmpty) {
      final factor = ReadinessFactor(
        cycleContext,
        'Cycle context informs the plan, but today’s check-in carries more weight.',
      );
      if (cycleModifier >= 0) {
        supporting.add(factor);
      } else {
        limiting.add(factor);
      }
    }

    final historyProfileValue = historyProfile;
    final historyInsight = _historyInsight(
      historyProfileValue,
      selfReportedEnergy,
      painLevel,
      sleepHours,
      currentCycleDay,
    );
    if (historyProfileValue != null && historyProfileValue.hasPersonalPattern) {
      final modifier = _historyModifier(
        historyProfileValue,
        selfReportedEnergy,
        painLevel,
        sleepHours,
      );
      score += modifier;
      if (modifier > 1) {
        supporting.add(
          const ReadinessFactor(
            'Personal pattern',
            'Similar days in your logs tend to look more supportive.',
          ),
        );
      } else if (modifier < -1) {
        limiting.add(
          const ReadinessFactor(
            'Personal pattern',
            'Similar days in your logs have needed more room.',
          ),
        );
      }
    }

    final confidence = _confidenceFor(
      knownSignals: knownSignals,
      loggedHistoryCount: loggedHistoryCount,
      historyProfile: historyProfile,
    );
    if (knownSignals <= 1) {
      limiting.add(
        const ReadinessFactor(
          'Limited check-in data',
          'Add energy, pain and sleep to sharpen today’s guidance.',
        ),
      );
    }

    final rounded = score.round().clamp(0, 100);
    final level = _levelFor(rounded, painLevel, selfReportedEnergy, sleepHours);

    return DailyReadinessResult(
      score: level,
      internalScore: rounded,
      label: _labelFor(level),
      title: _titleFor(level),
      description: _summaryFor(level, supporting, limiting, knownSignals),
      primaryRecommendation: _recommendationFor(level),
      supportingFactors: supporting.take(4).toList(growable: false),
      limitingFactors: limiting.take(4).toList(growable: false),
      confidence: confidence,
      cycleContext: cycleContext.isEmpty
          ? 'Cycle context unavailable'
          : cycleContext,
      suggestedPace: _paceFor(level),
      bestFor: _bestFor(level),
      movementGuidance: _movementFor(level),
      historyInsight: historyInsight,
    );
  }

  static ReadinessScore _levelFor(
    int score,
    int? pain,
    int? energy,
    double? sleep,
  ) {
    if ((pain ?? 0) >= 5 || (energy != null && energy <= 1 && score < 45)) {
      return ReadinessScore.restore;
    }
    if (score < 38) return ReadinessScore.restore;
    if (score < 55) return ReadinessScore.gentle;
    if (score < 72) return ReadinessScore.steady;
    if (score < 87) return ReadinessScore.focused;
    return ReadinessScore.strong;
  }

  static String _labelFor(ReadinessScore level) {
    return switch (level) {
      ReadinessScore.restore => 'Restore',
      ReadinessScore.gentle => 'Gentle',
      ReadinessScore.steady => 'Steady',
      ReadinessScore.focused => 'Focused',
      ReadinessScore.strong => 'Strong',
    };
  }

  static String _titleFor(ReadinessScore level) {
    return switch (level) {
      ReadinessScore.restore => 'Give yourself more recovery room today.',
      ReadinessScore.gentle => 'Keep today lighter where you can.',
      ReadinessScore.steady => 'A good day for manageable progress.',
      ReadinessScore.focused => 'Your signals support deeper focus.',
      ReadinessScore.strong => 'You have strong capacity today.',
    };
  }

  static String _summaryFor(
    ReadinessScore level,
    List<ReadinessFactor> supporting,
    List<ReadinessFactor> limiting,
    int knownSignals,
  ) {
    if (knownSignals == 0) {
      return 'Add a quick check-in to personalise today’s plan.';
    }
    final support = supporting.isNotEmpty
        ? supporting.first.label.toLowerCase()
        : 'today’s check-in';
    final limit = limiting.isNotEmpty ? limiting.first.label.toLowerCase() : '';
    if (limit.isEmpty) {
      return 'Based on $support, Quevaa suggests a ${_labelFor(level).toLowerCase()} pace.';
    }
    return 'Based on $support, while accounting for $limit, Quevaa suggests a ${_labelFor(level).toLowerCase()} pace.';
  }

  static String _recommendationFor(ReadinessScore level) {
    return switch (level) {
      ReadinessScore.restore =>
        'Protect recovery time and keep only the most necessary commitments.',
      ReadinessScore.gentle =>
        'Choose one useful priority and leave room for resets.',
      ReadinessScore.steady => 'Work in consistent blocks with planned breaks.',
      ReadinessScore.focused =>
        'Use your best window for deeper work before lighter tasks.',
      ReadinessScore.strong =>
        'This is a good day for demanding work, decisions or momentum.',
    };
  }

  static String _paceFor(ReadinessScore level) {
    return switch (level) {
      ReadinessScore.restore => '15-20 min focus · generous reset',
      ReadinessScore.gentle => '20-30 min focus · 10 min reset',
      ReadinessScore.steady => '40 min focus · 10 min reset',
      ReadinessScore.focused => '45-60 min focus · short reset',
      ReadinessScore.strong => '60 min focus · active reset',
    };
  }

  static String _bestFor(ReadinessScore level) {
    return switch (level) {
      ReadinessScore.restore => 'Recovery, admin, simple decisions',
      ReadinessScore.gentle => 'Email, review work, light planning',
      ReadinessScore.steady => 'Core tasks, collaboration, planning',
      ReadinessScore.focused => 'Deep work, writing, decisions',
      ReadinessScore.strong => 'Demanding work, launches, strategy',
    };
  }

  static String _movementFor(ReadinessScore level) {
    return switch (level) {
      ReadinessScore.restore => 'Gentle mobility or rest is enough.',
      ReadinessScore.gentle => 'Choose a lighter movement option.',
      ReadinessScore.steady => 'Your planned movement should fit.',
      ReadinessScore.focused => 'Normal planned movement looks reasonable.',
      ReadinessScore.strong => 'A stronger session can fit if you want it.',
    };
  }

  static String _cycleContext({
    required String estimatedPhase,
    required int? currentCycleDay,
    required bool isPeriodActive,
  }) {
    final day = currentCycleDay == null ? null : 'Cycle Day $currentCycleDay';
    final phase = estimatedPhase.trim().isEmpty ? null : estimatedPhase;
    if (day == null && phase == null) return '';
    if (isPeriodActive && day != null) return '$day of your period';
    if (day != null && phase != null) return '$day · $phase';
    return day ?? phase ?? '';
  }

  static double _cycleModifier({
    required String estimatedPhase,
    required int? currentCycleDay,
    required bool isPeriodActive,
    required int? painLevel,
    required int? selfReportedEnergy,
  }) {
    final phase = estimatedPhase.toLowerCase();
    var modifier = 0.0;
    if (isPeriodActive || phase.contains('menstrual')) {
      modifier -= ((painLevel ?? 0) >= 3) ? 4 : 1;
      if ((selfReportedEnergy ?? 3) >= 4 && (painLevel ?? 0) <= 1) {
        modifier += 3;
      }
      if ((currentCycleDay ?? 0) >= 4) modifier += 1.5;
    } else if (phase.contains('follicular')) {
      modifier += 2;
    } else if (phase.contains('ovulat') || phase.contains('fertile')) {
      modifier += 2.5;
    } else if (phase.contains('luteal')) {
      modifier -= ((painLevel ?? 0) >= 3 || (selfReportedEnergy ?? 3) <= 2)
          ? 3
          : 0.5;
    }
    return modifier.clamp(-6, 6);
  }

  static int _moodSignal(String? mood) {
    final value = mood?.toLowerCase().trim() ?? '';
    if (value.isEmpty || value == 'neutral') return 0;
    if ([
      'calm',
      'happy',
      'energized',
      'energetic',
      'hopeful',
    ].contains(value)) {
      return 1;
    }
    if (['sad', 'anxious', 'irritable', 'overwhelmed', 'low'].contains(value)) {
      return -1;
    }
    return 0;
  }

  static String _painLabel(int pain) {
    return switch (pain) {
      0 => 'No pain',
      1 => 'Mild discomfort',
      2 => 'Moderate discomfort',
      3 => 'High discomfort',
      _ => 'Severe discomfort',
    };
  }

  static ReadinessConfidence _confidenceFor({
    required int knownSignals,
    required int loggedHistoryCount,
    required ReadinessHistoryProfile? historyProfile,
  }) {
    if (historyProfile?.hasPersonalPattern == true ||
        loggedHistoryCount >= 10) {
      return ReadinessConfidence.personal;
    }
    if (knownSignals >= 3) return ReadinessConfidence.current;
    return ReadinessConfidence.low;
  }

  static double _historyModifier(
    ReadinessHistoryProfile profile,
    int? energy,
    int? pain,
    double? sleep,
  ) {
    var modifier = 0.0;
    if (profile.typicalEnergy != null && energy != null) {
      modifier += (profile.typicalEnergy! - 3) * 2;
    }
    if (profile.typicalPain != null && pain != null) {
      modifier -= (profile.typicalPain! - 1.5) * 2;
    }
    if (profile.typicalSleep != null && sleep != null) {
      modifier += (profile.typicalSleep! - 7) * 1.5;
    }
    return modifier.clamp(-7, 7);
  }

  static String _historyInsight(
    ReadinessHistoryProfile? profile,
    int? energy,
    int? pain,
    double? sleep,
    int? currentCycleDay,
  ) {
    if (profile == null || !profile.hasPersonalPattern) {
      return 'Quevaa is still learning your personal pattern. Keep checking in to make this more specific.';
    }
    final day = currentCycleDay == null
        ? 'similar cycle days'
        : 'Cycle Day $currentCycleDay';
    final energyText = profile.typicalEnergy == null
        ? null
        : 'energy around ${profile.typicalEnergy!.toStringAsFixed(1)}/5';
    final painText = profile.typicalPain == null
        ? null
        : 'pain around ${profile.typicalPain!.toStringAsFixed(1)}/5';
    return 'Across ${profile.matchingCycleLogs} logs near $day, your usual pattern shows ${[energyText, painText].whereType<String>().join(' and ')}.';
  }
}
