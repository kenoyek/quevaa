import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quevaa/core/database/app_database.dart';
import 'package:quevaa/core/models/prediction_confidence.dart';
import 'package:quevaa/core/providers/database_provider.dart';
import 'package:quevaa/features/cycle/application/cycle_workspace_provider.dart';
import 'package:quevaa/features/productivity/application/plan_workspace_provider.dart';
import 'package:quevaa/features/wellness/application/wellness_workspace_provider.dart';
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
  late ProviderContainer container;
  late MockNotificationScheduler mockScheduler;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    mockScheduler = MockNotificationScheduler();

    // Stub the reconcileNotifications call
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

    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        notificationSchedulerProvider.overrideWithValue(mockScheduler),
        localTodayProvider.overrideWithValue(DateTime(2026, 8, 5)),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test(
    'Cycle workspace persists daily logs, symptoms, and period boundaries',
    () async {
      final controller = container.read(
        cycleWorkspaceControllerProvider.notifier,
      );
      final date = DateTime(2026, 8, 5);

      await controller.saveDailyLog(
        date: date,
        flow: 'Medium',
        pain: 3,
        mood: 'Calm',
        energy: 2,
        stress: 4,
        sleepQuality: 3,
        water: 6,
        symptoms: ['Cramps', 'Fatigue'],
        notes: 'Needed a lighter pace.',
      );
      await controller.startPeriod(date);
      await controller.endLatestPeriod(date.add(const Duration(days: 4)));

      final logs = await db.select(db.dailyLogs).get();
      final symptoms = await db.select(db.symptomEntries).get();
      final periods = await db.select(db.cyclePeriods).get();

      expect(logs.single.flow, 'Medium');
      expect(logs.single.energyLevel, 2);
      expect(
        symptoms.map((entry) => entry.symptomCategory),
        containsAll(['Cramps', 'Fatigue']),
      );
      expect(periods.single.startDate, DateTime(2026, 8, 5));
      expect(periods.single.endDate, DateTime(2026, 8, 9));
      expect(periods.single.isOngoing, isFalse);

      container.invalidate(periodHistoryProvider);
      await container.read(periodHistoryProvider.future);
      final snapshot = container.read(currentCycleSnapshotProvider);
      final output = container.read(currentCycleOutputProvider);
      expect(snapshot.hasEnoughData, isTrue);
      expect(snapshot.confidence.label, isNotNull);
      expect(output.hasEnoughData, isTrue);
    },
  );

  test(
    'Plan workspace persists tasks, completion, routines, and focus sessions',
    () async {
      final controller = container.read(
        planWorkspaceControllerProvider.notifier,
      );

      await controller.saveTask(
        title: 'Prepare launch notes',
        category: 'Work',
        priority: 'High',
        energy: 'Moderate',
        scheduledDate: DateTime(2026, 8, 5),
        estimatedDurationMinutes: 45,
      );
      final task = (await db.select(db.tasks).get()).single;

      await controller.completeTask(task, completed: true);
      await controller.saveRoutine(title: 'Evening reflection');
      final routine = (await db.select(db.routines).get()).single;
      await controller.completeRoutine(routine);
      await controller.saveFocusSession(
        title: task.title,
        durationMinutes: 25,
        taskId: task.id,
      );

      final completedTask = (await db.select(db.tasks).get()).single;
      final completedRoutine = (await db.select(db.routines).get()).single;
      final sessions = await db.select(db.focusSessions).get();

      expect(completedTask.status, 'Completed');
      expect(completedTask.completedAt, isNotNull);
      expect(completedRoutine.streakCount, 1);
      expect(completedRoutine.completionHistoryJson, contains('2026'));
      expect(sessions.single.durationMinutes, 25);
      expect(sessions.single.taskId, task.id);
    },
  );

  test(
    'Wellness workspace persists hydration, pantry, shopping, meals, and workouts',
    () async {
      final controller = container.read(
        wellnessWorkspaceControllerProvider.notifier,
      );
      final recommendation = container.read(wellnessRecommendationProvider);

      await controller.logWater(8);
      await controller.addPantryItem(
        name: 'Ugu',
        quantity: 2,
        unit: 'bunches',
        lowStock: true,
      );
      await controller.planMeal(DateTime(2026, 8, 5), recommendation.meal);
      await controller.markMealPrepared(recommendation.meal);
      await controller.addRecipeToShoppingList(recommendation.meal);
      await controller.completeWorkout(recommendation.workout, exertion: 4);

      final logs = await db.select(db.dailyLogs).get();
      final pantry = await db.select(db.pantryItems).get();
      final mealPlans = await db.select(db.mealPlans).get();
      final mealLogs = await db.select(db.mealLogs).get();
      final shopping = await db.select(db.shoppingItems).get();
      final workouts = await db.select(db.workoutSessions).get();

      expect(logs.single.waterGlasses, 8);
      expect(pantry.single.lowStock, isTrue);
      expect(mealPlans.single.mealType, recommendation.meal.mealType);
      expect(mealLogs.single.mealTitle, recommendation.meal.title);
      expect(shopping, isNotEmpty);
      expect(workouts.single.perceivedExertion, 4);
    },
  );

  test(
    'Wellness workspace persists, updates, and deletes journal entries',
    () async {
      final controller = container.read(
        wellnessWorkspaceControllerProvider.notifier,
      );

      await controller.saveJournalEntry(
        title: 'Morning thought',
        content: 'Felt calm and clear today.',
        mood: 'Calm',
        tags: ['morning', 'mindfulness'],
      );

      final entries = await db.select(db.journalEntries).get();
      expect(entries.length, 1);
      expect(entries.single.title, 'Morning thought');
      expect(entries.single.encryptedContent, 'Felt calm and clear today.');
      expect(entries.single.mood, 'Calm');

      await controller.saveJournalEntry(
        id: entries.single.id,
        title: 'Updated morning thought',
        content: 'Felt calm, clear, and focused today.',
        mood: 'Energized',
      );

      final updated = await db.select(db.journalEntries).get();
      expect(updated.single.title, 'Updated morning thought');
      expect(updated.single.mood, 'Energized');

      await controller.deleteJournalEntry(entries.single.id);
      container.invalidate(journalStreamProvider);
      final activeEntries = await container.read(journalStreamProvider.future);
      expect(activeEntries, isEmpty);
    },
  );
}
