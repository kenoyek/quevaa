import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quevaa/core/database/app_database.dart';
import 'package:quevaa/core/providers/database_provider.dart';
import 'package:quevaa/features/cycle/domain/cycle_engine.dart';
import 'package:quevaa/features/cycle/domain/models/cycle_calendar_phase.dart';
import 'package:quevaa/features/cycle/presentation/pages/cycle_workspace_page.dart';
import 'package:quevaa/features/notifications/application/notification_preferences_provider.dart';
import 'package:quevaa/features/notifications/domain/services/notification_scheduler.dart';
import 'package:quevaa/features/notifications/domain/services/smart_notification_engine.dart';

class MockNotificationScheduler extends Mock implements NotificationScheduler {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(NotificationReconciliationReason.manualRefresh);
    registerFallbackValue(const NotificationSourceSnapshot());
  });

  group('Requirement 18: Calendar-State Assertions for August 2026', () {
    test(
      'Correctly identifies bleeding range 8–11 August and exact phase states',
      () {
        final history = [
          CyclePeriodRecord(
            startDate: DateTime(2026, 7, 11),
            endDate: DateTime(2026, 7, 14), // 4 days duration
          ),
        ];

        final output = CycleEngine.calculate(
          periodHistory: history,
          targetDate: DateTime(2026, 8, 1),
          userConfiguredPeriodLength: 4,
          userConfiguredAverageCycleLength: 28,
        );

        final pred = output.periodPredictions.first;
        expect(pred.estimatedStartDate, DateTime(2026, 8, 8));
        expect(pred.predictedBleedingRange.start, DateTime(2026, 8, 8));
        expect(pred.predictedBleedingRange.end, DateTime(2026, 8, 11));

        // Assertions for specific August 2026 dates:
        // 7 August is NOT a central predicted bleeding day
        expect(
          output.getCalendarPhase(DateTime(2026, 8, 7), history: history),
          isNot(CycleCalendarPhase.menstrual),
        );
        expect(pred.isBleedingDay(DateTime(2026, 8, 7)), false);

        // 8 August is central predicted bleeding start
        expect(pred.isBleedingDay(DateTime(2026, 8, 8)), true);
        expect(
          output.getCalendarPhase(DateTime(2026, 8, 8), history: history),
          CycleCalendarPhase.menstrual,
        );

        // 9 & 10 August are central predicted bleeding middle days
        expect(pred.isBleedingDay(DateTime(2026, 8, 9)), true);
        expect(pred.isBleedingDay(DateTime(2026, 8, 10)), true);
        expect(
          output.getCalendarPhase(DateTime(2026, 8, 9), history: history),
          CycleCalendarPhase.menstrual,
        );
        expect(
          output.getCalendarPhase(DateTime(2026, 8, 10), history: history),
          CycleCalendarPhase.menstrual,
        );

        // 11 August is central predicted bleeding end
        expect(pred.isBleedingDay(DateTime(2026, 8, 11)), true);
        expect(
          output.getCalendarPhase(DateTime(2026, 8, 11), history: history),
          CycleCalendarPhase.menstrual,
        );

        // 12 August is NOT a predicted bleeding day
        expect(pred.isBleedingDay(DateTime(2026, 8, 12)), false);

        // 12-15 August should be Follicular phase
        expect(
          output.getCalendarPhase(DateTime(2026, 8, 14), history: history),
          CycleCalendarPhase.follicular,
        );

        // 21 August should be Estimated Ovulation
        expect(
          output.getCalendarPhase(DateTime(2026, 8, 21), history: history),
          CycleCalendarPhase.estimatedOvulation,
        );

        // 18 August should be Fertile Window
        expect(
          output.getCalendarPhase(DateTime(2026, 8, 18), history: history),
          CycleCalendarPhase.fertileWindow,
        );

        // 27 August should be Luteal phase
        expect(
          output.getCalendarPhase(DateTime(2026, 8, 27), history: history),
          CycleCalendarPhase.luteal,
        );
      },
    );
  });

  group('Requirement 19: Calendar Widget & Visual Tests', () {
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

    testWidgets('Renders CycleWorkspacePage at 320dp width without overflow', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 800));
      addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            notificationSchedulerProvider.overrideWithValue(mockScheduler),
          ],
          child: const MaterialApp(home: CycleWorkspacePage()),
        ),
      );

      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Cycle'), findsOneWidget);
      expect(find.byType(CycleWorkspacePage), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(Duration.zero);
    });

    testWidgets('Renders properly in Dark Theme', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            notificationSchedulerProvider.overrideWithValue(mockScheduler),
          ],
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: const CycleWorkspacePage(),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(CycleWorkspacePage), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(Duration.zero);
    });
  });
}
