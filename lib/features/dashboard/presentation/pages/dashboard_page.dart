import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/models/prediction_confidence.dart';
import '../../../cycle/application/cycle_workspace_provider.dart';
import '../../../cycle/domain/models/cycle_engine_output.dart';
import '../../../dashboard/domain/readiness_calculator.dart';
import '../../../insights/domain/insight_generator.dart';
import '../../../nutrition/data/nigerian_recipe_database.dart';
import '../../../../core/providers/user_profile_provider.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  int _selectedEnergy = 3;
  int _selectedPain = 0;
  double _selectedSleep = 7.5;
  int _activeMealIndex = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cycleOutput = ref.watch(currentCycleOutputProvider);

    final readiness = ReadinessCalculator.calculate(
      selfReportedEnergy: _selectedEnergy,
      sleepHours: _selectedSleep,
      painLevel: _selectedPain,
      estimatedPhase: cycleOutput.estimatedPhase,
    );

    final recipes = NigerianRecipeDatabase.getForPhase(
      cycleOutput.estimatedPhase,
    );
    final currentRecipe = recipes.isNotEmpty
        ? recipes[_activeMealIndex % recipes.length]
        : NigerianRecipeDatabase.recipes.first;

    final insights = InsightGenerator.generateInsights(
      loggedEntries: [
        {
          'symptoms': ['Cramps'],
          'sleepHours': 8,
          'energy': 4,
          'waterGlasses': 8,
        },
        {
          'symptoms': ['Cramps'],
          'sleepHours': 7.5,
          'energy': 4,
          'waterGlasses': 8,
        },
        {'symptoms': [], 'sleepHours': 8, 'energy': 4, 'waterGlasses': 7},
      ],
    );

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgWarmDark : AppColors.bgWarmCream,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DashboardHeader(
                onNotificationsTap: () => context.go('/notifications/settings'),
              ),
              const SizedBox(height: 20),

              // Rhythm Card
              _RhythmCard(output: cycleOutput)
                  .animate()
                  .fadeIn(duration: 450.ms)
                  .slideY(begin: 0.06, end: 0, curve: Curves.easeOutCubic),
              const SizedBox(height: 20),

              // How are you today? (Quick Inputs)
              _QuickInputsCard(
                energy: _selectedEnergy,
                pain: _selectedPain,
                sleep: _selectedSleep,
                onEnergyChanged: (v) => setState(() => _selectedEnergy = v),
                onPainChanged: (v) => setState(() => _selectedPain = v),
                onSleepChanged: (v) => setState(() => _selectedSleep = v),
              ),
              const SizedBox(height: 20),

              // Daily Readiness Card
              _ReadinessCard(readiness: readiness),
              const SizedBox(height: 20),

              // Today's Focus
              _TodayFocusCard(
                readiness: readiness,
                onAdjustPlan: () => context.go('/plan'),
              ),
              const SizedBox(height: 20),

              // Eat Well Today (Nigerian Cuisine)
              _NigerianMealCard(
                recipe: currentRecipe,
                onSwapMeal: () {
                  setState(() {
                    _activeMealIndex++;
                  });
                },
              ),
              const SizedBox(height: 20),

              // Move Today (Workouts)
              _MoveTodayCard(
                readiness: readiness,
                onSubstitute: () => context.go('/wellness'),
              ),
              const SizedBox(height: 20),

              // Reflect & Journal Prompt
              _ReflectCard(),
              const SizedBox(height: 20),

              // Quick Insights Section
              if (insights.isNotEmpty) ...[
                Text('Quick Insights', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 12),
                ...insights.map((insight) => _InsightTile(insight: insight)),
              ],
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardHeader extends ConsumerWidget {
  final VoidCallback onNotificationsTap;

  const _DashboardHeader({required this.onNotificationsTap});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondaryText = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final name = profile?.userName ?? 'Adaora';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.cardSurfaceDark
            : Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_getGreeting()}, $name',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontSize: 22,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your personal rhythm and wellness overview',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: secondaryText,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.07)
                  : AppColors.terracottaContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: IconButton(
              tooltip: 'Notifications',
              icon: const Icon(Icons.notifications_none_rounded, size: 24),
              color: isDark
                  ? AppColors.terracottaLight
                  : AppColors.terracottaPrimary,
              onPressed: onNotificationsTap,
            ),
          ),
        ],
      ),
    );
  }
}

class _RhythmCard extends StatelessWidget {
  final CycleEngineOutput output;

  const _RhythmCard({required this.output});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final df = DateFormat('d MMM');
    final primaryPred = output.periodPredictions.firstOrNull;

    final String periodText;
    final String? possibleStartText;

    if (primaryPred != null) {
      final bleedingStart = df.format(primaryPred.predictedBleedingRange.start);
      final bleedingEnd = df.format(primaryPred.predictedBleedingRange.end);
      periodText =
          'Next Period: $bleedingStart (${primaryPred.expectedDurationDays} days, $bleedingStart–$bleedingEnd)';

      if (output.confidence == PredictionConfidence.low ||
          primaryPred.possibleStartRange.start !=
              primaryPred.estimatedStartDate) {
        possibleStartText =
            'Possible start range: ${df.format(primaryPred.possibleStartRange.start)}–${df.format(primaryPred.possibleStartRange.end)}';
      } else {
        possibleStartText = null;
      }
    } else {
      periodText = 'Next Period: ${output.formattedPeriodRange}';
      possibleStartText = null;
    }

    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardSurfaceDark : AppColors.deepPlum,
        borderRadius: BorderRadius.circular(24),
        border: isDark
            ? Border.all(color: AppColors.borderDark, width: 1)
            : null,
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : AppColors.deepPlum).withValues(
              alpha: 0.25,
            ),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.terracottaPrimary.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  output.hasEnoughData
                      ? 'Cycle Day ${output.currentCycleDay}'
                      : 'Cycle Tracker',
                  style: const TextStyle(
                    color: AppColors.terracottaLight,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Confidence: ${formatPredictionConfidence(output.confidence).toUpperCase()}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            output.estimatedPhase,
            style: theme.textTheme.displayMedium?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.calendar_month_rounded,
                  color: AppColors.terracottaLight,
                  size: 16,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      periodText,
                      style: const TextStyle(
                        color: Color(0xE6FFFFFF),
                        fontSize: 14,
                      ),
                    ),
                    if (possibleStartText != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        possibleStartText,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickInputsCard extends StatelessWidget {
  final int energy;
  final int pain;
  final double sleep;
  final ValueChanged<int> onEnergyChanged;
  final ValueChanged<int> onPainChanged;
  final ValueChanged<double> onSleepChanged;

  const _QuickInputsCard({
    required this.energy,
    required this.pain,
    required this.sleep,
    required this.onEnergyChanged,
    required this.onPainChanged,
    required this.onSleepChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How are you feeling today?',
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            _RatingRow(
              label: 'Energy Level',
              selectedValue: energy,
              activeIcon: Icons.bolt_rounded,
              inactiveIcon: Icons.bolt_outlined,
              activeColor: AppColors.warmGold,
              onChanged: onEnergyChanged,
            ),
            const SizedBox(height: 6),
            _RatingRow(
              label: 'Pain / Discomfort',
              selectedValue: pain,
              activeIcon: Icons.error_rounded,
              inactiveIcon: Icons.error_outline_rounded,
              activeColor: AppColors.terracottaPrimary,
              onChanged: onPainChanged,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Sleep',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '${sleep.toStringAsFixed(1)}h',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.sageLight
                        : AppColors.sageDark,
                  ),
                ),
              ],
            ),
            Slider(
              value: sleep,
              min: 4,
              max: 10,
              divisions: 12,
              label: '${sleep.toStringAsFixed(1)}h',
              onChanged: onSleepChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _RatingRow extends StatelessWidget {
  final String label;
  final int selectedValue;
  final IconData activeIcon;
  final IconData inactiveIcon;
  final Color activeColor;
  final ValueChanged<int> onChanged;

  const _RatingRow({
    required this.label,
    required this.selectedValue,
    required this.activeIcon,
    required this.inactiveIcon,
    required this.activeColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (index) {
            final value = index + 1;
            final isSelected = value <= selectedValue;

            return IconButton(
              constraints: const BoxConstraints.tightFor(width: 36, height: 36),
              padding: EdgeInsets.zero,
              iconSize: 22,
              tooltip: '$label $value',
              icon: Icon(
                isSelected ? activeIcon : inactiveIcon,
                color: isSelected ? activeColor : Colors.grey,
              ),
              onPressed: () => onChanged(value),
            );
          }),
        ),
      ],
    );
  }
}

class _ReadinessCard extends StatelessWidget {
  final DailyReadinessResult readiness;

  const _ReadinessCard({required this.readiness});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      color: isDark ? AppColors.cycleFollicularDark : AppColors.sageContainer,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.spa_rounded,
                  color: isDark ? AppColors.sageLight : AppColors.sageDark,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Daily Readiness: ${readiness.label}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.sageDark,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              readiness.description,
              style: TextStyle(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textPrimaryLight,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayFocusCard extends StatelessWidget {
  final DailyReadinessResult readiness;
  final VoidCallback onAdjustPlan;

  const _TodayFocusCard({required this.readiness, required this.onAdjustPlan});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    "Today's Focus",
                    style: theme.textTheme.headlineMedium,
                  ),
                ),
                TextButton(
                  onPressed: onAdjustPlan,
                  child: const Text('Adjust Plan'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.cycleMenstrualPredictedDark
                    : AppColors.terracottaContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.star_rounded,
                    color: isDark
                        ? AppColors.terracottaLight
                        : AppColors.terracottaPrimary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      readiness.recommendedPriority,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ...readiness.lighterTasks.map(
              (task) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline_rounded,
                      size: 18,
                      color: isDark
                          ? AppColors.sageLight
                          : AppColors.sagePrimary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(task)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NigerianMealCard extends StatelessWidget {
  final NigerianRecipe recipe;
  final VoidCallback onSwapMeal;

  const _NigerianMealCard({required this.recipe, required this.onSwapMeal});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.restaurant_rounded,
                  color: AppColors.terracottaPrimary,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Eat Well Today',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.headlineMedium,
                  ),
                ),
                TextButton.icon(
                  onPressed: onSwapMeal,
                  icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                  label: const Text('Swap'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              recipe.title,
              style: theme.textTheme.titleLarge?.copyWith(
                color: isDark
                    ? AppColors.terracottaLight
                    : AppColors.terracottaDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              recipe.description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.cycleOvulationDark
                    : AppColors.warmGoldContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Key Nutrients: ${recipe.keyNutrients}',
                style: TextStyle(
                  color: isDark
                      ? AppColors.warmGold
                      : AppColors.warmGoldPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoveTodayCard extends StatelessWidget {
  final DailyReadinessResult readiness;
  final VoidCallback onSubstitute;

  const _MoveTodayCard({required this.readiness, required this.onSubstitute});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.fitness_center_rounded,
                  color: isDark ? AppColors.sageLight : AppColors.sageDark,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text('Move Today', style: theme.textTheme.headlineMedium),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              readiness.recommendedWorkout,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onSubstitute,
              icon: const Icon(Icons.alt_route_rounded, size: 18),
              label: const Text('Substitute Exercise'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReflectCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.edit_note_rounded,
                  color: isDark
                      ? AppColors.purpleLight
                      : AppColors.purplePrimary,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text('Reflect', style: theme.textTheme.headlineMedium),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Journal Prompt:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              '"What is one thing your body needed today, and how did you listen?"',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontStyle: FontStyle.italic,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightTile extends StatelessWidget {
  final TransparentInsight insight;

  const _InsightTile({required this.insight});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      color: isDark ? AppColors.cycleLutealDark : AppColors.purpleContainer,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              insight.title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.purpleLight : AppColors.purplePrimary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              insight.observation,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              insight.context,
              style: TextStyle(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
