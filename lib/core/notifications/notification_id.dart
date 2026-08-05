import '../../features/notifications/domain/enums/notification_type.dart';

class QuevaaNotificationId {
  const QuevaaNotificationId._();

  static int generate({
    required QuevaaNotificationType type,
    required String entityId,
    required DateTime occurrence,
  }) {
    final occurrenceKey =
        '${occurrence.year.toString().padLeft(4, '0')}'
        '${occurrence.month.toString().padLeft(2, '0')}'
        '${occurrence.day.toString().padLeft(2, '0')}'
        '${occurrence.hour.toString().padLeft(2, '0')}'
        '${occurrence.minute.toString().padLeft(2, '0')}';
    final input = '${type.name}|$entityId|$occurrenceKey';
    return _fnv1a31(input);
  }

  static int _fnv1a31(String input) {
    const int fnvPrime = 16777619;
    var hash = 2166136261;
    for (final codeUnit in input.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * fnvPrime) & 0x7fffffff;
    }
    return hash == 0 ? 1 : hash;
  }
}
