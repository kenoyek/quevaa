import 'dart:convert';
import 'dart:math' as math;

import '../../../core/database/app_database.dart';
import '../../cycle/application/cycle_workspace_provider.dart';

enum CycleInsightRange {
  last3Cycles('Last 3 cycles', 3),
  last6Cycles('Last 6 cycles', 6),
  last12Cycles('Last 12 cycles', 12),
  all('All tracked cycles', null);

  const CycleInsightRange(this.label, this.cycleLimit);

  final String label;
  final int? cycleLimit;
}

class CycleInsightsInput {
  final List<CyclePeriod> periods;
  final List<DailyLog> dailyLogs;
  final List<SymptomEntry> symptomEntries;
  final List<MoodEntry> moodEntries;
  final List<SleepEntry> sleepEntries;
  final List<Task> tasks;
  final List<FocusSession> focusSessions;
  final bool ttcEnabled;
  final int basalTemperatureCount;
  final int cervicalMucusCount;
  final int ovulationTestCount;
  final int pregnancyTestCount;

  const CycleInsightsInput({
    required this.periods,
    required this.dailyLogs,
    required this.symptomEntries,
    required this.moodEntries,
    required this.sleepEntries,
    required this.tasks,
    required this.focusSessions,
    required this.ttcEnabled,
    required this.basalTemperatureCount,
    required this.cervicalMucusCount,
    required this.ovulationTestCount,
    required this.pregnancyTestCount,
  });
}

class CycleInsightsResult {
  final CycleInsightRange range;
  final DateTime? rangeStart;
  final DateTime? rangeEnd;
  final int periodCount;
  final int completedPeriodCount;
  final int trackedCycleCount;
  final List<CycleLengthPoint> cycleLengths;
  final double? averageCycleLength;
  final int? shortestCycleLength;
  final int? longestCycleLength;
  final double? cycleVariability;
  final String regularityLabel;
  final List<int> periodDurations;
  final double? averagePeriodDuration;
  final List<SymptomPattern> symptomPatterns;
  final MetricPattern energyPattern;
  final MetricPattern painPattern;
  final MetricPattern sleepPattern;
  final TextPattern moodPattern;
  final TextPattern stressPattern;
  final ProductivityPattern productivityPattern;
  final TtcPattern? ttcPattern;
  final List<String> personalInsights;

  const CycleInsightsResult({
    required this.range,
    required this.rangeStart,
    required this.rangeEnd,
    required this.periodCount,
    required this.completedPeriodCount,
    required this.trackedCycleCount,
    required this.cycleLengths,
    required this.averageCycleLength,
    required this.shortestCycleLength,
    required this.longestCycleLength,
    required this.cycleVariability,
    required this.regularityLabel,
    required this.periodDurations,
    required this.averagePeriodDuration,
    required this.symptomPatterns,
    required this.energyPattern,
    required this.painPattern,
    required this.sleepPattern,
    required this.moodPattern,
    required this.stressPattern,
    required this.productivityPattern,
    required this.ttcPattern,
    required this.personalInsights,
  });

  bool get hasAnyCycleHistory => periodCount > 0;
  bool get hasCycleAverages => cycleLengths.length >= 3;
  bool get isLowHistory => trackedCycleCount < 3;

  String get cycleRangeLabel {
    if (shortestCycleLength == null || longestCycleLength == null) {
      return 'Not enough cycle history';
    }
    if (shortestCycleLength == longestCycleLength) {
      return '$shortestCycleLength days';
    }
    return '$shortestCycleLength-$longestCycleLength days';
  }

  String get averageCycleLabel => averageCycleLength == null
      ? 'Learning'
      : '${averageCycleLength!.round()} days';

  String get averagePeriodLabel => averagePeriodDuration == null
      ? 'Learning'
      : '${averagePeriodDuration!.round()} days';
}

class CycleLengthPoint {
  final DateTime startDate;
  final int lengthDays;
  final int cycleNumber;

  const CycleLengthPoint({
    required this.startDate,
    required this.lengthDays,
    required this.cycleNumber,
  });
}

class SymptomPattern {
  final String symptom;
  final int loggedDays;
  final int cycleCount;
  final String timingSummary;
  final String explanation;

  const SymptomPattern({
    required this.symptom,
    required this.loggedDays,
    required this.cycleCount,
    required this.timingSummary,
    required this.explanation,
  });
}

class MetricPattern {
  final String name;
  final int observationCount;
  final double? average;
  final String summary;
  final String explanation;
  final Map<String, double> phaseAverages;

  const MetricPattern({
    required this.name,
    required this.observationCount,
    required this.average,
    required this.summary,
    required this.explanation,
    required this.phaseAverages,
  });
}

class TextPattern {
  final String name;
  final int observationCount;
  final String summary;
  final String explanation;

  const TextPattern({
    required this.name,
    required this.observationCount,
    required this.summary,
    required this.explanation,
  });
}

class ProductivityPattern {
  final int taskCount;
  final int completedTaskCount;
  final int focusSessionCount;
  final int completedFocusSessionCount;
  final String summary;
  final String explanation;

  const ProductivityPattern({
    required this.taskCount,
    required this.completedTaskCount,
    required this.focusSessionCount,
    required this.completedFocusSessionCount,
    required this.summary,
    required this.explanation,
  });
}

class TtcPattern {
  final int basalTemperatureCount;
  final int cervicalMucusCount;
  final int ovulationTestCount;
  final int pregnancyTestCount;
  final String summary;

  const TtcPattern({
    required this.basalTemperatureCount,
    required this.cervicalMucusCount,
    required this.ovulationTestCount,
    required this.pregnancyTestCount,
    required this.summary,
  });
}

class CycleInsightsAnalyzer {
  const CycleInsightsAnalyzer();

  CycleInsightsResult analyze({
    required CycleInsightsInput input,
    required CycleInsightRange range,
    DateTime? windowStart,
    DateTime? windowEnd,
  }) {
    final periods = [...input.periods]
      ..sort((a, b) => a.startDate.compareTo(b.startDate));
    final scopedPeriods = _scopePeriods(
      periods,
      range,
      windowStart: windowStart,
      windowEnd: windowEnd,
    );
    final rangeStart = windowStart ?? scopedPeriods.firstOrNull?.startDate;
    final rangeEnd =
        windowEnd ??
        scopedPeriods.lastOrNull?.endDate ??
        scopedPeriods.lastOrNull?.startDate;

    final dailyLogs = _between(
      input.dailyLogs,
      (log) => log.date,
      rangeStart,
      rangeEnd,
    );
    final symptoms = _between(
      input.symptomEntries,
      (entry) => entry.date,
      rangeStart,
      rangeEnd,
    );
    final moods = _between(
      input.moodEntries,
      (entry) => entry.date,
      rangeStart,
      rangeEnd,
    );
    final sleeps = _between(
      input.sleepEntries,
      (entry) => entry.date,
      rangeStart,
      rangeEnd,
    );
    final tasks = _between(
      input.tasks,
      (task) => task.scheduledDate ?? task.dueDate,
      rangeStart,
      rangeEnd,
    );
    final focus = _between(
      input.focusSessions,
      (session) => session.startedAt ?? session.completedAt,
      rangeStart,
      rangeEnd,
    );

    final cycleLengths = _cycleLengths(scopedPeriods);
    final periodDurations = scopedPeriods
        .where((period) => period.endDate != null)
        .map((period) => _daysInclusive(period.startDate, period.endDate!))
        .where((duration) => duration > 0 && duration <= 14)
        .toList();
    final averageCycle = cycleLengths.length >= 3
        ? _average(cycleLengths.map((point) => point.lengthDays.toDouble()))
        : null;
    final variability = cycleLengths.length >= 3
        ? _standardDeviation(
            cycleLengths.map((point) => point.lengthDays.toDouble()),
          )
        : null;
    final averagePeriod = periodDurations.length >= 2
        ? _average(periodDurations.map((duration) => duration.toDouble()))
        : null;

    final symptomsByDay = _mergedSymptoms(dailyLogs, symptoms);
    final symptomPatterns = _symptomPatterns(symptomsByDay, scopedPeriods);
    final energyPattern = _dailyMetricPattern(
      name: 'Energy',
      logs: dailyLogs.where((log) => log.energyLevel > 0).toList(),
      periods: scopedPeriods,
      valueFor: (log) => log.energyLevel.toDouble(),
      minimum: 5,
      insufficient:
          'We need more energy check-ins to identify your personal pattern.',
      summaryBuilder: (average, phases) => _energySummary(phases),
    );
    final painPattern = _dailyMetricPattern(
      name: 'Pain',
      logs: dailyLogs.where((log) => log.painLevel > 0).toList(),
      periods: scopedPeriods,
      valueFor: (log) => log.painLevel.toDouble(),
      minimum: 3,
      insufficient: 'Pain patterns will appear after a few pain logs.',
      summaryBuilder: (average, phases) {
        final top = _highestPhase(phases);
        return top == null
            ? 'Pain has been logged, but not enough to identify timing.'
            : 'Pain was logged most often around $top based on your Quevaa logs.';
      },
    );
    final sleepPattern = _sleepPattern(dailyLogs, sleeps, scopedPeriods);
    final moodPattern = _moodPattern(dailyLogs, moods);
    final stressPattern = _stressPattern(dailyLogs);
    final productivityPattern = _productivityPattern(tasks, focus, dailyLogs);
    final ttcPattern = input.ttcEnabled
        ? _ttcPattern(
            input.basalTemperatureCount,
            input.cervicalMucusCount,
            input.ovulationTestCount,
            input.pregnancyTestCount,
          )
        : null;

    return CycleInsightsResult(
      range: range,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
      periodCount: scopedPeriods.length,
      completedPeriodCount: scopedPeriods
          .where((p) => p.endDate != null)
          .length,
      trackedCycleCount: cycleLengths.length,
      cycleLengths: cycleLengths,
      averageCycleLength: averageCycle,
      shortestCycleLength: cycleLengths.isEmpty
          ? null
          : cycleLengths.map((point) => point.lengthDays).reduce(math.min),
      longestCycleLength: cycleLengths.isEmpty
          ? null
          : cycleLengths.map((point) => point.lengthDays).reduce(math.max),
      cycleVariability: variability,
      regularityLabel: _regularityLabel(variability, cycleLengths.length),
      periodDurations: periodDurations,
      averagePeriodDuration: averagePeriod,
      symptomPatterns: symptomPatterns,
      energyPattern: energyPattern,
      painPattern: painPattern,
      sleepPattern: sleepPattern,
      moodPattern: moodPattern,
      stressPattern: stressPattern,
      productivityPattern: productivityPattern,
      ttcPattern: ttcPattern,
      personalInsights: _personalInsights(
        cycleLengths: cycleLengths,
        symptomPatterns: symptomPatterns,
        energyPattern: energyPattern,
        painPattern: painPattern,
        sleepPattern: sleepPattern,
      ),
    );
  }

  List<CyclePeriod> _scopePeriods(
    List<CyclePeriod> periods,
    CycleInsightRange range, {
    DateTime? windowStart,
    DateTime? windowEnd,
  }) {
    final windowed = periods.where((period) {
      if (windowStart == null && windowEnd == null) return true;
      final periodEnd = period.endDate ?? period.startDate;
      final startsBeforeEnd =
          windowEnd == null || !period.startDate.isAfter(windowEnd);
      final endsAfterStart =
          windowStart == null || !periodEnd.isBefore(windowStart);
      return startsBeforeEnd && endsAfterStart;
    }).toList();
    final limit = range.cycleLimit;
    if (limit == null || windowed.length <= limit + 1) return windowed;
    return windowed.sublist(windowed.length - limit - 1);
  }

  List<T> _between<T>(
    List<T> values,
    DateTime? Function(T value) dateFor,
    DateTime? start,
    DateTime? end,
  ) {
    if (start == null || end == null) return const [];
    return values.where((value) {
      final date = dateFor(value);
      if (date == null) return false;
      final normalized = normalizeDate(date);
      return !normalized.isBefore(normalizeDate(start)) &&
          !normalized.isAfter(normalizeDate(end));
    }).toList();
  }

  List<CycleLengthPoint> _cycleLengths(List<CyclePeriod> periods) {
    final points = <CycleLengthPoint>[];
    for (var index = 0; index < periods.length - 1; index++) {
      final length = normalizeDate(
        periods[index + 1].startDate,
      ).difference(normalizeDate(periods[index].startDate)).inDays;
      if (length >= 15 && length <= 60) {
        points.add(
          CycleLengthPoint(
            startDate: periods[index].startDate,
            lengthDays: length,
            cycleNumber: points.length + 1,
          ),
        );
      }
    }
    return points;
  }

  Map<DateTime, Set<String>> _mergedSymptoms(
    List<DailyLog> dailyLogs,
    List<SymptomEntry> symptomEntries,
  ) {
    final byDay = <DateTime, Set<String>>{};
    for (final entry in symptomEntries) {
      byDay
          .putIfAbsent(normalizeDate(entry.date), () => {})
          .add(entry.symptomCategory.trim());
    }
    for (final log in dailyLogs) {
      final decoded = _decodeSymptoms(log.customSymptomsJson);
      if (decoded.isEmpty) continue;
      byDay.putIfAbsent(normalizeDate(log.date), () => {}).addAll(decoded);
    }
    byDay.removeWhere((_, values) => values.where((v) => v.isNotEmpty).isEmpty);
    return byDay;
  }

  List<String> _decodeSymptoms(String value) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is List) {
        return decoded.map((item) => item.toString().trim()).where((item) {
          return item.isNotEmpty;
        }).toList();
      }
    } catch (_) {
      return const [];
    }
    return const [];
  }

  List<SymptomPattern> _symptomPatterns(
    Map<DateTime, Set<String>> symptomsByDay,
    List<CyclePeriod> periods,
  ) {
    final grouped = <String, List<DateTime>>{};
    for (final entry in symptomsByDay.entries) {
      for (final symptom in entry.value) {
        grouped.putIfAbsent(symptom, () => []).add(entry.key);
      }
    }
    final patterns =
        grouped.entries.map((entry) {
          final cycleIndexes = <int>{};
          final cycleDays = <int>[];
          final phases = <String, int>{};
          for (final date in entry.value) {
            final context = _cycleContextFor(date, periods);
            if (context == null) continue;
            cycleIndexes.add(context.cycleIndex);
            cycleDays.add(context.cycleDay);
            phases.update(
              context.phase,
              (count) => count + 1,
              ifAbsent: () => 1,
            );
          }
          cycleDays.sort();
          final timing = cycleDays.isEmpty
              ? 'timing still needs more logs'
              : _timingLabel(cycleDays, phases);
          return SymptomPattern(
            symptom: entry.key,
            loggedDays: entry.value.length,
            cycleCount: cycleIndexes.length,
            timingSummary: timing,
            explanation:
                'Based on ${entry.value.length} logged day${entry.value.length == 1 ? '' : 's'} across ${cycleIndexes.length} cycle${cycleIndexes.length == 1 ? '' : 's'}.',
          );
        }).toList()..sort((a, b) {
          final count = b.loggedDays.compareTo(a.loggedDays);
          return count == 0 ? a.symptom.compareTo(b.symptom) : count;
        });
    return patterns.take(6).toList();
  }

  MetricPattern _dailyMetricPattern({
    required String name,
    required List<DailyLog> logs,
    required List<CyclePeriod> periods,
    required double Function(DailyLog log) valueFor,
    required int minimum,
    required String insufficient,
    required String Function(double average, Map<String, double> phases)
    summaryBuilder,
  }) {
    if (logs.length < minimum) {
      return MetricPattern(
        name: name,
        observationCount: logs.length,
        average: null,
        summary: insufficient,
        explanation:
            'Based on ${logs.length} logged value${logs.length == 1 ? '' : 's'}.',
        phaseAverages: const {},
      );
    }
    final values = logs.map(valueFor).toList();
    final phaseValues = <String, List<double>>{};
    for (final log in logs) {
      final context = _cycleContextFor(log.date, periods);
      if (context == null) continue;
      phaseValues.putIfAbsent(context.phase, () => []).add(valueFor(log));
    }
    final phaseAverages = {
      for (final entry in phaseValues.entries)
        if (entry.value.length >= 2) entry.key: _average(entry.value),
    };
    final average = _average(values);
    return MetricPattern(
      name: name,
      observationCount: logs.length,
      average: average,
      summary: summaryBuilder(average, phaseAverages),
      explanation:
          'Based on ${logs.length} ${name.toLowerCase()} check-in${logs.length == 1 ? '' : 's'} across your selected cycle history.',
      phaseAverages: phaseAverages,
    );
  }

  MetricPattern _sleepPattern(
    List<DailyLog> dailyLogs,
    List<SleepEntry> sleepEntries,
    List<CyclePeriod> periods,
  ) {
    final byDate = <DateTime, double>{};
    for (final entry in sleepEntries) {
      byDate[normalizeDate(entry.date)] = entry.durationHours;
    }
    for (final log in dailyLogs) {
      final hours = log.sleepHours;
      if (hours != null) byDate[normalizeDate(log.date)] = hours;
    }
    final sleepLogs = byDate.entries.map((entry) {
      return _MetricLog(date: entry.key, value: entry.value);
    }).toList();
    if (sleepLogs.length < 5) {
      return MetricPattern(
        name: 'Sleep',
        observationCount: sleepLogs.length,
        average: null,
        summary: 'We need more sleep logs to identify your personal pattern.',
        explanation:
            'Based on ${sleepLogs.length} sleep log${sleepLogs.length == 1 ? '' : 's'}.',
        phaseAverages: const {},
      );
    }
    final phases = <String, List<double>>{};
    for (final log in sleepLogs) {
      final context = _cycleContextFor(log.date, periods);
      if (context == null) continue;
      phases.putIfAbsent(context.phase, () => []).add(log.value);
    }
    final phaseAverages = {
      for (final entry in phases.entries)
        if (entry.value.length >= 2) entry.key: _average(entry.value),
    };
    final average = _average(sleepLogs.map((log) => log.value));
    return MetricPattern(
      name: 'Sleep',
      observationCount: sleepLogs.length,
      average: average,
      summary: phaseAverages.isEmpty
          ? 'Average logged sleep is ${average.toStringAsFixed(1)}h.'
          : 'Average logged sleep is ${average.toStringAsFixed(1)}h, with phase comparisons based only on days you logged sleep.',
      explanation: 'Based on ${sleepLogs.length} sleep logs.',
      phaseAverages: phaseAverages,
    );
  }

  TextPattern _moodPattern(List<DailyLog> dailyLogs, List<MoodEntry> moods) {
    final values = <String>[];
    values.addAll(
      dailyLogs
          .map((log) => log.mood)
          .whereType<String>()
          .where((mood) => mood.isNotEmpty),
    );
    values.addAll(
      moods.map((entry) => entry.moodType).where((mood) => mood.isNotEmpty),
    );
    if (values.length < 4) {
      return TextPattern(
        name: 'Mood',
        observationCount: values.length,
        summary: 'Mood patterns will appear after more mood check-ins.',
        explanation:
            'Based on ${values.length} mood log${values.length == 1 ? '' : 's'}.',
      );
    }
    final counts = _counts(values);
    final top = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return TextPattern(
      name: 'Mood',
      observationCount: values.length,
      summary:
          '${top.first.key} is your most commonly logged mood in this range.',
      explanation: 'Based on ${values.length} mood logs recorded in Quevaa.',
    );
  }

  TextPattern _stressPattern(List<DailyLog> dailyLogs) {
    final values = dailyLogs.map((log) => log.stressLevel).toList();
    if (values.length < 5) {
      return TextPattern(
        name: 'Stress',
        observationCount: values.length,
        summary: 'Stress patterns will appear after more daily check-ins.',
        explanation:
            'Based on ${values.length} stress check-in${values.length == 1 ? '' : 's'}.',
      );
    }
    final highStress = values.where((value) => value >= 4).length;
    return TextPattern(
      name: 'Stress',
      observationCount: values.length,
      summary: highStress == 0
          ? 'High stress was not common in this range based on your Quevaa logs.'
          : 'Higher stress was logged on $highStress of ${values.length} tracked days.',
      explanation: 'Based on ${values.length} stress check-ins.',
    );
  }

  ProductivityPattern _productivityPattern(
    List<Task> tasks,
    List<FocusSession> focusSessions,
    List<DailyLog> dailyLogs,
  ) {
    final completedTasks = tasks.where((task) => task.isCompleted).length;
    final completedFocus = focusSessions.where((session) {
      return session.status.toLowerCase() == 'completed' ||
          session.completedAt != null;
    }).length;
    final hasEnough = tasks.length >= 3 || focusSessions.length >= 2;
    return ProductivityPattern(
      taskCount: tasks.length,
      completedTaskCount: completedTasks,
      focusSessionCount: focusSessions.length,
      completedFocusSessionCount: completedFocus,
      summary: hasEnough
          ? 'Completed $completedTasks of ${tasks.length} selected-range tasks and $completedFocus of ${focusSessions.length} focus sessions.'
          : 'Productivity patterns will appear after more tasks or focus sessions.',
      explanation:
          'Based on ${tasks.length} tasks, ${focusSessions.length} focus sessions, and ${dailyLogs.length} daily check-ins in this range.',
    );
  }

  TtcPattern _ttcPattern(int bbt, int mucus, int lh, int pregnancy) {
    final total = bbt + mucus + lh + pregnancy;
    return TtcPattern(
      basalTemperatureCount: bbt,
      cervicalMucusCount: mucus,
      ovulationTestCount: lh,
      pregnancyTestCount: pregnancy,
      summary: total == 0
          ? 'TTC mode is on, but no TTC observations are logged in this range.'
          : 'TTC mode is on with $bbt BBT, $lh LH, $mucus cervical mucus, and $pregnancy pregnancy-test record${pregnancy == 1 ? '' : 's'}.',
    );
  }

  List<String> _personalInsights({
    required List<CycleLengthPoint> cycleLengths,
    required List<SymptomPattern> symptomPatterns,
    required MetricPattern energyPattern,
    required MetricPattern painPattern,
    required MetricPattern sleepPattern,
  }) {
    final insights = <String>[];
    if (cycleLengths.length >= 3) {
      final low = cycleLengths
          .map((point) => point.lengthDays)
          .reduce(math.min);
      final high = cycleLengths
          .map((point) => point.lengthDays)
          .reduce(math.max);
      insights.add('Your recent cycles have ranged from $low-$high days.');
    }
    if (symptomPatterns.isNotEmpty) {
      final top = symptomPatterns.first;
      insights.add(
        '${top.symptom} is your most commonly logged symptom in this range.',
      );
    }
    for (final pattern in [energyPattern, painPattern, sleepPattern]) {
      if (pattern.average != null) insights.add(pattern.summary);
    }
    return insights.take(5).toList();
  }

  _CycleContext? _cycleContextFor(DateTime date, List<CyclePeriod> periods) {
    if (periods.isEmpty) return null;
    final normalized = normalizeDate(date);
    for (var index = periods.length - 1; index >= 0; index--) {
      final start = normalizeDate(periods[index].startDate);
      if (normalized.isBefore(start)) continue;
      final nextStart = index < periods.length - 1
          ? normalizeDate(periods[index + 1].startDate)
          : null;
      if (nextStart != null && !normalized.isBefore(nextStart)) continue;
      final cycleDay = normalized.difference(start).inDays + 1;
      final periodDuration = periods[index].endDate == null
          ? 5
          : _daysInclusive(periods[index].startDate, periods[index].endDate!);
      return _CycleContext(
        cycleIndex: index,
        cycleDay: cycleDay,
        phase: _phaseFor(cycleDay, periodDuration),
      );
    }
    return null;
  }

  String _phaseFor(int cycleDay, int periodDuration) {
    if (cycleDay <= periodDuration.clamp(1, 10)) return 'menstrual';
    if (cycleDay <= 13) return 'follicular';
    if (cycleDay <= 16) return 'ovulation window';
    return 'luteal';
  }

  String _timingLabel(List<int> cycleDays, Map<String, int> phases) {
    if (cycleDays.length >= 2) {
      final low = cycleDays.first;
      final high = cycleDays.last;
      if (high - low <= 3) {
        return low == high
            ? 'mostly cycle day $low'
            : 'mostly cycle days $low-$high';
      }
    }
    if (phases.isNotEmpty) {
      final top = phases.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      return 'most often ${top.first.key}';
    }
    return 'timing still needs more logs';
  }

  String _energySummary(Map<String, double> phases) {
    if (phases.isEmpty) {
      return 'Energy has enough logs for an average, but not enough phase-specific comparison yet.';
    }
    final low = _lowestPhase(phases);
    final high = _highestPhase(phases);
    if (low == null || high == null || low == high) {
      return 'Energy has been fairly similar across the phases with enough logs based on your Quevaa logs.';
    }
    return 'Energy has tended to be lower around $low and higher around $high based on your Quevaa logs.';
  }

  String? _highestPhase(Map<String, double> phases) {
    if (phases.isEmpty) return null;
    return phases.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  String? _lowestPhase(Map<String, double> phases) {
    if (phases.isEmpty) return null;
    return phases.entries.reduce((a, b) => a.value <= b.value ? a : b).key;
  }

  String _regularityLabel(double? variability, int cycleCount) {
    if (cycleCount < 3 || variability == null) return 'Learning';
    if (variability < 2.5) return 'Consistent';
    if (variability < 5) return 'Some variation';
    return 'Highly variable';
  }

  int _daysInclusive(DateTime start, DateTime end) {
    return normalizeDate(end).difference(normalizeDate(start)).inDays + 1;
  }

  double _average(Iterable<double> values) {
    final list = values.toList();
    if (list.isEmpty) return 0;
    return list.reduce((a, b) => a + b) / list.length;
  }

  double _standardDeviation(Iterable<double> values) {
    final list = values.toList();
    if (list.isEmpty) return 0;
    final mean = _average(list);
    final variance =
        list
            .map((value) => math.pow(value - mean, 2).toDouble())
            .reduce((a, b) => a + b) /
        list.length;
    return math.sqrt(variance);
  }

  Map<String, int> _counts(Iterable<String> values) {
    final counts = <String, int>{};
    for (final value in values) {
      counts.update(value, (count) => count + 1, ifAbsent: () => 1);
    }
    return counts;
  }
}

class _CycleContext {
  final int cycleIndex;
  final int cycleDay;
  final String phase;

  const _CycleContext({
    required this.cycleIndex,
    required this.cycleDay,
    required this.phase,
  });
}

class _MetricLog {
  final DateTime date;
  final double value;

  const _MetricLog({required this.date, required this.value});
}
