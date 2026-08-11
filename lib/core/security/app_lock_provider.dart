import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import '../analytics/app_logger.dart';
import '../database/app_database.dart';
import '../providers/database_provider.dart';
import '../providers/user_profile_provider.dart';

final appLockProvider = StateNotifierProvider<AppLockNotifier, bool>((ref) {
  return AppLockNotifier(ref);
});

class AppLockNotifier extends StateNotifier<bool> with WidgetsBindingObserver {
  final Ref ref;
  final LocalAuthentication _localAuth = LocalAuthentication();
  DateTime? _pausedAt;
  int _inactivityThresholdSeconds = 120;

  AppLockNotifier(this.ref) : super(false) {
    WidgetsBinding.instance.addObserver(this);
    _initLockState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void updateLockTimeout(int seconds) {
    _inactivityThresholdSeconds = seconds;
  }

  void _initLockState() {
    final db = ref.read(appDatabaseProvider);
    (db.select(db.appSettings)..limit(1)).getSingleOrNull().then((settings) {
      if (settings != null) {
        _inactivityThresholdSeconds = settings.autoLockInactivitySeconds;
      }
    });

    final current = ref.read(userProfileProvider).valueOrNull;
    if (current?.isBiometricEnabled ?? false) {
      state = true;
    }

    ref.listen<AsyncValue<UserProfile?>>(userProfileProvider, (previous, next) {
      final prevEnabled = previous?.valueOrNull?.isBiometricEnabled ?? false;
      final nextEnabled = next.valueOrNull?.isBiometricEnabled ?? false;

      if (nextEnabled && (!prevEnabled || previous?.valueOrNull == null)) {
        state = true;
      } else if (prevEnabled && !nextEnabled) {
        state = false;
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final profile = ref.read(userProfileProvider).valueOrNull;
    if (!(profile?.isBiometricEnabled ?? false)) return;

    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      if (_pausedAt != null) {
        final elapsed = DateTime.now().difference(_pausedAt!).inSeconds;
        if (elapsed >= _inactivityThresholdSeconds) {
          this.state = true;
          AppLogger.info('App locked due to inactivity ($elapsed seconds)');
        }
      }
      _pausedAt = null;
    }
  }

  Future<bool> unlock() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      if (!canCheck && !isSupported) {
        AppLogger.info(
          'Device does not support local authentication; unlocking',
        );
        state = false;
        return true;
      }

      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Unlock Quevaa to protect your health privacy',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
          useErrorDialogs: true,
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
