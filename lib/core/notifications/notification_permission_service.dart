import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'notification_system_settings.dart';

enum QuevaaNotificationPermissionStatus { unknown, granted, denied }

class QuevaaNotificationPermissionService {
  QuevaaNotificationPermissionService(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  Future<bool> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }

    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      return await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }

    final macos = _plugin
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >();
    if (macos != null) {
      return await macos.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }

    return true;
  }

  Future<QuevaaNotificationPermissionStatus> status() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      final systemEnabled =
          await QuevaaNotificationSystemSettings.areNotificationsEnabled();
      final pluginEnabled = await android.areNotificationsEnabled();

      if (systemEnabled == false || pluginEnabled == false) {
        return QuevaaNotificationPermissionStatus.denied;
      }
      if (systemEnabled == true || pluginEnabled == true) {
        return QuevaaNotificationPermissionStatus.granted;
      }
      return QuevaaNotificationPermissionStatus.unknown;
    }

    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      final permissions = await ios.checkPermissions();
      return permissions?.isEnabled == true
          ? QuevaaNotificationPermissionStatus.granted
          : QuevaaNotificationPermissionStatus.denied;
    }

    return QuevaaNotificationPermissionStatus.unknown;
  }
}
