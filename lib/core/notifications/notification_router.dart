import 'package:go_router/go_router.dart';

import '../analytics/app_logger.dart';
import '../security/app_lock_service.dart';
import 'notification_payload.dart';

class QuevaaNotificationRouter {
  QuevaaNotificationRouter({required this.appLockService});

  final AppLockService appLockService;
  String? _queuedRoute;

  String? get queuedRoute => _queuedRoute;

  void handlePayload(String? payload, GoRouter router) {
    final parsed = QuevaaNotificationPayload.tryParse(payload);
    final route = parsed?.route ?? '/';
    if (appLockService.isLocked) {
      _queuedRoute = route;
      AppLogger.info('Notification route queued behind app lock');
      return;
    }
    router.go(route);
  }

  void flushQueuedRoute(GoRouter router) {
    final route = _queuedRoute;
    if (route == null || appLockService.isLocked) return;
    _queuedRoute = null;
    router.go(route);
  }
}
