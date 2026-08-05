import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../analytics/app_logger.dart';
import 'notification_constants.dart';

class QuevaaNotificationTimezoneService {
  bool _initialized = false;
  String _lastKnownTimezone = QuevaaNotificationConstants.fallbackTimezone;

  String get lastKnownTimezone => _lastKnownTimezone;
  tz.Location get localLocation => tz.local;

  Future<String> initializeTimezone() async {
    if (!_initialized) {
      tz_data.initializeTimeZones();
      _initialized = true;
    }

    try {
      final currentTimezone = await FlutterTimezone.getLocalTimezone();
      final identifier = currentTimezone.identifier.trim();
      if (identifier.isEmpty) {
        throw ArgumentError('Empty timezone identifier');
      }
      final location = tz.getLocation(identifier);
      tz.setLocalLocation(location);
      _lastKnownTimezone = identifier;
      return identifier;
    } catch (error, stack) {
      AppLogger.error(
        'Timezone detection failed, falling back to UTC',
        error,
        stack,
      );
      final fallback = tz.getLocation(
        QuevaaNotificationConstants.fallbackTimezone,
      );
      tz.setLocalLocation(fallback);
      _lastKnownTimezone = QuevaaNotificationConstants.fallbackTimezone;
      return _lastKnownTimezone;
    }
  }
}

final quevaaNotificationTimezoneService = QuevaaNotificationTimezoneService();
