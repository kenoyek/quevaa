import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';
import 'theme/quevaa_theme_mode.dart';
import 'startup/app_startup_provider.dart';
import '../core/analytics/app_logger.dart';
import '../core/notifications/notification_routing_provider.dart';
import '../core/security/widgets/app_lock_wrapper.dart';
import '../features/notifications/application/notification_inbox_provider.dart';
import '../features/notifications/application/notification_preferences_provider.dart';
import '../features/notifications/application/pending_notifications_provider.dart';
import '../features/notifications/domain/services/notification_scheduler.dart';

class QuevaaApp extends ConsumerStatefulWidget {
  const QuevaaApp({super.key});

  @override
  ConsumerState<QuevaaApp> createState() => _QuevaaAppState();
}

class _QuevaaAppState extends ConsumerState<QuevaaApp> {
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(onResume: _refreshReminders);
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  Future<void> _refreshReminders() async {
    ref.invalidate(notificationPermissionStatusProvider);
    try {
      final refresh = appStartupProvider(
        NotificationReconciliationReason.appResumed,
      );
      ref.invalidate(refresh);
      await ref.read(refresh.future);
    } catch (error, stack) {
      AppLogger.error('Refreshing reminders failed', error, stack);
    } finally {
      if (mounted) {
        ref.invalidate(pendingNotificationsProvider);
        ref.invalidate(notificationInboxProvider);
        ref.invalidate(unreadNotificationCountProvider);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedMode =
        ref.watch(quevaaThemeModeProvider).valueOrNull ??
        QuevaaThemeMode.system;
    final platformBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    final effectiveDark =
        selectedMode == QuevaaThemeMode.dark ||
        (selectedMode == QuevaaThemeMode.system &&
            platformBrightness == Brightness.dark);
    final overlay = effectiveDark
        ? const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
            systemNavigationBarColor: Color(0xFF1C1318),
            systemNavigationBarIconBrightness: Brightness.light,
          )
        : const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
            systemNavigationBarColor: Color(0xFFFAFAF7),
            systemNavigationBarIconBrightness: Brightness.dark,
          );

    final router = ref.watch(routerProvider);
    ref.watch(appStartupProvider(NotificationReconciliationReason.appStarted));

    // Listen for notification taps
    ref.listen(notificationRoutingProvider, (previous, next) {
      if (next != null) {
        final notificationId = next.notificationId;
        if (notificationId != null) {
          unawaited(
            ref
                .read(notificationRepositoryProvider)
                .markInboxEntryRead(notificationId)
                .catchError((Object error, StackTrace stack) {
                  AppLogger.error(
                    'Updating reminder status failed',
                    error,
                    stack,
                  );
                }),
          );
        }
        router.go(next.route);
        ref.read(notificationRoutingProvider.notifier).consume();
      }
    });

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay,
      child: MaterialApp.router(
        title: 'Quevaa',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme(),
        darkTheme: AppTheme.darkTheme(),
        themeMode: selectedMode.materialMode,
        routerConfig: router,
        builder: (context, child) => AppLockWrapper(child: child!),
      ),
    );
  }
}
