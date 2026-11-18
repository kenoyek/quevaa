import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';
import 'package:sqlite3/open.dart';
import 'app/app.dart';
import 'app/bootstrap/app_config.dart';
import 'core/analytics/app_logger.dart';
import 'core/notifications/local_notification_service.dart';
import 'core/notifications/notification_initializer.dart';
import 'core/notifications/notification_routing_provider.dart';

final container = ProviderContainer();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (defaultTargetPlatform == TargetPlatform.android) {
    open.overrideFor(OperatingSystem.android, openCipherOnAndroid);
  }
  AppConfig.initializeFromPlatform();
  var appMounted = false;
  String? launchPayload;
  void handleTap(String? payload) {
    if (!appMounted) {
      launchPayload = payload ?? launchPayload;
      return;
    }
    container
        .read(notificationRoutingProvider.notifier)
        .handleNotificationTap(payload);
  }

  try {
    await QuevaaNotificationInitializer.initialize(
      onTap: (response) => handleTap(response.payload),
    );
    final response = await QuevaaLocalNotificationService.instance
        .launchResponse();
    launchPayload ??= response?.payload;
  } catch (error, stack) {
    AppLogger.error('Notification initialization failed', error, stack);
  }

  runApp(
    UncontrolledProviderScope(container: container, child: const QuevaaApp()),
  );
  WidgetsBinding.instance.addPostFrameCallback((_) {
    appMounted = true;
    if (launchPayload != null) handleTap(launchPayload);
  });
}
