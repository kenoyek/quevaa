import 'dart:convert';

import '../../features/notifications/domain/enums/notification_type.dart';
import 'notification_constants.dart';
import 'notification_destination_resolver.dart';

class QuevaaNotificationPayload {
  final int version;
  final int? notificationId;
  final QuevaaNotificationType type;
  final String route;
  final String? entityId;

  const QuevaaNotificationPayload({
    required this.version,
    this.notificationId,
    required this.type,
    required this.route,
    this.entityId,
  });

  factory QuevaaNotificationPayload.forSchedule({
    int? notificationId,
    required QuevaaNotificationType type,
    required String route,
    String? entityId,
  }) {
    return QuevaaNotificationPayload(
      version: QuevaaNotificationConstants.payloadVersion,
      notificationId: notificationId,
      type: type,
      route: NotificationDestinationResolver.resolve(type: type, route: route),
      entityId: entityId,
    );
  }

  String encode() {
    return jsonEncode({
      'version': version,
      'notificationId': notificationId,
      'type': type.name,
      'route': route,
      'entityId': entityId,
    });
  }

  static QuevaaNotificationPayload? tryParse(String? payload) {
    if (payload == null || payload.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) return null;
      if (decoded['version'] != QuevaaNotificationConstants.payloadVersion) {
        return null;
      }
      final route = decoded['route'];
      final typeName = decoded['type'];
      if (typeName is! String) return null;
      QuevaaNotificationType? type;
      for (final candidate in QuevaaNotificationType.values) {
        if (candidate.name == typeName) {
          type = candidate;
          break;
        }
      }
      if (type == null) return null;
      if (route is! String) return null;
      final resolvedRoute = NotificationDestinationResolver.resolve(
        type: type,
        route: route,
      );
      if (resolvedRoute == NotificationDestinationResolver.fallbackRoute &&
          route != NotificationDestinationResolver.fallbackRoute) {
        return null;
      }
      final entityId = decoded['entityId'];
      final notificationId = decoded['notificationId'];
      return QuevaaNotificationPayload(
        version: decoded['version'] as int,
        notificationId: notificationId is int ? notificationId : null,
        type: type,
        route: resolvedRoute,
        entityId: entityId is String ? entityId : null,
      );
    } catch (_) {
      return null;
    }
  }
}
