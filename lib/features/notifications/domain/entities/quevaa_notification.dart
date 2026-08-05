import 'package:timezone/timezone.dart' as tz;

import '../enums/notification_priority.dart';
import '../enums/notification_type.dart';

class QuevaaNotification {
  final int id;
  final QuevaaNotificationType type;
  final tz.TZDateTime scheduledAt;
  final String title;
  final String body;
  final String privacySafeTitle;
  final String privacySafeBody;
  final String hiddenTitle;
  final String hiddenBody;
  final String route;
  final String? localRecordId;
  final QuevaaNotificationPriority priority;
  final String source;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int scheduleVersion;

  const QuevaaNotification({
    required this.id,
    required this.type,
    required this.scheduledAt,
    required this.title,
    required this.body,
    required this.privacySafeTitle,
    required this.privacySafeBody,
    this.hiddenTitle = 'Quevaa',
    this.hiddenBody = 'Open the app to view your update.',
    required this.route,
    this.localRecordId,
    required this.priority,
    required this.source,
    required this.createdAt,
    required this.updatedAt,
    required this.scheduleVersion,
  });

  String get fingerprint {
    return [
      id,
      type.name,
      scheduledAt.millisecondsSinceEpoch,
      title,
      body,
      privacySafeTitle,
      privacySafeBody,
      route,
      localRecordId ?? '',
      priority.name,
      scheduleVersion,
    ].join('|');
  }
}
