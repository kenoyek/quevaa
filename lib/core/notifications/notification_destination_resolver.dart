import '../../features/notifications/domain/enums/notification_type.dart';

class NotificationDestinationResolver {
  const NotificationDestinationResolver._();

  static const fallbackRoute = '/';

  static const Set<String> allowedRoutes = {
    '/',
    '/cycle',
    '/plan',
    '/wellness',
    '/wellness?section=Meals',
    '/me',
    '/conception/log',
    '/notifications',
    '/notifications/settings',
  };

  static String resolve({QuevaaNotificationType? type, String? route}) {
    final candidate = route?.trim();
    if (candidate != null && allowedRoutes.contains(candidate)) {
      return candidate;
    }
    final typeRoute = type?.defaultRoute;
    if (typeRoute != null && allowedRoutes.contains(typeRoute)) {
      return typeRoute;
    }
    return fallbackRoute;
  }
}
