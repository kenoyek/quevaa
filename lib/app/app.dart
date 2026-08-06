import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';
import 'theme/quevaa_theme_mode.dart';
import 'startup/app_startup_provider.dart';
import '../core/notifications/notification_routing_provider.dart';
import '../core/security/widgets/app_lock_wrapper.dart';

class QuevaaApp extends ConsumerWidget {
  const QuevaaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
    ref.watch(appStartupProvider);

    // Listen for notification taps
    ref.listen(notificationRoutingProvider, (previous, next) {
      if (next != null) {
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
