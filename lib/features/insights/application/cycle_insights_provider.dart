import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../../conception/application/conception_settings_provider.dart';
import '../domain/cycle_insights_analyzer.dart';

final cycleInsightsRangeProvider = StateProvider<CycleInsightRange>((ref) {
  return CycleInsightRange.last6Cycles;
});

final cycleInsightsProvider =
    FutureProvider.family<CycleInsightsResult, CycleInsightRange>((
      ref,
      range,
    ) async {
      final db = ref.watch(appDatabaseProvider);
      final ttcEnabled =
          ref.watch(persistedConceptionModeActiveProvider).valueOrNull ?? false;
      final input = await CycleInsightsRepository(
        db,
      ).loadInput(ttcEnabled: ttcEnabled);
      return const CycleInsightsAnalyzer().analyze(input: input, range: range);
    });

class CycleInsightsRepository {
  const CycleInsightsRepository(this.db);

  final AppDatabase db;

  Future<CycleInsightsInput> loadInput({required bool ttcEnabled}) async {
    final periods =
        await (db.select(db.cyclePeriods)
              ..where((tbl) => tbl.deletedAt.isNull())
              ..orderBy([(tbl) => OrderingTerm.asc(tbl.startDate)]))
            .get();
    final dailyLogs =
        await (db.select(db.dailyLogs)
              ..where((tbl) => tbl.deletedAt.isNull())
              ..orderBy([(tbl) => OrderingTerm.asc(tbl.date)]))
            .get();
    final symptoms =
        await (db.select(db.symptomEntries)
              ..where((tbl) => tbl.deletedAt.isNull())
              ..orderBy([(tbl) => OrderingTerm.asc(tbl.date)]))
            .get();
    final moods =
        await (db.select(db.moodEntries)
              ..where((tbl) => tbl.deletedAt.isNull())
              ..orderBy([(tbl) => OrderingTerm.asc(tbl.date)]))
            .get();
    final sleeps =
        await (db.select(db.sleepEntries)
              ..where((tbl) => tbl.deletedAt.isNull())
              ..orderBy([(tbl) => OrderingTerm.asc(tbl.date)]))
            .get();
    final tasks =
        await (db.select(db.tasks)
              ..where((tbl) => tbl.deletedAt.isNull())
              ..orderBy([(tbl) => OrderingTerm.asc(tbl.scheduledDate)]))
            .get();
    final focusSessions =
        await (db.select(db.focusSessions)
              ..where((tbl) => tbl.deletedAt.isNull())
              ..orderBy([(tbl) => OrderingTerm.asc(tbl.startedAt)]))
            .get();

    return CycleInsightsInput(
      periods: periods,
      dailyLogs: dailyLogs,
      symptomEntries: symptoms,
      moodEntries: moods,
      sleepEntries: sleeps,
      tasks: tasks,
      focusSessions: focusSessions,
      ttcEnabled: ttcEnabled,
      basalTemperatureCount: ttcEnabled
          ? await db
                .select(db.basalTemperatureEntries)
                .get()
                .then((rows) => rows.length)
          : 0,
      cervicalMucusCount: ttcEnabled
          ? await db
                .select(db.cervicalMucusEntries)
                .get()
                .then((rows) => rows.length)
          : 0,
      ovulationTestCount: ttcEnabled
          ? await db
                .select(db.ovulationTestEntries)
                .get()
                .then((rows) => rows.length)
          : 0,
      pregnancyTestCount: ttcEnabled
          ? await db
                .select(db.pregnancyTestEntries)
                .get()
                .then((rows) => rows.length)
          : 0,
    );
  }
}
