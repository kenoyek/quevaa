import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quevaa/features/productivity/presentation/pages/plan_workspace_page.dart';
import 'package:quevaa/features/wellness/presentation/pages/wellness_workspace_page.dart';
import 'package:quevaa/app/theme/quevaa_layout.dart';
import 'package:quevaa/core/database/app_database.dart';
import 'package:quevaa/core/providers/database_provider.dart';
import 'package:quevaa/features/notifications/application/notification_preferences_provider.dart';
import 'package:quevaa/features/notifications/domain/services/notification_scheduler.dart';
import 'package:quevaa/features/notifications/domain/services/smart_notification_engine.dart';
import 'package:drift/native.dart';
import 'package:mocktail/mocktail.dart';

class MockNotificationScheduler extends Mock implements NotificationScheduler {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(NotificationReconciliationReason.manualRefresh);
    registerFallbackValue(const NotificationSourceSnapshot());
  });

  Widget wrapWithProvider(Widget child, {Size size = const Size(360, 800), AppDatabase? db, NotificationScheduler? scheduler}) {
    return ProviderScope(
      overrides: [
        if (db != null) appDatabaseProvider.overrideWithValue(db),
        if (scheduler != null) notificationSchedulerProvider.overrideWithValue(scheduler),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: size),
          child: child,
        ),
      ),
    );
  }

  group('Responsive UI Tests', () {
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

    testWidgets('PlanWorkspacePage should render without overflow at 320dp', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 800));
      await tester.pumpWidget(wrapWithProvider(const PlanWorkspacePage(), size: const Size(320, 800), db: db, scheduler: mockScheduler));
      await tester.pumpAndSettle();

      expect(find.byType(PlanWorkspacePage), findsOneWidget);
      expect(find.byType(QuevaaSectionTabs), findsOneWidget);
      
      final dynamic exception = tester.takeException();
      expect(exception, isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(Duration.zero);
    });

    testWidgets('WellnessWorkspacePage should render without overflow at 320dp', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 800));
      await tester.pumpWidget(wrapWithProvider(const WellnessWorkspacePage(), size: const Size(320, 800), db: db, scheduler: mockScheduler));
      await tester.pumpAndSettle();

      expect(find.byType(WellnessWorkspacePage), findsOneWidget);
      expect(find.byType(QuevaaSectionTabs), findsOneWidget);
      
      final dynamic exception = tester.takeException();
      expect(exception, isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(Duration.zero);
    });

    testWidgets('QuevaaSectionTabs should handle long labels and be scrollable', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 800));
      await tester.pumpWidget(wrapWithProvider(
        const Scaffold(
          body: QuevaaSectionTabs(
            segments: [
              (value: '1', label: 'Very Long Label One', icon: Icons.star),
              (value: '2', label: 'Very Long Label Two', icon: Icons.star),
              (value: '3', label: 'Very Long Label Three', icon: Icons.star),
              (value: '4', label: 'Very Long Label Four', icon: Icons.star),
              (value: '5', label: 'Very Long Label Five', icon: Icons.star),
            ],
            selected: '1',
            onSelectionChanged: _dummyOnChanged,
          ),
        ),
        size: const Size(320, 800),
        db: db,
        scheduler: mockScheduler,
      ));

      expect(find.text('Very Long Label One'), findsOneWidget);
      expect(find.text('Very Long Label Five'), findsOneWidget); 
      
      await tester.drag(find.byType(SingleChildScrollView), const Offset(-500, 0));
      await tester.pump();
      
      final dynamic exception = tester.takeException();
      expect(exception, isNull);
    });

    group('Specific UI Elements', () {
      testWidgets('QuevaaSectionTabs selected state color check', (tester) async {
        await tester.pumpWidget(wrapWithProvider(
          const Scaffold(
            body: QuevaaSectionTabs(
              segments: [
                (value: 'Today', label: 'Today', icon: Icons.today),
                (value: 'Focus', label: 'Focus', icon: Icons.timer),
              ],
              selected: 'Today',
              onSelectionChanged: _dummyOnChanged,
            ),
          ),
          db: db,
          scheduler: mockScheduler,
        ));
        
        final chip = tester.widget<ChoiceChip>(find.byType(ChoiceChip).first);
        expect(chip.selected, isTrue);
      });
    });
  });
}

void _dummyOnChanged(String value) {}
