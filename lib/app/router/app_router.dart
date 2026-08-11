import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../features/conception/application/conception_controller.dart';
import '../../features/conception/application/conception_settings_provider.dart';
import '../../features/conception/presentation/pages/conception_dashboard_page.dart';
import '../../features/conception/presentation/pages/conception_onboarding_page.dart';
import '../../features/conception/presentation/pages/fertility_log_page.dart';
import '../../features/conception/presentation/pages/pregnancy_transition_page.dart';
import '../../features/cycle/presentation/pages/cycle_workspace_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/insights/presentation/pages/cycle_insights_page.dart';
import '../../features/notifications/presentation/notification_center_page.dart';
import '../../features/notifications/presentation/notification_settings_page.dart';
import '../../features/onboarding/presentation/pages/onboarding_page.dart';
import '../../features/productivity/presentation/pages/plan_workspace_page.dart';
import '../../features/reports/domain/health_report_model.dart';
import '../../features/reports/presentation/pages/health_report_preview_page.dart';
import '../../features/reports/presentation/pages/health_reports_page.dart';
import '../../features/wellness/presentation/pages/wellness_workspace_page.dart';
import '../../core/database/app_database.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/user_profile_provider.dart';
import '../theme/app_colors.dart';
import '../theme/quevaa_theme_mode.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'shell',
);

class RouterRefreshNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterRefreshNotifier(this._ref) {
    _ref.listen<AsyncValue<UserProfile?>>(userProfileProvider, (
      previous,
      next,
    ) {
      notifyListeners();
    });
  }
}

final routerRefreshNotifierProvider = Provider<RouterRefreshNotifier>((ref) {
  return RouterRefreshNotifier(ref);
});

class StartupErrorPage extends ConsumerWidget {
  final Object error;

  const StartupErrorPage({super.key, required this.error});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgWarmDark : AppColors.bgWarmCream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.terracottaPrimary,
                size: 64,
              ),
              const SizedBox(height: 24),
              Text(
                'Quevaa Database Error',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Quevaa encountered an issue opening your local data safely.\nYour data is preserved on your device.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondaryLight,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  error.toString(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    color: AppColors.terracottaDark,
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 36),
              ElevatedButton(
                onPressed: () {
                  ref.invalidate(userProfileProvider);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.terracottaPrimary,
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Retry Loading Quevaa',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = ref.watch(routerRefreshNotifierProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final userProfileState = ref.read(userProfileProvider);

      final isOnboardingRoute =
          state.matchedLocation == '/onboarding' ||
          state.matchedLocation == '/conception/onboarding';
      final isErrorRoute = state.matchedLocation == '/startup-error';

      if (userProfileState.isLoading && !userProfileState.hasValue) {
        return null;
      }

      if (userProfileState.hasError) {
        if (!isErrorRoute) {
          return '/startup-error';
        }
        return null;
      }

      final profile = userProfileState.valueOrNull;

      if (profile == null) {
        if (!isOnboardingRoute) {
          return '/onboarding';
        }
      } else {
        if (state.matchedLocation == '/onboarding' || isErrorRoute) {
          if (profile.primaryGoal == 'Try to conceive') {
            return '/conception/onboarding';
          }
          return '/';
        }
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/startup-error',
        builder: (context, state) {
          final err =
              ref.read(userProfileProvider).error ?? 'Unknown Database Error';
          return StartupErrorPage(error: err);
        },
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingPage(),
      ),
      GoRoute(
        path: '/conception/onboarding',
        builder: (context, state) => const ConceptionOnboardingPage(),
      ),
      GoRoute(
        path: '/conception/log',
        builder: (context, state) => const FertilityLogPage(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationCenterPage(),
      ),
      GoRoute(
        path: '/notifications/settings',
        builder: (context, state) => const NotificationSettingsPage(),
      ),
      GoRoute(
        path: '/insights',
        builder: (context, state) => const CycleInsightsPage(),
      ),
      GoRoute(
        path: '/reports',
        builder: (context, state) => const HealthReportsPage(),
      ),
      GoRoute(
        path: '/reports/preview',
        builder: (context, state) {
          final report = state.extra;
          if (report is GeneratedHealthReport) {
            return HealthReportPreviewPage(report: report);
          }
          return const HealthReportsPage();
        },
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) {
          return MainNavigationShell(child: child);
        },
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const _ModeAwareHomePage(),
          ),
          GoRoute(
            path: '/cycle',
            builder: (context, state) => const _ModeAwareCyclePage(),
          ),
          GoRoute(
            path: '/plan',
            builder: (context, state) => const _ModeAwarePlanPage(),
          ),
          GoRoute(
            path: '/wellness',
            builder: (context, state) => _ModeAwareWellnessPage(
              initialSection: state.uri.queryParameters['section'],
            ),
          ),
          GoRoute(
            path: '/me',
            builder: (context, state) => const _ModeAwareMePage(),
          ),
          GoRoute(
            path: '/classic',
            builder: (context, state) => const DashboardPage(),
          ),
        ],
      ),
    ],
  );
});

class _ModeAwareHomePage extends ConsumerWidget {
  const _ModeAwareHomePage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conceptionModeActive = ref.watch(conceptionModeActiveProvider);
    return conceptionModeActive
        ? const ConceptionDashboardPage()
        : const DashboardPage();
  }
}

class _ModeAwareCyclePage extends ConsumerWidget {
  const _ModeAwareCyclePage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conceptionModeActive = ref.watch(conceptionModeActiveProvider);
    return conceptionModeActive
        ? const CycleWorkspacePage()
        : const CycleWorkspacePage();
  }
}

class _ModeAwarePlanPage extends ConsumerWidget {
  const _ModeAwarePlanPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conceptionModeActive = ref.watch(conceptionModeActiveProvider);
    return conceptionModeActive
        ? const PlanWorkspacePage()
        : const PlanWorkspacePage();
  }
}

class _ModeAwareWellnessPage extends ConsumerWidget {
  final String? initialSection;

  const _ModeAwareWellnessPage({this.initialSection});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conceptionModeActive = ref.watch(conceptionModeActiveProvider);
    return conceptionModeActive
        ? WellnessWorkspacePage(initialSection: initialSection)
        : WellnessWorkspacePage(initialSection: initialSection);
  }
}

class _ModeAwareMePage extends ConsumerWidget {
  const _ModeAwareMePage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conceptionModeActive = ref.watch(conceptionModeActiveProvider);
    return conceptionModeActive
        ? const PregnancyTransitionPage()
        : const _NormalMePage();
  }
}

class _NormalMePage extends ConsumerWidget {
  const _NormalMePage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgWarmDark : AppColors.bgWarmCream,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Me & Settings', style: theme.textTheme.displaySmall),
              const SizedBox(height: 8),
              Text(
                'Privacy, insights, health reports and care-mode settings.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 22),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.terracottaContainer,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.eco_rounded,
                              color: AppColors.terracottaPrimary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Current goal',
                              style: theme.textTheme.headlineMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Normal period tracking is active. You can switch to Trying to Conceive Mode when your current goal changes.',
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: () {
                          ref
                              .read(conceptionControllerProvider.notifier)
                              .enterConceptionMode();
                          context.go('/conception/onboarding');
                        },
                        icon: const Icon(Icons.favorite_rounded),
                        label: const Text(
                          'Set current goal: Trying to conceive',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const _PersonalProfileSection(),
              const SizedBox(height: 14),
              const _AppearanceSection(),
              const SizedBox(height: 14),
              const _SecuritySection(),
              const SizedBox(height: 14),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _SettingsRow(
                        icon: Icons.insights_rounded,
                        title: 'Cycle insights',
                        subtitle: 'Historical patterns and transparent ranges',
                        route: '/insights',
                      ),
                      _SettingsRow(
                        icon: Icons.lock_rounded,
                        title: 'Notification settings',
                        subtitle: 'Permissions, privacy and quiet hours',
                        route: '/notifications/settings',
                      ),
                      _SettingsRow(
                        icon: Icons.description_rounded,
                        title: 'Health reports',
                        subtitle: 'Doctor-ready period and symptom summaries',
                        route: '/reports',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecuritySection extends ConsumerWidget {
  const _SecuritySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    final theme = Theme.of(context);

    return profileAsync.when(
      data: (profile) {
        if (profile == null) return const SizedBox.shrink();
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.sageContainer,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.security_rounded,
                        color: AppColors.sagePrimary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Security & Privacy',
                        style: theme.textTheme.headlineMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Biometric Authentication'),
                  subtitle: const Text(
                    'Require Face ID or Fingerprint to unlock Quevaa after inactivity.',
                  ),
                  value: profile.isBiometricEnabled,
                  onChanged: (value) async {
                    final db = ref.read(appDatabaseProvider);
                    await (db.update(
                      db.userProfiles,
                    )..where((tbl) => tbl.id.equals(profile.id))).write(
                      UserProfilesCompanion(
                        isBiometricEnabled: Value(value),
                        updatedAt: Value(DateTime.now()),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _AppearanceSection extends ConsumerWidget {
  const _AppearanceSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected =
        ref.watch(quevaaThemeModeProvider).valueOrNull ??
        QuevaaThemeMode.system;
    final saving = ref.watch(quevaaThemeControllerProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.purpleContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.palette_rounded,
                    color: AppColors.deepPlum,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Appearance',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                if (saving)
                  const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            for (final mode in QuevaaThemeMode.values)
              _ThemeModeTile(
                mode: mode,
                selected: selected == mode,
                onTap: saving
                    ? null
                    : () => ref
                          .read(quevaaThemeControllerProvider.notifier)
                          .setMode(mode),
              ),
          ],
        ),
      ),
    );
  }
}

class _ThemeModeTile extends StatelessWidget {
  final QuevaaThemeMode mode;
  final bool selected;
  final VoidCallback? onTap;

  const _ThemeModeTile({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = switch (mode) {
      QuevaaThemeMode.dark => (
        bg: AppColors.bgWarmDark,
        surface: AppColors.cardSurfaceDark,
        accent: AppColors.terracottaLight,
      ),
      QuevaaThemeMode.light => (
        bg: AppColors.bgWarmCream,
        surface: AppColors.cardSurfaceLight,
        accent: AppColors.terracottaPrimary,
      ),
      QuevaaThemeMode.system => (
        bg: AppColors.deepPlumContainer,
        surface: AppColors.cardSurfaceLight,
        accent: AppColors.sagePrimary,
      ),
    };
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: Container(
        width: 48,
        height: 36,
        decoration: BoxDecoration(
          color: colors.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? colors.accent : AppColors.borderLight,
            width: selected ? 2 : 1,
          ),
        ),
        child: Align(
          alignment: Alignment.bottomRight,
          child: Container(
            width: 24,
            height: 18,
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
      title: Text(mode.label),
      subtitle: Text(mode.description),
      trailing: selected
          ? Icon(Icons.check_circle_rounded, color: colors.accent)
          : const Icon(Icons.circle_outlined),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? route;

  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.route,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.sagePrimary),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: route == null ? null : () => context.go(route!),
    );
  }
}

class MainNavigationShell extends ConsumerWidget {
  final Widget child;

  const MainNavigationShell({super.key, required this.child});

  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/cycle')) return 1;
    if (location.startsWith('/plan')) return 2;
    if (location.startsWith('/wellness')) return 3;
    if (location.startsWith('/me')) return 4;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        GoRouter.of(context).go('/');
        break;
      case 1:
        GoRouter.of(context).go('/cycle');
        break;
      case 2:
        GoRouter.of(context).go('/plan');
        break;
      case 3:
        GoRouter.of(context).go('/wellness');
        break;
      case 4:
        GoRouter.of(context).go('/me');
        break;
    }
  }

  void _showQuickActionBottomSheet(
    BuildContext context,
    bool conceptionModeActive,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark
          ? AppColors.cardSurfaceDark
          : AppColors.cardSurfaceLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      conceptionModeActive
                          ? 'Log Fertility Signs'
                          : 'Log & Record',
                      style: theme.textTheme.headlineMedium,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 4,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 16,
                  children: conceptionModeActive
                      ? [
                          _QuickActionTile(
                            icon: Icons.water_drop_rounded,
                            label: 'Mucus',
                            color: AppColors.terracottaPrimary,
                            onTap: () {
                              Navigator.pop(context);
                              GoRouter.of(context).go('/conception/log');
                            },
                          ),
                          _QuickActionTile(
                            icon: Icons.science_rounded,
                            label: 'LH Test',
                            color: AppColors.sagePrimary,
                            onTap: () {
                              Navigator.pop(context);
                              GoRouter.of(context).go('/conception/log');
                            },
                          ),
                          _QuickActionTile(
                            icon: Icons.thermostat_rounded,
                            label: 'BBT',
                            color: AppColors.purplePrimary,
                            onTap: () {
                              Navigator.pop(context);
                              GoRouter.of(context).go('/conception/log');
                            },
                          ),
                          _QuickActionTile(
                            icon: Icons.favorite_rounded,
                            label: 'Intimacy',
                            color: AppColors.warmGoldPrimary,
                            onTap: () {
                              Navigator.pop(context);
                              GoRouter.of(context).go('/conception/log');
                            },
                          ),
                          _QuickActionTile(
                            icon: Icons.water_drop_outlined,
                            label: 'Water',
                            color: AppColors.waterBlue,
                            onTap: () {
                              Navigator.pop(context);
                              GoRouter.of(context).go('/wellness');
                            },
                          ),
                          _QuickActionTile(
                            icon: Icons.restaurant_rounded,
                            label: 'Meal',
                            color: AppColors.terracottaDark,
                            onTap: () {
                              Navigator.pop(context);
                              GoRouter.of(context).go('/wellness');
                            },
                          ),
                          _QuickActionTile(
                            icon: Icons.fitness_center_rounded,
                            label: 'Move',
                            color: AppColors.sageDark,
                            onTap: () {
                              Navigator.pop(context);
                              GoRouter.of(context).go('/wellness');
                            },
                          ),
                          _QuickActionTile(
                            icon: Icons.edit_note_rounded,
                            label: 'Journal',
                            color: AppColors.purpleDark,
                            onTap: () {
                              Navigator.pop(context);
                              GoRouter.of(context).go('/wellness');
                            },
                          ),
                        ]
                      : [
                          _QuickActionTile(
                            icon: Icons.water_drop_rounded,
                            label: 'Period',
                            color: AppColors.terracottaPrimary,
                            onTap: () {
                              Navigator.pop(context);
                              GoRouter.of(context).go('/cycle');
                            },
                          ),
                          _QuickActionTile(
                            icon: Icons.health_and_safety_rounded,
                            label: 'Symptoms',
                            color: AppColors.sagePrimary,
                            onTap: () {
                              Navigator.pop(context);
                              GoRouter.of(context).go('/cycle');
                            },
                          ),
                          _QuickActionTile(
                            icon: Icons.sentiment_satisfied_alt_rounded,
                            label: 'Mood',
                            color: AppColors.purplePrimary,
                            onTap: () {
                              Navigator.pop(context);
                              GoRouter.of(context).go('/cycle');
                            },
                          ),
                          _QuickActionTile(
                            icon: Icons.add_task_rounded,
                            label: 'Add Task',
                            color: AppColors.warmGoldPrimary,
                            onTap: () {
                              Navigator.pop(context);
                              GoRouter.of(context).go('/plan');
                            },
                          ),
                          _QuickActionTile(
                            icon: Icons.water_drop_outlined,
                            label: 'Water',
                            color: AppColors.waterBlue,
                            onTap: () {
                              Navigator.pop(context);
                              GoRouter.of(context).go('/wellness');
                            },
                          ),
                          _QuickActionTile(
                            icon: Icons.restaurant_rounded,
                            label: 'Meal',
                            color: AppColors.terracottaDark,
                            onTap: () {
                              Navigator.pop(context);
                              GoRouter.of(context).go('/wellness');
                            },
                          ),
                          _QuickActionTile(
                            icon: Icons.fitness_center_rounded,
                            label: 'Workout',
                            color: AppColors.sageDark,
                            onTap: () {
                              Navigator.pop(context);
                              GoRouter.of(context).go('/wellness');
                            },
                          ),
                          _QuickActionTile(
                            icon: Icons.edit_note_rounded,
                            label: 'Journal',
                            color: AppColors.purpleDark,
                            onTap: () {
                              Navigator.pop(context);
                              GoRouter.of(context).go('/wellness');
                            },
                          ),
                        ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = _calculateSelectedIndex(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final conceptionModeActive = ref.watch(conceptionModeActiveProvider);

    return Scaffold(
      body: child,
      floatingActionButton:
          selectedIndex == 0 ||
              selectedIndex == 1 ||
              selectedIndex == 2 ||
              selectedIndex == 3
          ? null
          : Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FloatingActionButton(
                onPressed: () =>
                    _showQuickActionBottomSheet(context, conceptionModeActive),
                backgroundColor: AppColors.terracottaPrimary,
                elevation: 4,
                shape: const CircleBorder(),
                child: const Icon(
                  Icons.add_rounded,
                  size: 32,
                  color: Colors.white,
                ),
              ),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: selectedIndex,
          onTap: (index) => _onItemTapped(index, context),
          selectedItemColor: isDark
              ? AppColors.terracottaLight
              : AppColors.terracottaPrimary,
          unselectedItemColor: isDark
              ? AppColors.textSecondaryDark
              : AppColors.textSecondaryLight,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.favorite_rounded, size: 22),
              label: 'Today',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today_rounded, size: 22),
              label: 'Cycle',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.task_alt_rounded, size: 22),
              label: 'Plan',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.spa_rounded, size: 22),
              label: 'Wellness',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_rounded, size: 22),
              label: 'Me',
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _PersonalProfileSection extends ConsumerWidget {
  const _PersonalProfileSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    final theme = Theme.of(context);

    return profileAsync.when(
      data: (profile) {
        if (profile == null) return const SizedBox.shrink();
        final lastPeriodStr = profile.lastPeriodStartDate != null
            ? DateFormat('d MMM yyyy').format(profile.lastPeriodStartDate!)
            : 'Not set';

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.terracottaContainer,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        color: AppColors.terracottaPrimary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Personal & Cycle Profile',
                        style: theme.textTheme.headlineMedium,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.edit_rounded,
                        color: AppColors.terracottaPrimary,
                      ),
                      tooltip: 'Edit Profile',
                      onPressed: () =>
                          _showEditProfileModal(context, ref, profile),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _ProfileDetailRow(label: 'Name', value: profile.userName),
                const Divider(height: 20),
                _ProfileDetailRow(
                  label: 'Age',
                  value: profile.age != null
                      ? '${profile.age} years old'
                      : 'Not set',
                ),
                const Divider(height: 20),
                _ProfileDetailRow(
                  label: 'Average Period Duration',
                  value: '${profile.averagePeriodLength} days',
                ),
                const Divider(height: 20),
                _ProfileDetailRow(
                  label: 'Average Cycle Length',
                  value: '${profile.averageCycleLength} days',
                ),
                const Divider(height: 20),
                _ProfileDetailRow(
                  label: 'Last Period Start',
                  value: lastPeriodStr,
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => _showEditProfileModal(context, ref, profile),
                  icon: const Icon(Icons.edit_note_rounded),
                  label: const Text('Edit Profile & Cycle Parameters'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  void _showEditProfileModal(
    BuildContext context,
    WidgetRef ref,
    UserProfile profile,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? AppColors.cardSurfaceDark
          : AppColors.cardSurfaceLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return _EditProfileBottomSheet(profile: profile);
      },
    );
  }
}

class _ProfileDetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _ProfileDetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _EditProfileBottomSheet extends ConsumerStatefulWidget {
  final UserProfile profile;

  const _EditProfileBottomSheet({required this.profile});

  @override
  ConsumerState<_EditProfileBottomSheet> createState() =>
      _EditProfileBottomSheetState();
}

class _EditProfileBottomSheetState
    extends ConsumerState<_EditProfileBottomSheet> {
  late TextEditingController _nameController;
  late TextEditingController _ageController;
  late int _periodLength;
  late int _cycleLength;
  DateTime? _lastPeriodDate;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.userName);
    _ageController = TextEditingController(
      text: widget.profile.age?.toString() ?? '',
    );
    _periodLength = widget.profile.averagePeriodLength;
    _cycleLength = widget.profile.averageCycleLength;
    _lastPeriodDate = widget.profile.lastPeriodStartDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final db = ref.read(appDatabaseProvider);
    final ageParsed = int.tryParse(_ageController.text.trim());

    await (db.update(
      db.userProfiles,
    )..where((tbl) => tbl.id.equals(widget.profile.id))).write(
      UserProfilesCompanion(
        userName: Value(_nameController.text.trim()),
        age: Value(ageParsed),
        averagePeriodLength: Value(_periodLength),
        averageCycleLength: Value(_cycleLength),
        lastPeriodStartDate: Value(_lastPeriodDate),
        updatedAt: Value(DateTime.now()),
      ),
    );

    if (_lastPeriodDate != null) {
      final existingPeriod = await (db.select(
        db.cyclePeriods,
      )..limit(1)).getSingleOrNull();
      if (existingPeriod != null) {
        await (db.update(
          db.cyclePeriods,
        )..where((tbl) => tbl.id.equals(existingPeriod.id))).write(
          CyclePeriodsCompanion(
            startDate: Value(_lastPeriodDate!),
            endDate: Value(
              _lastPeriodDate!.add(Duration(days: _periodLength - 1)),
            ),
            updatedAt: Value(DateTime.now()),
          ),
        );
      } else {
        await db
            .into(db.cyclePeriods)
            .insert(
              CyclePeriodsCompanion.insert(
                startDate: _lastPeriodDate!,
                endDate: Value(
                  _lastPeriodDate!.add(Duration(days: _periodLength - 1)),
                ),
                uuid: DateTime.now().millisecondsSinceEpoch.toString(),
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
            );
      }
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondaryText = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Edit Profile & Cycle',
                  style: theme.textTheme.headlineMedium,
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'Enter your name',
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _ageController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Age',
                hintText: 'Enter age in years',
              ),
            ),
            const SizedBox(height: 20),
            // Period length
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Period Duration', style: theme.textTheme.titleMedium),
                    Text(
                      'Typical bleeding days',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: secondaryText,
                      ),
                    ),
                  ],
                ),
                Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? AppColors.borderDark
                          : AppColors.borderLight,
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_rounded, size: 20),
                        onPressed: _periodLength > 1
                            ? () => setState(() => _periodLength--)
                            : null,
                      ),
                      Text(
                        '$_periodLength days',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_rounded, size: 20),
                        onPressed: _periodLength < 15
                            ? () => setState(() => _periodLength++)
                            : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Cycle length
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cycle Length', style: theme.textTheme.titleMedium),
                    Text(
                      'Days between period starts',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: secondaryText,
                      ),
                    ),
                  ],
                ),
                Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? AppColors.borderDark
                          : AppColors.borderLight,
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_rounded, size: 20),
                        onPressed: _cycleLength > 15
                            ? () => setState(() => _cycleLength--)
                            : null,
                      ),
                      Text(
                        '$_cycleLength days',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_rounded, size: 20),
                        onPressed: _cycleLength < 60
                            ? () => setState(() => _cycleLength++)
                            : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Last period start date
            Text('Last Period Start Date', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _lastPeriodDate ?? DateTime.now(),
                  firstDate: DateTime.now().subtract(const Duration(days: 180)),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  setState(() => _lastPeriodDate = picked);
                }
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _lastPeriodDate != null
                        ? AppColors.terracottaPrimary
                        : (isDark
                              ? AppColors.borderDark
                              : AppColors.borderLight),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_month_rounded,
                      color: AppColors.terracottaPrimary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _lastPeriodDate != null
                            ? DateFormat(
                                'EEEE, d MMMM yyyy',
                              ).format(_lastPeriodDate!)
                            : 'Select date',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: _lastPeriodDate != null
                              ? (isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimaryLight)
                              : secondaryText,
                          fontWeight: _lastPeriodDate != null
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.terracottaPrimary,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isSaving
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Save Changes',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
