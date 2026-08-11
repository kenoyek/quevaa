import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quevaa/core/notifications/notification_permission_service.dart';
import 'package:quevaa/features/notifications/application/notification_preferences_provider.dart';
import 'package:quevaa/features/notifications/application/notification_snapshot_provider.dart';
import 'package:quevaa/features/notifications/application/pending_notifications_provider.dart';
import 'package:quevaa/features/notifications/domain/entities/notification_preferences.dart';
import 'package:quevaa/features/notifications/domain/enums/notification_privacy_mode.dart';
import 'package:quevaa/features/notifications/domain/repositories/notification_repository.dart';
import 'package:quevaa/features/notifications/domain/services/notification_scheduler.dart';
import 'package:quevaa/features/notifications/domain/services/smart_notification_engine.dart';
import 'package:quevaa/features/notifications/presentation/notification_settings_page.dart';
import 'package:quevaa/features/notifications/presentation/widgets/quiet_hours_selector.dart';

class MockNotificationRepository extends Mock
    implements NotificationRepository {}

class MockNotificationScheduler extends Mock implements NotificationScheduler {}

void main() {
  setUpAll(() {
    registerFallbackValue(QuevaaNotificationPreferences.defaults());
    registerFallbackValue(NotificationReconciliationReason.preferencesChanged);
    registerFallbackValue(
      const NotificationSourceSnapshot(
        estimatedPhase: 'Follicular',
        mealSuggestion: 'Rice and Beans',
        workoutSuggestion: 'Walk',
      ),
    );
  });

  testWidgets(
    'Detailed and Discreet preview updates immediately while saves are queued',
    (tester) async {
      final repository = MockNotificationRepository();
      final scheduler = MockNotificationScheduler();
      final completers = [Completer<void>(), Completer<void>()];
      var saveCount = 0;
      when(() => repository.savePreferences(any())).thenAnswer((_) {
        return completers[saveCount++].future;
      });
      when(
        () => scheduler.reconcileNotifications(
          any(),
          snapshot: any(named: 'snapshot'),
        ),
      ).thenAnswer(
        (_) async => const NotificationReconciliationResult(
          reason: NotificationReconciliationReason.preferencesChanged,
          desiredCount: 0,
          scheduledCount: 0,
          cancelledCount: 0,
          unchangedCount: 0,
          permissionGranted: true,
          timezone: 'UTC',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationPreferencesProvider.overrideWith(
              (_) async => QuevaaNotificationPreferences.defaults().copyWith(
                enabled: true,
                privacyMode: QuevaaNotificationPrivacyMode.discreet,
              ),
            ),
            notificationPermissionStatusProvider.overrideWith(
              (_) async => QuevaaNotificationPermissionStatus.granted,
            ),
            pendingNotificationsProvider.overrideWith((_) async => const []),
            notificationRepositoryProvider.overrideWithValue(repository),
            notificationSchedulerProvider.overrideWithValue(scheduler),
            notificationSourceSnapshotProvider.overrideWithValue(
              const NotificationSourceSnapshot(
                estimatedPhase: 'Follicular',
                mealSuggestion: 'Rice and Beans',
                workoutSuggestion: 'Walk',
              ),
            ),
          ],
          child: const MaterialApp(home: NotificationSettingsPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('You have a Quevaa update.'), findsOneWidget);

      await tester.tap(find.text('Detailed'));
      await tester.pump();

      expect(find.text('Your period may start tomorrow.'), findsOneWidget);
      expect(saveCount, 1);

      await tester.tap(find.text('Discreet'));
      await tester.pump();

      expect(find.text('You have a Quevaa update.'), findsOneWidget);
      expect(saveCount, 1);

      completers.first.complete();
      await tester.pump();
      await tester.pump();
      expect(saveCount, 2);
      completers.last.complete();
      await tester.pumpAndSettle();
    },
  );

  testWidgets('quiet-hour sliders preview immediately and commit on release', (
    tester,
  ) async {
    var start = 21 * 60;
    var end = 8 * 60;
    int? previewStart;
    int? committedStart;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return QuietHoursSelector(
                startMinutes: start,
                endMinutes: end,
                onStartChanged: (value) {
                  previewStart = value;
                  setState(() => start = value);
                },
                onStartChangeEnd: (value) => committedStart = value,
                onEndChanged: (value) => setState(() => end = value),
                onEndChangeEnd: (_) {},
              );
            },
          ),
        ),
      ),
    );

    var startSlider = tester.widget<Slider>(find.byType(Slider).first);
    startSlider.onChanged!(22 * 60);
    await tester.pump();

    expect(previewStart, 22 * 60);
    expect(committedStart, isNull);

    startSlider = tester.widget<Slider>(find.byType(Slider).first);
    startSlider.onChangeEnd!(22 * 60);

    expect(committedStart, 22 * 60);
  });
}
