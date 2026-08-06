import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';
import 'core/notifications/notification_initializer.dart';
import 'core/notifications/notification_routing_provider.dart';

final container = ProviderContainer();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await QuevaaNotificationInitializer.initialize(
    onTap: (response) {
      container
          .read(notificationRoutingProvider.notifier)
          .handleNotificationTap(response.payload);
    },
  );
  runApp(UncontrolledProviderScope(container: container, child: const QuevaaApp()));
}
