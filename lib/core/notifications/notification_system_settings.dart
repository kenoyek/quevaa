import 'dart:io';

import 'package:flutter/services.dart';

class QuevaaNotificationSystemSettings {
  QuevaaNotificationSystemSettings._();

  static const MethodChannel _channel = MethodChannel(
    'com.quevaa.quevaa/notification_settings',
  );

  static Future<bool?> areNotificationsEnabled() async {
    if (!Platform.isAndroid) return null;
    try {
      return await _channel.invokeMethod<bool>('areNotificationsEnabled');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  static Future<bool> openNotificationSettings() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('openNotificationSettings') ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
