import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import '../analytics/app_logger.dart';
import '../providers/user_profile_provider.dart';

final appLockProvider = StateNotifierProvider<AppLockNotifier, bool>((ref) {
  return AppLockNotifier(ref);
});

class AppLockNotifier extends StateNotifier<bool> with WidgetsBindingObserver {
  final Ref ref;
  final LocalAuthentication _localAuth = LocalAuthentication();
  DateTime? _pausedAt;
  static const int inactivityThresholdSeconds = 120;

  AppLockNotifier(this.ref) : super(false) {
    WidgetsBinding.instance.addObserver(this);
    // Initial lock if enabled
    _checkInitialLock();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _checkInitialLock() {
    final profile = ref.read(userProfileProvider).valueOrNull;
    if (profile?.isBiometricEnabled ?? false) {
      state = true;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    final profile = ref.read(userProfileProvider).valueOrNull;
    if (!(profile?.isBiometricEnabled ?? false)) return;

    if (lifecycleState == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
    } else if (lifecycleState == AppLifecycleState.resumed) {
      if (_pausedAt != null) {
        final elapsed = DateTime.now().difference(_pausedAt!).inSeconds;
        if (elapsed >= inactivityThresholdSeconds) {
          state = true;
          AppLogger.info('App locked due to inactivity ($elapsed seconds)');
        }
      }
      _pausedAt = null;
    }
  }

  Future<bool> unlock() async {
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Unlock Quevaa to protect your health privacy',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );

      if (authenticated) {
        state = false;
        AppLogger.info('App unlocked via biometrics');
      }
      return authenticated;
    } catch (e, stack) {
      AppLogger.error('Unlock authentication error', e, stack);
      return false;
    }
  }

  void lock() {
    state = true;
  }
}
