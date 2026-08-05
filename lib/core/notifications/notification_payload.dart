import 'dart:convert';

import '../../features/notifications/domain/enums/notification_type.dart';
import 'notification_constants.dart';

class QuevaaNotificationPayload {
  final int version;
  final QuevaaNotificationType type;
  final String route;
  final String? entityId;

  const QuevaaNotificationPayload({
    required this.version,
    required this.type,
    required this.route,
    this.entityId,
  });

  factory QuevaaNotificationPayload.forSchedule({
    required QuevaaNotificationType type,
    required String route,
    String? entityId,
  }) {
    return QuevaaNotificationPayload(
      version: QuevaaNotificationConstants.payloadVersion,
      type: type,
      route: route,
      entityId: entityId,
    );
  }

  String encode() {
    return jsonEncode({
      'version': version,
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
      if (route is! String || !_allowedRoutes.contains(route)) return null;
      if (typeName is! String) return null;
      QuevaaNotificationType? type;
      for (final candidate in QuevaaNotificationType.values) {
        if (candidate.name == typeName) {
          type = candidate;
          break;
        }
      }
      if (type == null) return null;
      final entityId = decoded['entityId'];
      return QuevaaNotificationPayload(
        version: decoded['version'] as int,
        type: type,
        route: route,
        entityId: entityId is String ? entityId : null,
      );
    } catch (_) {
      return null;
    }
  }

  static const Set<String> _allowedRoutes = {
    '/',
    '/cycle',
    '/plan',
    '/wellness',
    '/me',
    '/conception/log',
    '/notifications/settings',
  };
}
