import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'notification_payload.dart';

final notificationRoutingProvider =
    StateNotifierProvider<NotificationRoutingNotifier, QuevaaNotificationPayload?>(
  (ref) => NotificationRoutingNotifier(),
);

class NotificationRoutingNotifier extends StateNotifier<QuevaaNotificationPayload?> {
  NotificationRoutingNotifier() : super(null);

  void handleNotificationTap(String? payload) {
    final parsed = QuevaaNotificationPayload.tryParse(payload);
    if (parsed != null) {
      state = parsed;
    }
  }

  void consume() {
    state = null;
  }
}
