import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../application/providers/onboarding_provider.dart';
import '../widgets/cycle_care_hero.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final PageController _pageController = PageController(keepPage: false);
  int _currentStep = 0;

  final List<String> _goals = [
    'Understand my period',
    'Prepare for my next period',
    'Manage symptoms',
    'Build healthier routines',
    'Plan tasks around my energy',
    'Eat more balanced Nigerian meals',
    'Exercise consistently',
    'Improve emotional wellbeing',
    'Prepare information for a doctor',
    'Try to conceive',
  ];

  void _nextPage() {
    if (_currentStep < 6) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  void _skipPage() {
    _nextPage();
  }

  Future<void> _finishOnboarding() async {
    final profile = ref.read(onboardingProfileProvider);
    await ref.read(onboardingProfileProvider.notifier).completeOnboarding();
    if (mounted) {
      if (profile.primaryGoal == 'Try to conceive') {
        context.go('/conception/onboarding');
      } else {
        context.go('/');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgWarmDark : AppColors.bgWarmCream,
      appBar: AppBar(
        toolbarHeight: _currentStep == 0 ? 0 : kToolbarHeight,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_currentStep > 0 && _currentStep < 6)
            TextButton(
              onPressed: _skipPage,
              child: const Text(
                'Skip',
                style: TextStyle(
                  color: AppColors.terracottaPrimary,
                  fontSize: 16,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress Bar
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 8.0,
              ),
              child: Row(
                children: List.generate(7, (index) {
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: index <= _currentStep
                            ? AppColors.terracottaPrimary
                            : AppColors.borderLight,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),

            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) {
                  setState(() => _currentStep = index);
                },
                children: [
                  _buildWelcomeStep(theme),
                  _buildCycleProfileStep(theme),
                  _buildProductivityStep(theme),
                  _buildMealStep(theme),
                  _buildWorkoutStep(theme),
                  _buildPrivacyStep(theme),
                  _buildCompletionStep(theme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeStep(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final secondaryText = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxHeight < 720;

        return Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 12),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 112,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CycleCareHero(height: isCompact ? 248 : 292)
                          .animate()
                          .fadeIn(duration: 650.ms)
                          .slideY(
                            begin: 0.08,
                            end: 0,
                            curve: Curves.easeOutCubic,
                          ),
                      SizedBox(height: isCompact ? 20 : 28),
                      Semantics(
                        label: 'Quevaa logo',
                        image: true,
                        child: Image.asset(
                          'assets/branding/quevaa_wordmark.png',
                          height: isCompact ? 42 : 50,
                          fit: BoxFit.contain,
                        ),
                      ).animate().fadeIn(duration: 450.ms, delay: 100.ms),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : AppColors.terracottaContainer,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.10)
                                : AppColors.borderLight,
                          ),
                        ),
                        child: Text(
                          'Private cycle care, beautifully personal',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: isDark
                                ? AppColors.terracottaLight
                                : AppColors.terracottaDark,
                          ),
                        ),
                      ).animate().fadeIn(duration: 450.ms, delay: 140.ms),
                      const SizedBox(height: 14),
                      Text(
                            'Welcome to Quevaa',
                            style: theme.textTheme.displayLarge?.copyWith(
                              fontSize: isCompact ? 30 : 34,
                              height: 1.04,
                            ),
                          )
                          .animate()
                          .fadeIn(duration: 520.ms, delay: 200.ms)
                          .slideX(begin: -0.04, end: 0),
                      const SizedBox(height: 12),
                      Text(
                        'A calm, intelligent space for period tracking, symptom care, energy planning, movement, and nourishing Nigerian meals.',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: secondaryText,
                          height: 1.55,
                        ),
                      ).animate().fadeIn(duration: 520.ms, delay: 260.ms),
                      SizedBox(height: isCompact ? 18 : 24),
                      const Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _WelcomeMetric(
                            icon: Icons.lock_rounded,
                            label: 'Offline-first',
                          ),
                          _WelcomeMetric(
                            icon: Icons.auto_awesome_rounded,
                            label: 'Cycle-aware',
                          ),
                          _WelcomeMetric(
                            icon: Icons.spa_rounded,
                            label: 'Care rituals',
                          ),
                        ],
                      ).animate().fadeIn(duration: 500.ms, delay: 320.ms),
                      SizedBox(height: isCompact ? 18 : 24),
                      const _BenefitTile(
                        icon: Icons.calendar_today_rounded,
                        title: 'Predict the rhythm',
                        subtitle:
                            'See estimated cycle windows, phase context, and gentle reminders.',
                      ),
                      const SizedBox(height: 14),
                      const _BenefitTile(
                        icon: Icons.health_and_safety_rounded,
                        title: 'Care for period days',
                        subtitle:
                            'Log symptoms, rest needs, pain cues, mood, hydration, and recovery.',
                      ),
                      const SizedBox(height: 14),
                      const _BenefitTile(
                        icon: Icons.restaurant_rounded,
                        title: 'Nourish with intention',
                        subtitle:
                            'Get culturally familiar meal ideas aligned with your body signals.',
                      ),
                      SizedBox(height: isCompact ? 18 : 24),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
              child:
                  ElevatedButton.icon(
                        onPressed: _nextPage,
                        icon: const Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                        ),
                        label: const Text(
                          'Begin Your Care Journey',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.terracottaPrimary,
                          minimumSize: const Size(double.infinity, 56),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      )
                      .animate()
                      .fadeIn(duration: 500.ms, delay: 420.ms)
                      .slideY(begin: 0.14, end: 0),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCycleProfileStep(ThemeData theme) {
    final profile = ref.watch(onboardingProfileProvider);
    final isDark = theme.brightness == Brightness.dark;
    final secondaryText = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cycle Profile', style: theme.textTheme.displaySmall),
          const SizedBox(height: 8),
          Text(
            'Help Quevaa estimate your rhythm (all questions are optional).',
            style: theme.textTheme.bodyMedium?.copyWith(color: secondaryText),
          ),
          const SizedBox(height: 24),
          Text('What is your primary goal?', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _goals.map((goal) {
              final isSelected = profile.primaryGoal == goal;
              return ChoiceChip(
                label: Text(goal),
                selected: isSelected,
                showCheckmark: false,
                backgroundColor: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.white,
                selectedColor: AppColors.terracottaContainer,
                labelStyle: theme.textTheme.labelLarge?.copyWith(
                  color: isSelected
                      ? AppColors.terracottaDark
                      : (isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight),
                  fontWeight: FontWeight.w700,
                ),
                side: BorderSide(
                  color: isSelected
                      ? AppColors.terracottaLight
                      : (isDark ? AppColors.borderDark : AppColors.borderLight),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                onSelected: (selected) {
                  if (selected) {
                    ref
                        .read(onboardingProfileProvider.notifier)
                        .updateProfile(profile.copyWith(primaryGoal: goal));
                  }
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _nextPage,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.terracottaPrimary,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'Continue',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductivityStep(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Productivity Profile', style: theme.textTheme.displaySmall),
          const SizedBox(height: 8),
          Text(
            'Tailor focus sessions and task recommendations to your working style.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 32),
          const _BenefitTile(
            icon: Icons.timer_rounded,
            title: '25-minute Pomodoro Focus',
            subtitle: 'Recommended default focus duration.',
          ),
          const SizedBox(height: 16),
          const _BenefitTile(
            icon: Icons.wb_sunny_rounded,
            title: 'Morning Peak Energy',
            subtitle: 'Schedule deep work during peak focus hours.',
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: _nextPage,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.terracottaPrimary,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'Continue',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealStep(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Nigerian Cuisine Profile', style: theme.textTheme.displaySmall),
          const SizedBox(height: 8),
          Text(
            'Discover nutrient-rich regional meals tailored to your cycle needs.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 32),
          const _BenefitTile(
            icon: Icons.rice_bowl_rounded,
            title: 'Iron & Magnesium Boosts',
            subtitle:
                'Ugu soup, Plantain, Snail & Liver for menstrual recovery.',
          ),
          const SizedBox(height: 16),
          const _BenefitTile(
            icon: Icons.set_meal_rounded,
            title: 'Light & Energizing Dishes',
            subtitle:
                'Fresh fish pepper soup, Abacha & Ogi for follicular energy.',
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: _nextPage,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.terracottaPrimary,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'Continue',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutStep(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Movement Profile', style: theme.textTheme.displaySmall),
          const SizedBox(height: 8),
          Text(
            'Gentle movement and exercise aligned with how you feel.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 32),
          const _BenefitTile(
            icon: Icons.spa_rounded,
            title: 'Yin Yoga & Walking',
            subtitle: 'Low-impact movement when energy is lower.',
          ),
          const SizedBox(height: 16),
          const _BenefitTile(
            icon: Icons.fitness_center_rounded,
            title: 'Strength & Pilates',
            subtitle: 'Moderate movement during high-energy windows.',
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: _nextPage,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.terracottaPrimary,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'Continue',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyStep(ThemeData theme) {
    final profile = ref.watch(onboardingProfileProvider);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Privacy Setup', style: theme.textTheme.displaySmall),
          const SizedBox(height: 8),
          Text(
            'Your health data is stored strictly on your device.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 32),
          SwitchListTile(
            title: const Text('Enable Biometric Lock'),
            subtitle: const Text(
              'Require FaceID / Fingerprint / PIN to open Quevaa',
            ),
            value: profile.enableBiometrics,
            onChanged: (val) {
              ref
                  .read(onboardingProfileProvider.notifier)
                  .updateProfile(profile.copyWith(enableBiometrics: val));
            },
          ),
          SwitchListTile(
            title: const Text('Discreet Notifications'),
            subtitle: const Text(
              'Hide sensitive health terms on lock screen reminders',
            ),
            value: profile.enableDiscreetNotifications,
            onChanged: (val) {
              ref
                  .read(onboardingProfileProvider.notifier)
                  .updateProfile(
                    profile.copyWith(enableDiscreetNotifications: val),
                  );
            },
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: _nextPage,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.terracottaPrimary,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'Complete Setup',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionStep(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: AppColors.sageContainer,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: AppColors.sageDark,
              size: 64,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Quevaa is Ready',
            style: theme.textTheme.displaySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Quevaa is ready. Your recommendations will become more personal as you log your days.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: AppColors.textSecondaryLight,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          ElevatedButton(
            onPressed: _finishOnboarding,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.terracottaPrimary,
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'Enter Quevaa',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BenefitTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _BenefitTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.terracottaContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.terracottaPrimary, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.textSecondaryLight,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WelcomeMetric extends StatelessWidget {
  final IconData icon;
  final String label;

  const _WelcomeMetric({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.07) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : AppColors.borderLight,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.sagePrimary),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondaryLight,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
