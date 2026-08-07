import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/user_profile_provider.dart';
import '../../conception/application/conception_settings_provider.dart';
import '../../notifications/application/notification_preferences_provider.dart';
import '../../notifications/domain/services/notification_scheduler.dart';
import '../domain/cycle_engine.dart';
import '../domain/models/current_cycle_snapshot.dart';
import '../domain/models/cycle_engine_output.dart';

DateTime normalizeDate(DateTime date) =>
    DateTime(date.year, date.month, date.day);

String localUuid(String prefix) =>
    '$prefix-${DateTime.now().microsecondsSinceEpoch}';

final localTodayProvider = Provider<DateTime>((ref) {
  return normalizeDate(DateTime.now());
});

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

final currentCycleSnapshotProvider = Provider<CurrentCycleSnapshot>((ref) {
  final history = ref.watch(periodHistoryProvider).valueOrNull ?? const [];
  final today = ref.watch(localTodayProvider);
  final userProfile = ref.watch(userProfileProvider).valueOrNull;
  final isTtcEnabled = ref.watch(conceptionModeActiveProvider);

  final activePeriod = history
      .where((p) => p.isOngoing || p.endDate == null)
      .lastOrNull;
  final currentPeriodStart =
      activePeriod?.startDate ?? history.lastOrNull?.startDate;
  final currentPeriodEnd = activePeriod?.endDate ?? history.lastOrNull?.endDate;

  final output = CycleEngine.calculate(
    periodHistory: [
      for (final period in history)
        CyclePeriodRecord(startDate: period.startDate, endDate: period.endDate),
    ],
    targetDate: today,
    userConfiguredAverageCycleLength: userProfile?.averageCycleLength ?? 28,
    userConfiguredPeriodLength: userProfile?.averagePeriodLength ?? 5,
  );

  return output.toSnapshot(
    today,
    currentPeriodStart: currentPeriodStart,
    currentPeriodEnd: currentPeriodEnd,
    isPeriodActive: activePeriod != null,
    isTtcEnabled: isTtcEnabled,
  );
});

final currentCycleOutputProvider = Provider<CycleEngineOutput>((ref) {
  final history = ref.watch(periodHistoryProvider).valueOrNull ?? const [];
  final today = ref.watch(localTodayProvider);
  final userProfile = ref.watch(userProfileProvider).valueOrNull;
  return CycleEngine.calculate(
    periodHistory: [
      for (final period in history)
        CyclePeriodRecord(startDate: period.startDate, endDate: period.endDate),
    ],
    targetDate: today,
    userConfiguredAverageCycleLength: userProfile?.averageCycleLength ?? 28,
    userConfiguredPeriodLength: userProfile?.averagePeriodLength ?? 5,
  );
});

final selectedDayCycleSnapshotProvider = Provider<CurrentCycleSnapshot>((ref) {
  final history = ref.watch(periodHistoryProvider).valueOrNull ?? const [];
  final selectedDate = ref.watch(selectedCycleDateProvider);
  final userProfile = ref.watch(userProfileProvider).valueOrNull;
  final isTtcEnabled = ref.watch(conceptionModeActiveProvider);

  final output = CycleEngine.calculate(
    periodHistory: [
      for (final period in history)
        CyclePeriodRecord(startDate: period.startDate, endDate: period.endDate),
    ],
    targetDate: selectedDate,
    userConfiguredAverageCycleLength: userProfile?.averageCycleLength ?? 28,
    userConfiguredPeriodLength: userProfile?.averagePeriodLength ?? 5,
  );

  return output.toSnapshot(selectedDate, isTtcEnabled: isTtcEnabled);
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
      // Reconcile notifications after logging data
      await ref
          .read(notificationSchedulerProvider)
          .reconcileNotifications(
            NotificationReconciliationReason.cycleDataChanged,
          );
    } finally {
      state = false;
    }
  }

  Future<void> startPeriod(DateTime date) async {
    if (state) return;
    state = true;
    try {
      final now = DateTime.now();
      final normalized = normalizeDate(date);

      // Close any existing ongoing periods first
      final ongoing =
          await (_db.select(_db.cyclePeriods)
                ..where(
                  (tbl) => tbl.deletedAt.isNull() & tbl.isOngoing.equals(true),
                )
                ..get())
              .get();

      for (final period in ongoing) {
        await (_db.update(
          _db.cyclePeriods,
        )..where((tbl) => tbl.id.equals(period.id))).write(
          CyclePeriodsCompanion(
            isOngoing: const Value(false),
            endDate: Value(normalized.subtract(const Duration(days: 1))),
            updatedAt: Value(now),
          ),
        );
      }

      await _db
          .into(_db.cyclePeriods)
          .insert(
            CyclePeriodsCompanion.insert(
              uuid: localUuid('period'),
              createdAt: now,
              updatedAt: now,
              startDate: normalized,
              isOngoing: const Value(true),
              flowIntensity: const Value(3),
            ),
          );
      // Reconcile notifications after starting a period
      await ref
          .read(notificationSchedulerProvider)
          .reconcileNotifications(
            NotificationReconciliationReason.cycleDataChanged,
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
      // Reconcile notifications after ending a period
      await ref
          .read(notificationSchedulerProvider)
          .reconcileNotifications(
            NotificationReconciliationReason.cycleDataChanged,
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
