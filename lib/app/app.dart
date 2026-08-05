import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';
import 'theme/quevaa_theme_mode.dart';

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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay,
      child: MaterialApp.router(
        title: 'Quevaa',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme(),
        darkTheme: AppTheme.darkTheme(),
        themeMode: selectedMode.materialMode,
        routerConfig: appRouter,
      ),
    );
  }
}
