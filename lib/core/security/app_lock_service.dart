import 'package:local_auth/local_auth.dart';
import '../analytics/app_logger.dart';

class AppLockService {
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _isLocked = false;
  DateTime? _lastActiveTimestamp;

  bool get isLocked => _isLocked;

  void lockApp() {
    _isLocked = true;
    AppLogger.info('App manually locked');
  }

  void unlockApp() {
    _isLocked = false;
    _lastActiveTimestamp = DateTime.now();
    AppLogger.info('App successfully unlocked');
  }

  /// Check if inactivity exceeds allowed threshold (default 120 seconds).
  bool checkInactivityLock(int allowedInactivitySeconds) {
    if (_lastActiveTimestamp == null) return false;
    final elapsedSeconds = DateTime.now()
        .difference(_lastActiveTimestamp!)
        .inSeconds;
    if (elapsedSeconds >= allowedInactivitySeconds) {
      _isLocked = true;
      AppLogger.info(
        'App locked due to inactivity ($elapsedSeconds seconds elapsed)',
      );
      return true;
    }
    return false;
  }

  void updateActivityTimestamp() {
    _lastActiveTimestamp = DateTime.now();
  }

  /// Re-authenticates user via OS biometrics or device PIN/Passcode before sensitive actions.
  Future<bool> authenticateForSensitiveAction(String reason) async {
    try {
      final isAvailable =
          await _localAuth.canCheckBiometrics ||
          await _localAuth.isDeviceSupported();
      if (!isAvailable) {
        return true; // Fallback if no device lock configured
      }

      final authenticated = await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );

      if (authenticated) {
        updateActivityTimestamp();
      }
      return authenticated;
    } catch (e, stack) {
      AppLogger.error('Biometric authentication error', e, stack);
      return false;
    }
  }
}
