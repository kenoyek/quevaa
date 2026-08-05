import 'quevaa_notification.dart';

class QuevaaNotificationSchedule {
  final QuevaaNotification notification;
  final String timezoneName;

  const QuevaaNotificationSchedule({
    required this.notification,
    required this.timezoneName,
  });

  int get id => notification.id;
  String get fingerprint => '${notification.fingerprint}|$timezoneName';
}
