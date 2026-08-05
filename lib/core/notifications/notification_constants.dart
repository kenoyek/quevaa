class QuevaaNotificationConstants {
  const QuevaaNotificationConstants._();

  static const int scheduleVersion = 1;
  static const int payloadVersion = 1;
  static const int maxPendingNotifications = 48;
  static const int rollingHorizonDays = 30;
  static const int defaultDailyCap = 4;
  static const int defaultQuietStartMinutes = 21 * 60;
  static const int defaultQuietEndMinutes = 8 * 60;
  static const String fallbackTimezone = 'UTC';
  static const String debugSource = 'quevaa-local-engine';
}
