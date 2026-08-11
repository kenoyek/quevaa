import 'dart:typed_data';

import '../../insights/domain/cycle_insights_analyzer.dart';

enum HealthReportType {
  cycleSummary('Cycle summary'),
  detailedHealth('Detailed health report');

  const HealthReportType(this.label);

  final String label;
}

enum HealthReportRange {
  last3Cycles('Last 3 cycles', CycleInsightRange.last3Cycles),
  last6Cycles('Last 6 cycles', CycleInsightRange.last6Cycles),
  last12Months('Last 12 months', CycleInsightRange.all),
  custom('Custom range', CycleInsightRange.all),
  allTracked('All tracked cycles', CycleInsightRange.all);

  const HealthReportRange(this.label, this.insightRange);

  final String label;
  final CycleInsightRange insightRange;
}

class HealthReportOptions {
  final HealthReportType type;
  final HealthReportRange range;
  final bool includeNotes;
  final bool includeJournal;
  final bool includeTtc;
  final bool includeIntimacy;
  final DateTime? customStartDate;
  final DateTime? customEndDate;

  const HealthReportOptions({
    this.type = HealthReportType.cycleSummary,
    this.range = HealthReportRange.last3Cycles,
    this.includeNotes = false,
    this.includeJournal = false,
    this.includeTtc = false,
    this.includeIntimacy = false,
    this.customStartDate,
    this.customEndDate,
  });

  HealthReportOptions copyWith({
    HealthReportType? type,
    HealthReportRange? range,
    bool? includeNotes,
    bool? includeJournal,
    bool? includeTtc,
    bool? includeIntimacy,
    DateTime? customStartDate,
    DateTime? customEndDate,
    bool clearCustomStartDate = false,
    bool clearCustomEndDate = false,
  }) {
    return HealthReportOptions(
      type: type ?? this.type,
      range: range ?? this.range,
      includeNotes: includeNotes ?? this.includeNotes,
      includeJournal: includeJournal ?? this.includeJournal,
      includeTtc: includeTtc ?? this.includeTtc,
      includeIntimacy: includeIntimacy ?? this.includeIntimacy,
      customStartDate: clearCustomStartDate
          ? null
          : customStartDate ?? this.customStartDate,
      customEndDate: clearCustomEndDate
          ? null
          : customEndDate ?? this.customEndDate,
    );
  }

  bool get hasValidDateRange {
    if (range != HealthReportRange.custom) return true;
    final start = customStartDate;
    final end = customEndDate;
    return start != null && end != null && !end.isBefore(start);
  }
}

class HealthReportModel {
  final String userName;
  final DateTime generatedAt;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final HealthReportOptions options;
  final CycleInsightsResult insights;

  const HealthReportModel({
    required this.userName,
    required this.generatedAt,
    required this.periodStart,
    required this.periodEnd,
    required this.options,
    required this.insights,
  });

  bool get canGenerate =>
      options.hasValidDateRange && insights.hasAnyCycleHistory;

  List<String> get includedSections {
    final sections = <String>[
      'Cycle history',
      'Period length',
      'Flow',
      'Symptoms',
    ];
    if (options.type == HealthReportType.detailedHealth) {
      sections.addAll(['Pain', 'Mood', 'Sleep', 'Energy']);
    }
    if (options.includeNotes) sections.add('User notes');
    if (options.includeTtc && insights.ttcPattern != null) {
      sections.add('TTC observations');
    }
    if (options.includeJournal) sections.add('Journal excerpts');
    if (options.includeIntimacy) sections.add('Intimacy');
    return sections;
  }

  List<String> get excludedSensitiveSections {
    return [
      if (!options.includeTtc) 'TTC observations',
      if (!options.includeJournal) 'Journal excerpts',
      if (!options.includeIntimacy) 'Intimacy',
    ];
  }

  String get filenamePrefix => options.type == HealthReportType.cycleSummary
      ? 'Quevaa_Cycle_Report'
      : 'Quevaa_Health_Report';
}

class GeneratedHealthReport {
  final HealthReportModel model;
  final Uint8List bytes;
  final String filename;
  final String path;

  const GeneratedHealthReport({
    required this.model,
    required this.bytes,
    required this.filename,
    required this.path,
  });

  int get fileSizeBytes => bytes.length;
}
