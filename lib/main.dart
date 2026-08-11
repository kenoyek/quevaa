import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';
import 'package:sqlite3/open.dart';
import 'app/app.dart';
import 'app/bootstrap/app_config.dart';
import 'core/notifications/notification_initializer.dart';
import 'core/notifications/notification_routing_provider.dart';

final container = ProviderContainer();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (defaultTargetPlatform == TargetPlatform.android) {
    open.overrideFor(OperatingSystem.android, openCipherOnAndroid);
  }
  AppConfig.initializeFromPlatform();
  await QuevaaNotificationInitializer.initialize(
    onTap: (response) {
      container
          .read(notificationRoutingProvider.notifier)
          .handleNotificationTap(response.payload);
    },
  );
  runApp(
    UncontrolledProviderScope(container: container, child: const QuevaaApp()),
  );
}
