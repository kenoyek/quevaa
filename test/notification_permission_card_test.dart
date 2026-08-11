import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quevaa/features/notifications/presentation/widgets/notification_permission_card.dart';

void main() {
  testWidgets(
    'shows Android settings recovery when notifications are blocked',
    (tester) async {
      var openedSettings = false;
      var retried = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NotificationPermissionCard(
              enabled: false,
              permissionBlocked: true,
              permissionPreviouslyDeclined: false,
              onEnable: () => retried = true,
              onDismiss: () {},
              onOpenSettings: () => openedSettings = true,
            ),
          ),
        ),
      );

      expect(find.text('Stay gently prepared'), findsOneWidget);
      expect(
        find.textContaining('Notifications are currently blocked for Quevaa'),
        findsOneWidget,
      );
      expect(find.text('Open settings'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(find.text('Enable reminders'), findsNothing);
      expect(find.text('Not now'), findsNothing);

      await tester.tap(find.text('Open settings'));
      await tester.pump();
      expect(openedSettings, isTrue);

      await tester.tap(find.text('Try again'));
      await tester.pump();
      expect(retried, isTrue);
    },
  );
}
