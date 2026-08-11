import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/user_profile_provider.dart';
import '../../conception/application/conception_settings_provider.dart';
import '../../cycle/application/cycle_workspace_provider.dart';
import '../../insights/application/cycle_insights_provider.dart';
import '../../insights/domain/cycle_insights_analyzer.dart';
import '../domain/health_report_model.dart';
import '../domain/pdf_health_report_generator.dart';

final healthReportOptionsProvider = StateProvider<HealthReportOptions>((ref) {
  return const HealthReportOptions();
});

final healthReportModelProvider = FutureProvider<HealthReportModel>((
  ref,
) async {
  final options = ref.watch(healthReportOptionsProvider);
  final profile = await ref.watch(userProfileProvider.future);
  final generatedAt = DateTime.now();
  final customWindow = _reportWindow(options, generatedAt);
  final insights = customWindow == null
      ? await ref.watch(
          cycleInsightsProvider(options.range.insightRange).future,
        )
      : await _customRangeInsights(ref, options, customWindow);

  return HealthReportModel(
    userName: profile?.userName ?? '',
    generatedAt: generatedAt,
    periodStart: insights.rangeStart,
    periodEnd: insights.rangeEnd,
    options: options,
    insights: insights,
  );
});

Future<CycleInsightsResult> _customRangeInsights(
  Ref ref,
  HealthReportOptions options,
  ({DateTime start, DateTime end}) window,
) async {
  final db = ref.watch(appDatabaseProvider);
  final ttcEnabled =
      ref.watch(persistedConceptionModeActiveProvider).valueOrNull ?? false;
  final input = await CycleInsightsRepository(
    db,
  ).loadInput(ttcEnabled: ttcEnabled);
  return const CycleInsightsAnalyzer().analyze(
    input: input,
    range: options.range.insightRange,
    windowStart: window.start,
    windowEnd: window.end,
  );
}

({DateTime start, DateTime end})? _reportWindow(
  HealthReportOptions options,
  DateTime now,
) {
  switch (options.range) {
    case HealthReportRange.last12Months:
      return (
        start: DateTime(now.year - 1, now.month, now.day),
        end: DateTime(now.year, now.month, now.day, 23, 59, 59),
      );
    case HealthReportRange.custom:
      final start = options.customStartDate;
      final end = options.customEndDate;
      if (start == null || end == null || end.isBefore(start)) return null;
      return (
        start: DateTime(start.year, start.month, start.day),
        end: DateTime(end.year, end.month, end.day, 23, 59, 59),
      );
    case HealthReportRange.last3Cycles:
    case HealthReportRange.last6Cycles:
    case HealthReportRange.allTracked:
      return null;
  }
}

final generatedHealthReportProvider = StateProvider<GeneratedHealthReport?>(
  (ref) => null,
);

final healthReportControllerProvider =
    StateNotifierProvider<HealthReportController, AsyncValue<void>>(
      HealthReportController.new,
    );

class HealthReportController extends StateNotifier<AsyncValue<void>> {
  HealthReportController(this.ref) : super(const AsyncValue.data(null));

  final Ref ref;

  Future<void> generatePdf() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final model = await ref.read(healthReportModelProvider.future);
      if (!model.canGenerate) {
        throw StateError(
          "There's not enough cycle history to create this report yet.",
        );
      }

      final bytes = await PdfHealthReportGenerator.generateHealthReport(model);
      if (bytes.isEmpty) {
        throw StateError('The PDF generator returned an empty file.');
      }

      final filename =
          '${model.filenamePrefix}_${_filenameDate(model.generatedAt)}.pdf';
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/$filename');
      await file.writeAsBytes(bytes, flush: true);
      if (!await file.exists() || await file.length() == 0) {
        throw StateError('The PDF file could not be written.');
      }

      final db = ref.read(appDatabaseProvider);
      final now = DateTime.now();
      await db
          .into(db.exportHistory)
          .insert(
            ExportHistoryCompanion.insert(
              uuid: localUuid('export'),
              createdAt: now,
              updatedAt: now,
              exportedAt: now,
              exportType: 'pdf',
              destination: file.path,
            ),
          );

      ref
          .read(generatedHealthReportProvider.notifier)
          .state = GeneratedHealthReport(
        model: model,
        bytes: bytes,
        filename: filename,
        path: file.path,
      );
    });
  }

  Future<void> shareGeneratedReport() async {
    final report = ref.read(generatedHealthReportProvider);
    if (report == null) {
      throw StateError('Generate a report before sharing.');
    }
    await Share.shareXFiles([
      XFile(report.path, mimeType: 'application/pdf', name: report.filename),
    ], text: 'Quevaa health report');
  }

  String _filenameDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
