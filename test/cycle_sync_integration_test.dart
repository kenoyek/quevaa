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
    when(() => mockScheduler.reconcileNotifications(any(), snapshot: any(named: 'snapshot')))
        .thenAnswer((_) async => const NotificationReconciliationResult(
              reason: NotificationReconciliationReason.manualRefresh,
              desiredCount: 0,
              scheduledCount: 0,
              cancelledCount: 0,
              unchangedCount: 0,
              permissionGranted: true,
              timezone: 'UTC',
            ));
  });

  tearDown(() async {
    await db.close();
  });

  test('Canonical CurrentCycleSnapshot calculates correctly and updates reactively', () async {
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

    final controller = container.read(cycleWorkspaceControllerProvider.notifier);
    final today = container.read(localTodayProvider);
    await controller.startPeriod(today.subtract(const Duration(days: 2)));
    container.invalidate(periodHistoryProvider);
    await container.read(periodHistoryProvider.future);

    snapshot = container.read(currentCycleSnapshotProvider);
    expect(snapshot.hasEnoughData, isTrue);
    expect(snapshot.cycleDay, 3);
    expect(snapshot.phase, EstimatedCyclePhase.menstrual);
    expect(formatPredictionConfidence(snapshot.confidence), 'Low');
  });

  testWidgets('DashboardPage renders cycle day, phase and confidence without .name exception', (tester) async {
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        notificationSchedulerProvider.overrideWithValue(mockScheduler),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(cycleWorkspaceControllerProvider.notifier);
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
    expect(find.text('Confidence: LOW'), findsOneWidget);
  });

  group('formatPredictionConfidence regression', () {
    test('formats low confidence', () {
      expect(formatPredictionConfidence(PredictionConfidence.low), 'Low');
    });

    test('formats moderate confidence', () {
      expect(formatPredictionConfidence(PredictionConfidence.moderate), 'Moderate');
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
