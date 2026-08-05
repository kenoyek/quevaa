import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/conception/application/conception_controller.dart';
import '../../features/conception/application/conception_settings_provider.dart';
import '../../features/conception/presentation/pages/conception_dashboard_page.dart';
import '../../features/conception/presentation/pages/conception_onboarding_page.dart';
import '../../features/conception/presentation/pages/conception_wellness_page.dart';
import '../../features/conception/presentation/pages/fertility_log_page.dart';
import '../../features/conception/presentation/pages/pregnancy_transition_page.dart';
import '../../features/conception/presentation/pages/temperature_chart_page.dart';
import '../../features/conception/presentation/pages/waiting_phase_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/notifications/presentation/notification_settings_page.dart';
import '../../features/onboarding/presentation/pages/onboarding_page.dart';
import '../theme/app_colors.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'shell',
);

final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/onboarding',
  routes: [
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
      path: '/notifications/settings',
      builder: (context, state) => const NotificationSettingsPage(),
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
          builder: (context, state) => const _ModeAwareWellnessPage(),
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
        ? const TemperatureChartPage()
        : const PlaceholderScreen(
            title: 'Cycle & Symptom Log',
            subtitle: 'Estimated Cycle Windows, Range Predictions & Symptoms',
            icon: Icons.calendar_month_rounded,
          );
  }
}

class _ModeAwarePlanPage extends ConsumerWidget {
  const _ModeAwarePlanPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conceptionModeActive = ref.watch(conceptionModeActiveProvider);
    return conceptionModeActive
        ? const WaitingPhasePage()
        : const PlaceholderScreen(
            title: 'Plan & Productivity',
            subtitle: 'Adaptive Task Suggestions Based on Energy & Symptoms',
            icon: Icons.task_alt_rounded,
          );
  }
}

class _ModeAwareWellnessPage extends ConsumerWidget {
  const _ModeAwareWellnessPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conceptionModeActive = ref.watch(conceptionModeActiveProvider);
    return conceptionModeActive
        ? const ConceptionWellnessPage()
        : const PlaceholderScreen(
            title: 'Wellness & Nourish',
            subtitle: 'Nigerian Cuisine, Guided Workouts & Private Journal',
            icon: Icons.spa_rounded,
          );
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
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _SettingsRow(
                        icon: Icons.insights_rounded,
                        title: 'Cycle insights',
                        subtitle: 'Historical patterns and transparent ranges',
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
                            onTap: () => Navigator.pop(context),
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
                            onTap: () => Navigator.pop(context),
                          ),
                        ]
                      : [
                          _QuickActionTile(
                            icon: Icons.water_drop_rounded,
                            label: 'Period',
                            color: AppColors.terracottaPrimary,
                            onTap: () => Navigator.pop(context),
                          ),
                          _QuickActionTile(
                            icon: Icons.health_and_safety_rounded,
                            label: 'Symptoms',
                            color: AppColors.sagePrimary,
                            onTap: () => Navigator.pop(context),
                          ),
                          _QuickActionTile(
                            icon: Icons.sentiment_satisfied_alt_rounded,
                            label: 'Mood',
                            color: AppColors.purplePrimary,
                            onTap: () => Navigator.pop(context),
                          ),
                          _QuickActionTile(
                            icon: Icons.add_task_rounded,
                            label: 'Add Task',
                            color: AppColors.warmGoldPrimary,
                            onTap: () => Navigator.pop(context),
                          ),
                          _QuickActionTile(
                            icon: Icons.water_drop_outlined,
                            label: 'Water',
                            color: AppColors.waterBlue,
                            onTap: () => Navigator.pop(context),
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
                            onTap: () => Navigator.pop(context),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            _showQuickActionBottomSheet(context, conceptionModeActive),
        backgroundColor: AppColors.terracottaPrimary,
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.add_rounded, size: 32, color: Colors.white),
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

class PlaceholderScreen extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const PlaceholderScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: AppColors.terracottaContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 44, color: AppColors.terracottaPrimary),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: theme.textTheme.displaySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.cardSurfaceDark
                      : AppColors.cardSurfaceLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF2E2A27)
                        : const Color(0xFFEFEBE4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.verified_user_rounded,
                      size: 18,
                      color: AppColors.sagePrimary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Quevaa System Active',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: AppColors.sageDark,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
