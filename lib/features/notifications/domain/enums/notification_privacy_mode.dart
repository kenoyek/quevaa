enum QuevaaNotificationPrivacyMode { explicit, discreet, hidden }

extension QuevaaNotificationPrivacyModeLabel on QuevaaNotificationPrivacyMode {
  String get label {
    switch (this) {
      case QuevaaNotificationPrivacyMode.explicit:
        return 'Explicit';
      case QuevaaNotificationPrivacyMode.discreet:
        return 'Discreet';
      case QuevaaNotificationPrivacyMode.hidden:
        return 'Hidden';
    }
  }
}
