import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';
import 'app/router/app_router.dart';
import 'core/notifications/notification_initializer.dart';
import 'core/notifications/notification_payload.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await QuevaaNotificationInitializer.initialize(
    onTap: (response) {
      final payload = QuevaaNotificationPayload.tryParse(response.payload);
      appRouter.go(payload?.route ?? '/');
    },
  );
  runApp(const ProviderScope(child: QuevaaApp()));
}
