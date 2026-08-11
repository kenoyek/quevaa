import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quevaa/core/database/app_database.dart';
import 'package:quevaa/features/insights/application/cycle_insights_provider.dart';
import 'package:quevaa/features/insights/domain/cycle_insights_analyzer.dart';
import 'package:quevaa/features/reports/domain/health_report_model.dart';
import 'package:quevaa/features/reports/domain/pdf_health_report_generator.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'calculates cycle averages, range, variability and period durations',
    () async {
      await _seedPremiumFixture(db);

      final input = await CycleInsightsRepository(
        db,
      ).loadInput(ttcEnabled: true);
      final result = const CycleInsightsAnalyzer().analyze(
        input: input,
        range: CycleInsightRange.all,
      );

      expect(result.trackedCycleCount, 4);
      expect(result.cycleLengths.map((point) => point.lengthDays), [
        28,
        29,
        31,
        28,
      ]);
      expect(result.averageCycleLength, 29);
      expect(result.shortestCycleLength, 28);
      expect(result.longestCycleLength, 31);
      expect(result.cycleVariability!.toStringAsFixed(2), '1.22');
      expect(result.regularityLabel, 'Consistent');
      expect(result.periodDurations.take(4), [4, 4, 5, 4]);
      expect(result.averagePeriodDuration!.round(), 4);
    },
  );

  test(
    'keeps low-history users in learning mode without fake trends',
    () async {
      final now = DateTime(2026, 1, 1);
      await db
          .into(db.cyclePeriods)
          .insert(
            CyclePeriodsCompanion.insert(
              uuid: 'period-low',
              createdAt: now,
              updatedAt: now,
              startDate: DateTime(2026, 1, 1),
              endDate: Value(DateTime(2026, 1, 4)),
              isOngoing: const Value(false),
            ),
          );
      await _insertDailyLog(db, DateTime(2026, 1, 1), energy: 2, pain: 3);
      await _insertDailyLog(db, DateTime(2026, 1, 2), energy: 3, pain: 2);

      final input = await CycleInsightsRepository(
        db,
      ).loadInput(ttcEnabled: false);
      final result = const CycleInsightsAnalyzer().analyze(
        input: input,
        range: CycleInsightRange.all,
      );

      expect(result.isLowHistory, isTrue);
      expect(result.averageCycleLength, isNull);
      expect(result.regularityLabel, 'Learning');
      expect(result.energyPattern.summary, contains('more energy check-ins'));
      expect(result.personalInsights, isEmpty);
    },
  );

  test('groups symptom timing and wellbeing from actual logs', () async {
    await _seedPremiumFixture(db);

    final input = await CycleInsightsRepository(
      db,
    ).loadInput(ttcEnabled: false);
    final result = const CycleInsightsAnalyzer().analyze(
      input: input,
      range: CycleInsightRange.all,
    );

    final cramps = result.symptomPatterns.firstWhere(
      (pattern) => pattern.symptom == 'Cramps',
    );
    expect(cramps.loggedDays, 4);
    expect(cramps.timingSummary, contains('cycle days 1-2'));
    expect(result.energyPattern.observationCount, greaterThanOrEqualTo(5));
    expect(result.energyPattern.summary, contains('based on your Quevaa logs'));
    expect(result.sleepPattern.average!.toStringAsFixed(1), '7.1');
    expect(result.painPattern.summary, contains('logged'));
  });

  test(
    'health report excludes sensitive sections by default and PDF is valid',
    () async {
      await _seedPremiumFixture(db);

      final input = await CycleInsightsRepository(
        db,
      ).loadInput(ttcEnabled: true);
      final insights = const CycleInsightsAnalyzer().analyze(
        input: input,
        range: CycleInsightRange.all,
      );
      final defaultModel = HealthReportModel(
        userName: 'Adaora',
        generatedAt: DateTime(2026, 8, 11),
        periodStart: insights.rangeStart,
        periodEnd: insights.rangeEnd,
        options: const HealthReportOptions(
          type: HealthReportType.detailedHealth,
          range: HealthReportRange.allTracked,
        ),
        insights: insights,
      );

      expect(
        defaultModel.includedSections,
        isNot(contains('TTC observations')),
      );
      expect(
        defaultModel.includedSections,
        isNot(contains('Journal excerpts')),
      );
      expect(
        defaultModel.excludedSensitiveSections,
        contains('TTC observations'),
      );
      expect(
        defaultModel.excludedSensitiveSections,
        contains('Journal excerpts'),
      );
      expect(defaultModel.excludedSensitiveSections, contains('Intimacy'));

      final pdfBytes = await PdfHealthReportGenerator.generateHealthReport(
        defaultModel,
      );
      expect(pdfBytes.length, greaterThan(1000));
      expect(String.fromCharCodes(pdfBytes.take(4)), '%PDF');

      final file = File(
        '${Directory.systemTemp.path}/Quevaa_Health_Report_2026-08-11.pdf',
      );
      await file.writeAsBytes(pdfBytes, flush: true);
      expect(await file.exists(), isTrue);
      expect(await file.length(), greaterThan(1000));
      await file.delete();

      final ttcModel = HealthReportModel(
        userName: 'Adaora',
        generatedAt: DateTime(2026, 8, 11),
        periodStart: insights.rangeStart,
        periodEnd: insights.rangeEnd,
        options: const HealthReportOptions(
          type: HealthReportType.detailedHealth,
          range: HealthReportRange.allTracked,
          includeTtc: true,
        ),
        insights: insights,
      );
      expect(ttcModel.includedSections, contains('TTC observations'));
      expect(ttcModel.includedSections, isNot(contains('Intimacy')));
    },
  );
}

Future<void> _seedPremiumFixture(AppDatabase db) async {
  final now = DateTime(2026, 8, 11);
  final starts = [
    DateTime(2026, 1, 1),
    DateTime(2026, 1, 29),
    DateTime(2026, 2, 27),
    DateTime(2026, 3, 30),
    DateTime(2026, 4, 27),
  ];
  final ends = [
    DateTime(2026, 1, 4),
    DateTime(2026, 2, 1),
    DateTime(2026, 3, 3),
    DateTime(2026, 4, 2),
    DateTime(2026, 4, 30),
  ];

  for (var index = 0; index < starts.length; index++) {
    await db
        .into(db.cyclePeriods)
        .insert(
          CyclePeriodsCompanion.insert(
            uuid: 'period-$index',
            createdAt: now,
            updatedAt: now,
            startDate: starts[index],
            endDate: Value(ends[index]),
            isOngoing: const Value(false),
          ),
        );
  }

  await _insertDailyLog(
    db,
    DateTime(2026, 1, 1),
    energy: 2,
    pain: 3,
    sleep: 6.5,
    mood: 'Tender',
    stress: 4,
    symptoms: ['Cramps', 'Fatigue'],
  );
  await _insertDailyLog(
    db,
    DateTime(2026, 1, 2),
    energy: 2,
    pain: 2,
    sleep: 7.0,
    mood: 'Tender',
    stress: 3,
    symptoms: ['Cramps'],
  );
  await _insertDailyLog(db, DateTime(2026, 1, 14), energy: 5, sleep: 8.0);
  await _insertDailyLog(
    db,
    DateTime(2026, 1, 29),
    energy: 2,
    pain: 3,
    sleep: 6.8,
  );
  await _insertDailyLog(db, DateTime(2026, 2, 15), energy: 4, sleep: 7.5);
  await _insertDailyLog(
    db,
    DateTime(2026, 3, 30),
    energy: 2,
    pain: 4,
    sleep: 6.6,
  );
  await _insertDailyLog(
    db,
    DateTime(2026, 3, 31),
    energy: 3,
    pain: 3,
    sleep: 7.0,
  );

  for (final date in [
    DateTime(2026, 1, 1),
    DateTime(2026, 1, 2),
    DateTime(2026, 1, 29),
    DateTime(2026, 3, 30),
  ]) {
    await db
        .into(db.symptomEntries)
        .insert(
          SymptomEntriesCompanion.insert(
            uuid: 'symptom-${date.toIso8601String()}',
            createdAt: now,
            updatedAt: now,
            date: date,
            symptomCategory: 'Cramps',
            severity: const Value(3),
          ),
        );
  }

  await db
      .into(db.basalTemperatureEntries)
      .insert(
        BasalTemperatureEntriesCompanion.insert(
          measuredAt: DateTime(2026, 3, 10, 7),
          temperature: 36.6,
        ),
      );
  await db
      .into(db.ovulationTestEntries)
      .insert(
        OvulationTestEntriesCompanion.insert(
          testedAt: DateTime(2026, 3, 13, 9),
          result: 'positive',
        ),
      );
  await db
      .into(db.cervicalMucusEntries)
      .insert(
        CervicalMucusEntriesCompanion.insert(
          date: DateTime(2026, 3, 12),
          type: 'egg-white',
        ),
      );
  await db
      .into(db.pregnancyTestEntries)
      .insert(
        PregnancyTestEntriesCompanion.insert(
          testedAt: DateTime(2026, 4, 24, 8),
          result: 'negative',
        ),
      );
}

Future<void> _insertDailyLog(
  AppDatabase db,
  DateTime date, {
  int energy = 3,
  int pain = 0,
  double? sleep,
  String mood = 'Calm',
  int stress = 2,
  List<String> symptoms = const [],
}) async {
  final now = DateTime(2026, 8, 11);
  await db
      .into(db.dailyLogs)
      .insert(
        DailyLogsCompanion.insert(
          uuid: 'log-${date.toIso8601String()}',
          createdAt: now,
          updatedAt: now,
          date: date,
          energyLevel: Value(energy),
          painLevel: Value(pain),
          sleepHours: Value(sleep),
          mood: Value(mood),
          stressLevel: Value(stress),
          customSymptomsJson: Value(
            symptoms.map((symptom) => '"$symptom"').join(',').isEmpty
                ? '[]'
                : '[${symptoms.map((symptom) => '"$symptom"').join(',')}]',
          ),
        ),
      );
}
