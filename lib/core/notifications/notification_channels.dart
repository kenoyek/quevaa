import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class QuevaaNotificationChannels {
  const QuevaaNotificationChannels._();

  static const cycle = AndroidNotificationChannel(
    'quevaa_cycle',
    'Cycle and Period',
    description: 'Cycle predictions and period check-ins',
    importance: Importance.defaultImportance,
  );

  static const conception = AndroidNotificationChannel(
    'quevaa_conception',
    'Trying to Conceive',
    description: 'Fertility observations and conception reminders',
    importance: Importance.defaultImportance,
  );

  static const medication = AndroidNotificationChannel(
    'quevaa_medication',
    'Supplements and Medication',
    description: 'User-enabled supplement and medication reminders',
    importance: Importance.high,
  );

  static const tasks = AndroidNotificationChannel(
    'quevaa_tasks',
    'Tasks and Routines',
    description: 'Task, routine and focus reminders',
    importance: Importance.defaultImportance,
  );

  static const wellness = AndroidNotificationChannel(
    'quevaa_wellness',
    'Meals, Hydration and Workouts',
    description: 'Wellness suggestions and planned movement reminders',
    importance: Importance.low,
  );

  static const reflection = AndroidNotificationChannel(
    'quevaa_reflection',
    'Journal and Reflection',
    description: 'Gentle journal and reflection reminders',
    importance: Importance.low,
  );

  static const all = [
    cycle,
    conception,
    medication,
    tasks,
    wellness,
    reflection,
  ];
}
