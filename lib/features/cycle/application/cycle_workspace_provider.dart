import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../domain/cycle_engine.dart';
import '../domain/models/cycle_engine_output.dart';

DateTime normalizeDate(DateTime date) =>
    DateTime(date.year, date.month, date.day);

String localUuid(String prefix) =>
    '$prefix-${DateTime.now().microsecondsSinceEpoch}';

final selectedCycleDateProvider = StateProvider<DateTime>(
  (ref) => normalizeDate(DateTime.now()),
);

final visibleCycleMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

final cycleCalendarViewProvider = StreamProvider<String>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.appSettings)..limit(1)).watchSingleOrNull().map(
    (settings) => settings?.cycleCalendarView ?? 'Month',
  );
});

final periodHistoryProvider = StreamProvider<List<CyclePeriod>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.cyclePeriods)
        ..where((tbl) => tbl.deletedAt.isNull())
        ..orderBy([(tbl) => OrderingTerm.asc(tbl.startDate)]))
      .watch();
});

final currentCycleOutputProvider = Provider<CycleEngineOutput>((ref) {
  final history = ref.watch(periodHistoryProvider).valueOrNull ?? const [];
  final targetDate = ref.watch(selectedCycleDateProvider);
  return CycleEngine.calculate(
    periodHistory: [
      for (final period in history)
        CyclePeriodRecord(startDate: period.startDate, endDate: period.endDate),
    ],
    targetDate: targetDate,
  );
});

final cycleRangeProvider = Provider<({DateTime start, DateTime end})>((ref) {
  final month = ref.watch(visibleCycleMonthProvider);
  final view = ref.watch(cycleCalendarViewProvider).valueOrNull ?? 'Month';
  final first = DateTime(month.year, month.month);
  final months = switch (view) {
    'Three months' => 3,
    'Year' => 12,
    _ => 1,
  };
  final end = DateTime(first.year, first.month + months, 0);
  return (
    start: first.subtract(const Duration(days: 7)),
    end: end.add(const Duration(days: 7)),
  );
});

final cycleLogsInRangeProvider = StreamProvider<List<DailyLog>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final range = ref.watch(cycleRangeProvider);
  return (db.select(db.dailyLogs)..where(
        (tbl) =>
            tbl.deletedAt.isNull() &
            tbl.date.isBiggerOrEqualValue(range.start) &
            tbl.date.isSmallerOrEqualValue(range.end),
      ))
      .watch();
});

final symptomsInRangeProvider = StreamProvider<List<SymptomEntry>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final range = ref.watch(cycleRangeProvider);
  return (db.select(db.symptomEntries)..where(
        (tbl) =>
            tbl.deletedAt.isNull() &
            tbl.date.isBiggerOrEqualValue(range.start) &
            tbl.date.isSmallerOrEqualValue(range.end),
      ))
      .watch();
});

final selectedDayLogProvider = StreamProvider<DailyLog?>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final date = ref.watch(selectedCycleDateProvider);
  return (db.select(db.dailyLogs)
        ..where((tbl) => tbl.deletedAt.isNull() & tbl.date.equals(date))
        ..limit(1))
      .watchSingleOrNull();
});

final selectedDaySymptomsProvider = StreamProvider<List<SymptomEntry>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final date = ref.watch(selectedCycleDateProvider);
  return (db.select(db.symptomEntries)
        ..where((tbl) => tbl.deletedAt.isNull() & tbl.date.equals(date))
        ..orderBy([(tbl) => OrderingTerm.desc(tbl.severity)]))
      .watch();
});

final cycleWorkspaceControllerProvider =
    NotifierProvider<CycleWorkspaceController, bool>(
      CycleWorkspaceController.new,
    );

class CycleWorkspaceController extends Notifier<bool> {
  @override
  bool build() => false;

  AppDatabase get _db => ref.read(appDatabaseProvider);

  Future<void> setCalendarView(String view) async {
    final now = DateTime.now();
    final existing = await (_db.select(
      _db.appSettings,
    )..limit(1)).getSingleOrNull();
    if (existing == null) {
      await _db
          .into(_db.appSettings)
          .insert(
            AppSettingsCompanion.insert(
              uuid: localUuid('settings'),
              createdAt: now,
              updatedAt: now,
              cycleCalendarView: Value(view),
            ),
          );
      return;
    }
    await (_db.update(
      _db.appSettings,
    )..where((tbl) => tbl.id.equals(existing.id))).write(
      AppSettingsCompanion(
        updatedAt: Value(now),
        cycleCalendarView: Value(view),
      ),
    );
  }

  Future<void> saveDailyLog({
    required DateTime date,
    required String flow,
    required int pain,
    required String mood,
    required int energy,
    required int stress,
    required int sleepQuality,
    required int water,
    required List<String> symptoms,
    String? notes,
  }) async {
    if (state) return;
    state = true;
    try {
      final normalized = normalizeDate(date);
      final now = DateTime.now();
      final existing =
          await (_db.select(_db.dailyLogs)
                ..where(
                  (tbl) => tbl.deletedAt.isNull() & tbl.date.equals(normalized),
                )
                ..limit(1))
              .getSingleOrNull();
      final companion = DailyLogsCompanion(
        date: Value(normalized),
        flow: Value(flow),
        spotting: Value(flow == 'Spotting'),
        painLevel: Value(pain),
        mood: Value(mood),
        energyLevel: Value(energy),
        stressLevel: Value(stress),
        sleepQuality: Value(sleepQuality),
        waterGlasses: Value(water),
        customSymptomsJson: Value(jsonEncode(symptoms)),
        generalNotes: Value(notes),
        updatedAt: Value(now),
      );
      if (existing == null) {
        await _db
            .into(_db.dailyLogs)
            .insert(
              companion.copyWith(
                uuid: Value(localUuid('log')),
                createdAt: Value(now),
                updatedAt: Value(now),
              ),
            );
      } else {
        await (_db.update(
          _db.dailyLogs,
        )..where((tbl) => tbl.id.equals(existing.id))).write(companion);
      }

      await (_db.delete(_db.symptomEntries)..where(
            (tbl) =>
                tbl.date.equals(normalized) & tbl.source.equals('quick_log'),
          ))
          .go();
      for (final symptom in symptoms) {
        await _db
            .into(_db.symptomEntries)
            .insert(
              SymptomEntriesCompanion.insert(
                uuid: localUuid('symptom'),
                createdAt: now,
                updatedAt: now,
                date: normalized,
                symptomCategory: symptom,
                severity: Value(pain.clamp(1, 5)),
                source: const Value('quick_log'),
              ),
            );
      }
    } finally {
      state = false;
    }
  }

  Future<void> startPeriod(DateTime date) async {
    if (state) return;
    state = true;
    try {
      final now = DateTime.now();
      await _db
          .into(_db.cyclePeriods)
          .insert(
            CyclePeriodsCompanion.insert(
              uuid: localUuid('period'),
              createdAt: now,
              updatedAt: now,
              startDate: normalizeDate(date),
              isOngoing: const Value(true),
              flowIntensity: const Value(3),
            ),
          );
    } finally {
      state = false;
    }
  }

  Future<void> endLatestPeriod(DateTime date) async {
    if (state) return;
    state = true;
    try {
      final latest =
          await (_db.select(_db.cyclePeriods)
                ..where(
                  (tbl) => tbl.deletedAt.isNull() & tbl.isOngoing.equals(true),
                )
                ..orderBy([(tbl) => OrderingTerm.desc(tbl.startDate)])
                ..limit(1))
              .getSingleOrNull();
      if (latest == null) return;
      await (_db.update(
        _db.cyclePeriods,
      )..where((tbl) => tbl.id.equals(latest.id))).write(
        CyclePeriodsCompanion(
          endDate: Value(normalizeDate(date)),
          isOngoing: const Value(false),
          updatedAt: Value(DateTime.now()),
        ),
      );
    } finally {
      state = false;
    }
  }

  Future<void> deleteSelectedLog(DateTime date) async {
    final normalized = normalizeDate(date);
    await (_db.update(
          _db.dailyLogs,
        )..where((tbl) => tbl.deletedAt.isNull() & tbl.date.equals(normalized)))
        .write(DailyLogsCompanion(deletedAt: Value(DateTime.now())));
  }
}
