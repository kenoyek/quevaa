enum QuevaaNotificationPriority { low, normal, high, userCreated }

extension QuevaaNotificationPriorityRank on QuevaaNotificationPriority {
  int get rank {
    switch (this) {
      case QuevaaNotificationPriority.userCreated:
        return 0;
      case QuevaaNotificationPriority.high:
        return 1;
      case QuevaaNotificationPriority.normal:
        return 2;
      case QuevaaNotificationPriority.low:
        return 3;
    }
  }
}
