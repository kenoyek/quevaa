import '../enums/notification_priority.dart';
import '../enums/notification_privacy_mode.dart';

class AppNotification {
  final int id;
  final String category;
  final String title;
  final String explicitBody;
  final String discreetBody;
  final DateTime createdAt;
  final DateTime scheduledFor;
  final DateTime? deliveredAt;
  final DateTime? readAt;
  final String deepLink;
  final String? payload;
  final QuevaaNotificationPriority priority;

  const AppNotification({
    required this.id,
    required this.category,
    required this.title,
    required this.explicitBody,
    required this.discreetBody,
    required this.createdAt,
    required this.scheduledFor,
    required this.deliveredAt,
    required this.readAt,
    required this.deepLink,
    required this.payload,
    required this.priority,
  });

  bool get isRead => readAt != null;
  bool get isUnread => !isRead;

  String bodyFor(QuevaaNotificationPrivacyMode mode) {
    switch (mode) {
      case QuevaaNotificationPrivacyMode.explicit:
        return explicitBody;
      case QuevaaNotificationPrivacyMode.discreet:
      case QuevaaNotificationPrivacyMode.hidden:
        return discreetBody;
    }
  }
}
