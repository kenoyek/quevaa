enum QuevaaNotificationType {
  periodExpected,
  periodToday,
  periodLateCheckIn,
  dailyCycleCheckIn,
  fertileWindowApproaching,
  highFertilityCheckIn,
  ovulationTest,
  basalBodyTemperature,
  pregnancyTest,
  prenatalSupplement,
  medication,
  hydration,
  breakfast,
  lunch,
  dinner,
  workout,
  taskDue,
  taskStarting,
  focusSession,
  routine,
  journalPrompt,
  eveningReflection,
  weeklyReview,
}

extension QuevaaNotificationTypeRoute on QuevaaNotificationType {
  String get defaultRoute {
    switch (this) {
      case QuevaaNotificationType.periodExpected:
      case QuevaaNotificationType.periodToday:
      case QuevaaNotificationType.periodLateCheckIn:
      case QuevaaNotificationType.dailyCycleCheckIn:
        return '/cycle';
      case QuevaaNotificationType.fertileWindowApproaching:
      case QuevaaNotificationType.highFertilityCheckIn:
      case QuevaaNotificationType.ovulationTest:
      case QuevaaNotificationType.basalBodyTemperature:
      case QuevaaNotificationType.pregnancyTest:
      case QuevaaNotificationType.prenatalSupplement:
        return '/conception/log';
      case QuevaaNotificationType.medication:
      case QuevaaNotificationType.hydration:
      case QuevaaNotificationType.breakfast:
      case QuevaaNotificationType.lunch:
      case QuevaaNotificationType.dinner:
      case QuevaaNotificationType.workout:
        return '/wellness';
      case QuevaaNotificationType.taskDue:
      case QuevaaNotificationType.taskStarting:
      case QuevaaNotificationType.focusSession:
      case QuevaaNotificationType.routine:
      case QuevaaNotificationType.weeklyReview:
        return '/plan';
      case QuevaaNotificationType.journalPrompt:
      case QuevaaNotificationType.eveningReflection:
        return '/me';
    }
  }

  String get categoryKey {
    switch (this) {
      case QuevaaNotificationType.periodExpected:
      case QuevaaNotificationType.periodToday:
      case QuevaaNotificationType.periodLateCheckIn:
      case QuevaaNotificationType.dailyCycleCheckIn:
        return 'cycle';
      case QuevaaNotificationType.fertileWindowApproaching:
      case QuevaaNotificationType.highFertilityCheckIn:
      case QuevaaNotificationType.ovulationTest:
      case QuevaaNotificationType.basalBodyTemperature:
      case QuevaaNotificationType.pregnancyTest:
      case QuevaaNotificationType.prenatalSupplement:
        return 'conception';
      case QuevaaNotificationType.medication:
        return 'medication';
      case QuevaaNotificationType.taskDue:
      case QuevaaNotificationType.taskStarting:
      case QuevaaNotificationType.focusSession:
      case QuevaaNotificationType.routine:
        return 'tasks';
      case QuevaaNotificationType.breakfast:
      case QuevaaNotificationType.lunch:
      case QuevaaNotificationType.dinner:
        return 'meals';
      case QuevaaNotificationType.hydration:
        return 'hydration';
      case QuevaaNotificationType.workout:
        return 'workouts';
      case QuevaaNotificationType.journalPrompt:
      case QuevaaNotificationType.eveningReflection:
        return 'journal';
      case QuevaaNotificationType.weeklyReview:
        return 'weeklyReview';
    }
  }
}
