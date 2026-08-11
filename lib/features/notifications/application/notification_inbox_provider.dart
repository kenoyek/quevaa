import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/app_notification.dart';
import 'notification_preferences_provider.dart';

final notificationInboxProvider = StreamProvider<List<AppNotification>>((ref) {
  return ref.watch(notificationRepositoryProvider).watchInbox();
});

final unreadNotificationCountProvider = StreamProvider<int>((ref) {
  return ref.watch(notificationRepositoryProvider).watchUnreadCount();
});

final notificationInboxControllerProvider =
    StateNotifierProvider<NotificationInboxController, AsyncValue<void>>(
      NotificationInboxController.new,
    );

class NotificationInboxController extends StateNotifier<AsyncValue<void>> {
  NotificationInboxController(this.ref) : super(const AsyncValue.data(null));

  final Ref ref;

  Future<void> markRead(int notificationId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() {
      return ref
          .read(notificationRepositoryProvider)
          .markInboxEntryRead(notificationId);
    });
  }

  Future<void> markAllRead() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() {
      return ref.read(notificationRepositoryProvider).markAllInboxRead();
    });
  }
}
