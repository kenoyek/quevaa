import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quevaa/core/database/app_database.dart';
import 'package:quevaa/core/models/prediction_confidence.dart';
import 'package:quevaa/core/providers/database_provider.dart';
import 'package:quevaa/features/cycle/application/cycle_workspace_provider.dart';
import 'package:quevaa/features/cycle/domain/models/estimated_cycle_phase.dart';
import 'package:quevaa/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:quevaa/features/notifications/application/notification_preferences_provider.dart';
import 'package:quevaa/features/notifications/domain/services/notification_scheduler.dart';
import 'package:quevaa/features/notifications/domain/services/smart_notification_engine.dart';
import 'package:mocktail/mocktail.dart';

class MockNotificationScheduler extends Mock implements NotificationScheduler {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(NotificationReconciliationReason.manualRefresh);
    registerFallbackValue(const NotificationSourceSnapshot());
  });

  late AppDatabase db;
  late MockNotificationScheduler mockScheduler;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    mockScheduler = MockNotificationScheduler();
    when(
      () => mockScheduler.reconcileNotifications(
        any(),
        snapshot: any(named: 'snapshot'),
      ),
    ).thenAnswer(
      (_) async => const NotificationReconciliationResult(
        reason: NotificationReconciliationReason.manualRefresh,
        desiredCount: 0,
        scheduledCount: 0,
        cancelledCount: 0,
        unchangedCount: 0,
        permissionGranted: true,
        timezone: 'UTC',
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'Canonical CurrentCycleSnapshot calculates correctly and updates reactively',
    () async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          notificationSchedulerProvider.overrideWithValue(mockScheduler),
        ],
      );
      addTearDown(container.dispose);

      await container.read(periodHistoryProvider.future);
      var snapshot = container.read(currentCycleSnapshotProvider);
      expect(snapshot.hasEnoughData, isFalse);
      expect(snapshot.phase, EstimatedCyclePhase.unknown);

      final controller = container.read(
        cycleWorkspaceControllerProvider.notifier,
      );
      final today = container.read(localTodayProvider);
      await controller.startPeriod(today.subtract(const Duration(days: 2)));
      container.invalidate(periodHistoryProvider);
      await container.read(periodHistoryProvider.future);

      snapshot = container.read(currentCycleSnapshotProvider);
      expect(snapshot.hasEnoughData, isTrue);
      expect(snapshot.cycleDay, 3);
      expect(snapshot.phase, EstimatedCyclePhase.menstrual);
      expect(formatPredictionConfidence(snapshot.confidence), 'Low');
    },
  );

  testWidgets(
    'DashboardPage renders cycle day, phase and confidence without .name exception',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          notificationSchedulerProvider.overrideWithValue(mockScheduler),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(
        cycleWorkspaceControllerProvider.notifier,
      );
      final today = container.read(localTodayProvider);
      await controller.startPeriod(today.subtract(const Duration(days: 2)));
      container.invalidate(periodHistoryProvider);
      await container.read(periodHistoryProvider.future);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: DashboardPage()),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Cycle Day 3'), findsOneWidget);
      expect(find.text('Period in progress'), findsOneWidget);
      expect(find.text('Menstrual phase'), findsOneWidget);
      expect(find.text('Menstrual'), findsOneWidget);
      expect(find.text('Follicular'), findsOneWidget);
      expect(find.text('Ovulatory'), findsOneWidget);
      expect(find.text('Luteal'), findsOneWidget);
      expect(find.text('Low confidence'), findsOneWidget);
    },
  );

  testWidgets('Today check-in saves explicitly and keeps existing notes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final today = DateTime(2026, 8, 8);
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        notificationSchedulerProvider.overrideWithValue(mockScheduler),
        localTodayProvider.overrideWithValue(today),
      ],
    );
    addTearDown(container.dispose);
    await container
        .read(cycleWorkspaceControllerProvider.notifier)
        .saveDailyLog(
          date: today,
          flow: 'None',
          pain: 2,
          mood: 'Calm',
          energy: 3,
          stress: 1,
          sleepQuality: 4,
          sleepHours: 7,
          water: 4,
          symptoms: ['Cramps'],
          notes: 'Keep this note',
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.4)),
            child: child!,
          ),
          home: const DashboardPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final edit = find.text('Edit check-in');
    await tester.ensureVisible(edit);
    await tester.tap(edit);
    await tester.pumpAndSettle();
    final energy = find.byType(Slider).first;
    tester.widget<Slider>(energy).onChanged!(5);
    await tester.pump();
    expect((await db.select(db.dailyLogs).get()).single.energyLevel, 3);
    final save = find.text('Save check-in');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    final updated = (await db.select(db.dailyLogs).get()).single;
    expect(updated.energyLevel, 5);
    expect(updated.sleepHours, 7);
    expect(updated.waterGlasses, 4);
    expect(updated.generalNotes, 'Keep this note');
    expect(updated.customSymptomsJson, contains('Cramps'));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  });

  group('formatPredictionConfidence regression', () {
    test('formats low confidence', () {
      expect(formatPredictionConfidence(PredictionConfidence.low), 'Low');
    });

    test('formats moderate confidence', () {
      expect(
        formatPredictionConfidence(PredictionConfidence.moderate),
        'Moderate',
      );
    });

    test('formats high confidence', () {
      expect(formatPredictionConfidence(PredictionConfidence.high), 'High');
    });

    test('mapStoredConfidence handles all stored values', () {
      expect(mapStoredConfidence('low'), PredictionConfidence.low);
      expect(mapStoredConfidence('moderate'), PredictionConfidence.moderate);
      expect(mapStoredConfidence('medium'), PredictionConfidence.moderate);
      expect(mapStoredConfidence('high'), PredictionConfidence.high);
      expect(mapStoredConfidence(null), PredictionConfidence.low);
      expect(mapStoredConfidence('unknown'), PredictionConfidence.low);
      expect(mapStoredConfidence(''), PredictionConfidence.low);
    });
  });
}
