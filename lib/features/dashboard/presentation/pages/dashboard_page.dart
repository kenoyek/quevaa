import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/models/prediction_confidence.dart';
import '../../../cycle/application/cycle_workspace_provider.dart';
import '../../../cycle/domain/models/cycle_engine_output.dart';
import '../../../dashboard/domain/readiness_calculator.dart';
import '../../../insights/domain/insight_generator.dart';
import '../../../nutrition/data/nigerian_recipe_database.dart';
import '../../../notifications/presentation/widgets/notification_bell_button.dart';
import '../../../recommendations/application/daily_quevaa_plan_provider.dart';
import '../../../workouts/domain/entities/workout_entity.dart';
import 'dart:convert';
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
  bool _isInitialized = false;

  Future<void> _updateLog({int? energy, int? pain, double? sleep}) async {
    final newEnergy = energy ?? _selectedEnergy;
    final newPain = pain ?? _selectedPain;
    final newSleep = sleep ?? _selectedSleep;

    setState(() {
      _selectedEnergy = newEnergy;
      _selectedPain = newPain;
      _selectedSleep = newSleep;
    });

    final log = ref.read(todaysDailyLogProvider).valueOrNull;
    final symptoms = <String>[];
    if (log != null) {
      try {
        final decoded = jsonDecode(log.customSymptomsJson);
        if (decoded is List) {
          symptoms.addAll(decoded.map((e) => e.toString()));
        }
      } catch (_) {}
    }

    await ref
        .read(cycleWorkspaceControllerProvider.notifier)
        .saveDailyLog(
          date: DateTime.now(),
          flow: log?.flow ?? 'None',
          pain: newPain,
          mood: log?.mood ?? 'Neutral',
          energy: newEnergy,
          stress: log?.stressLevel ?? 3,
          sleepQuality: log?.sleepQuality ?? 3,
          sleepHours: newSleep,
          water: log?.waterGlasses ?? 0,
          symptoms: symptoms,
          notes: log?.generalNotes,
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    ref.listen(todaysDailyLogProvider, (prev, next) {
      final log = next.valueOrNull;
      if (log != null && (!_isInitialized || prev?.valueOrNull?.id != log.id)) {
        setState(() {
          _isInitialized = true;
          _selectedEnergy = log.energyLevel;
          _selectedPain = log.painLevel;
          _selectedSleep = log.sleepHours ?? 7.5;
        });
      } else if (log == null && !_isInitialized) {
        setState(() {
          _isInitialized = true;
        });
      }
    });

    final dailyPlan = ref.watch(dailyQuevaaPlanProvider);
    final cycleOutput = dailyPlan.cycleOutput;
    final readiness = dailyPlan.readiness;
    final currentRecipe = dailyPlan.mealForOffset(_activeMealIndex);

    final insights = ref.watch(quickInsightsProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgWarmDark : AppColors.bgWarmCream,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DashboardHeader(
                onNotificationsTap: () => context.push('/notifications'),
              ),
              const SizedBox(height: 20),

              // Rhythm Card
              _RhythmCard(output: cycleOutput)
                  .animate()
                  .fadeIn(duration: 450.ms)
                  .slideY(begin: 0.06, end: 0, curve: Curves.easeOutCubic),
              const SizedBox(height: 14),

              _ReadinessCard(
                readiness: readiness,
                onSeeWhy: () => _showReadinessDetails(context, dailyPlan),
              ).animate().fadeIn(duration: 450.ms),
              const SizedBox(height: 14),

              _QuickInputsCard(
                energy: _selectedEnergy,
                pain: _selectedPain,
                sleep: _selectedSleep,
                onEnergyChanged: (v) => _updateLog(energy: v),
                onPainChanged: (v) => _updateLog(pain: v),
                onSleepChanged: (v) => _updateLog(sleep: v),
              ),
              const SizedBox(height: 20),

              _TodayFocusCard(
                readiness: readiness,
                recommendation: dailyPlan.productivityRecommendation,
                task: dailyPlan.topFocusTask,
                reason: dailyPlan.topFocusReason,
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
                workout: dailyPlan.workout,
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

void _showReadinessDetails(BuildContext context, DailyQuevaaPlan plan) {
  final readiness = plan.readiness;
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  final accent = _readinessAccent(readiness.score, isDark);
  final confidenceText = switch (readiness.confidence) {
    ReadinessConfidence.personal => 'Personal pattern',
    ReadinessConfidence.current => 'Current check-in',
    ReadinessConfidence.low => 'Learning mode',
  };

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: isDark ? AppColors.cardSurfaceDark : Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) {
      return SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            20 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.borderDark
                        : AppColors.borderLight,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: isDark ? 0.18 : 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(_readinessIcon(readiness.score), color: accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Why ${readiness.label} today?',
                          style: theme.textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$confidenceText · score ${readiness.internalScore}/100',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(readiness.description, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 18),
              _FactorSection(
                title: 'Supporting your capacity',
                factors: readiness.supportingFactors,
                icon: Icons.check_circle_rounded,
                color: isDark ? AppColors.sageLight : AppColors.sagePrimary,
                emptyText: 'No strong supporting signals yet.',
              ),
              const SizedBox(height: 14),
              _FactorSection(
                title: 'Plan around this',
                factors: readiness.limitingFactors,
                icon: Icons.info_rounded,
                color: isDark
                    ? AppColors.terracottaLight
                    : AppColors.terracottaPrimary,
                emptyText: 'No major limiting signals in this check-in.',
              ),
              const SizedBox(height: 14),
              _DetailCallout(
                title: 'Pattern',
                body: readiness.historyInsight,
                icon: Icons.timeline_rounded,
                color: accent,
              ),
              const SizedBox(height: 12),
              _DetailCallout(
                title: 'Recommendation',
                body: readiness.primaryRecommendation,
                icon: Icons.route_rounded,
                color: accent,
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.go('/plan');
                  },
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text("Adjust Today's Plan"),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _FactorSection extends StatelessWidget {
  final String title;
  final List<ReadinessFactor> factors;
  final IconData icon;
  final Color color;
  final String emptyText;

  const _FactorSection({
    required this.title,
    required this.factors,
    required this.icon,
    required this.color,
    required this.emptyText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (factors.isEmpty)
          Text(emptyText, style: theme.textTheme.bodySmall)
        else
          ...factors.map(
            (factor) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: color, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: theme.textTheme.bodySmall,
                        children: [
                          TextSpan(
                            text: '${factor.label}: ',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          TextSpan(text: factor.detail),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _DetailCallout extends StatelessWidget {
  final String title;
  final String body;
  final IconData icon;
  final Color color;

  const _DetailCallout({
    required this.title,
    required this.body,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(body, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
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
    final name = profile?.userName ?? '';
    final greetingText = name.trim().isEmpty
        ? 'Hi there'
        : '${_getGreeting()}, $name';
    final todayText = DateFormat('EEEE, d MMMM').format(DateTime.now());

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
                  greetingText,
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
                const SizedBox(height: 6),
                Text(
                  todayText,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: secondaryText,
                    fontWeight: FontWeight.w600,
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
            child: NotificationBellButton(
              onPressed: onNotificationsTap,
              iconColor: isDark
                  ? AppColors.terracottaLight
                  : AppColors.terracottaPrimary,
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
    final String? durationText;

    if (!output.hasEnoughData) {
      periodText = 'Add your last period to unlock cycle predictions.';
      possibleStartText = null;
      durationText = null;
    } else if (primaryPred != null) {
      final bleedingStart = df.format(primaryPred.predictedBleedingRange.start);
      final possibleStart = df.format(primaryPred.possibleStartRange.start);
      final possibleEnd = df.format(primaryPred.possibleStartRange.end);
      periodText = 'Next period around $bleedingStart';
      durationText =
          'Typical duration ${primaryPred.expectedDurationDays} days';

      if (output.confidence == PredictionConfidence.low ||
          primaryPred.possibleStartRange.start !=
              primaryPred.estimatedStartDate) {
        possibleStartText = 'Possible start $possibleStart-$possibleEnd';
      } else {
        possibleStartText = null;
      }
    } else {
      periodText = 'Next period ${output.formattedPeriodRange}';
      possibleStartText = null;
      durationText = null;
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
            output.hasEnoughData
                ? output.estimatedPhase.toUpperCase()
                : 'CYCLE TRACKER',
            style: theme.textTheme.displayMedium?.copyWith(
              color: Colors.white,
              letterSpacing: 0,
            ),
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
                    if (durationText != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        durationText,
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
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'How are you today?',
                    style: theme.textTheme.headlineMedium,
                  ),
                ),
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.sagePrimary,
                  size: 18,
                ),
                const SizedBox(width: 4),
                Text('Logged', style: theme.textTheme.labelMedium),
              ],
            ),
            const SizedBox(height: 12),
            _RatingRow(
              label: 'Energy',
              selectedValue: energy,
              activeIcon: Icons.bolt_rounded,
              inactiveIcon: Icons.bolt_outlined,
              activeColor: AppColors.warmGold,
              valueLabels: _energyLabels,
              onChanged: onEnergyChanged,
            ),
            const SizedBox(height: 8),
            _RatingRow(
              label: 'Pain',
              selectedValue: pain + 1,
              activeIcon: Icons.circle_rounded,
              inactiveIcon: Icons.circle_outlined,
              activeColor: AppColors.terracottaPrimary,
              valueLabels: _painLabels,
              onChanged: (value) => onPainChanged(value - 1),
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
  final List<String> valueLabels;
  final ValueChanged<int> onChanged;

  const _RatingRow({
    required this.label,
    required this.selectedValue,
    required this.activeIcon,
    required this.inactiveIcon,
    required this.activeColor,
    required this.valueLabels,
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
        Flexible(
          child: Wrap(
            spacing: 2,
            runSpacing: 2,
            alignment: WrapAlignment.end,
            children: List.generate(5, (index) {
              final value = index + 1;
              final isSelected = value <= selectedValue;
              final valueLabel = valueLabels[index];

              return IconButton(
                constraints: const BoxConstraints.tightFor(
                  width: 36,
                  height: 36,
                ),
                padding: EdgeInsets.zero,
                iconSize: 22,
                tooltip: '$label: $valueLabel',
                icon: Icon(
                  isSelected ? activeIcon : inactiveIcon,
                  color: isSelected ? activeColor : Colors.grey,
                ),
                onPressed: () => onChanged(value),
              );
            }),
          ),
        ),
      ],
    );
  }
}

const _energyLabels = ['Very low', 'Low', 'Moderate', 'High', 'Very high'];

const _painLabels = ['None', 'Mild', 'Moderate', 'High', 'Severe'];

class _ReadinessCard extends StatelessWidget {
  final DailyReadinessResult readiness;
  final VoidCallback onSeeWhy;

  const _ReadinessCard({required this.readiness, required this.onSeeWhy});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = _readinessAccent(readiness.score, isDark);
    final chips = [
      readiness.suggestedPace,
      readiness.cycleContext,
      ...readiness.supportingFactors.take(1).map((factor) => factor.label),
      ...readiness.limitingFactors.take(1).map((factor) => factor.label),
    ];

    return Semantics(
      label:
          'Daily readiness: ${readiness.label}. ${readiness.description}. ${readiness.primaryRecommendation}',
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardSurfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: accent.withValues(alpha: 0.35), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: isDark ? 0.18 : 0.12),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: isDark ? 0.18 : 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(_readinessIcon(readiness.score), color: accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily Readiness',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        readiness.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          height: 1.12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: isDark ? 0.18 : 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    readiness.label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              readiness.description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: chips
                  .where((chip) => chip.trim().isNotEmpty)
                  .map((chip) => _SignalChip(label: chip, color: accent))
                  .toList(growable: false),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: isDark ? 0.12 : 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.route_rounded, color: accent, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      readiness.primaryRecommendation,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onSeeWhy,
                icon: const Icon(Icons.insights_rounded, size: 18),
                label: const Text('See why'),
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
  final String recommendation;
  final Task? task;
  final String reason;
  final VoidCallback onAdjustPlan;

  const _TodayFocusCard({
    required this.readiness,
    required this.recommendation,
    required this.task,
    required this.reason,
    required this.onAdjustPlan,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = _readinessAccent(readiness.score, isDark);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18.0),
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
                  child: const Text('Adjust'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              recommendation,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : AppColors.bgWarmCream,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.flag_rounded, color: accent, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          task?.title ?? 'Choose one meaningful task',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (task != null) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _SignalChip(
                          label: '${task!.estimatedDurationMinutes} min',
                          color: accent,
                        ),
                        _SignalChip(label: task!.priority, color: accent),
                        _SignalChip(
                          label: '${task!.recommendedEnergy} energy',
                          color: accent,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                  Text(
                    reason,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.self_improvement_rounded,
                        color: isDark
                            ? AppColors.sageLight
                            : AppColors.sagePrimary,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          readiness.bestFor,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              readiness.movementGuidance,
              style: theme.textTheme.bodySmall?.copyWith(
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

class _SignalChip extends StatelessWidget {
  final String label;
  final Color color;

  const _SignalChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.16 : 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          height: 1.15,
        ),
      ),
    );
  }
}

Color _readinessAccent(ReadinessScore score, bool isDark) {
  return switch (score) {
    ReadinessScore.restore =>
      isDark ? AppColors.terracottaLight : AppColors.terracottaPrimary,
    ReadinessScore.gentle => isDark ? AppColors.sageLight : AppColors.sageDark,
    ReadinessScore.steady => AppColors.warmGoldPrimary,
    ReadinessScore.focused => AppColors.waterBlue,
    ReadinessScore.strong =>
      isDark ? AppColors.purpleLight : AppColors.purplePrimary,
  };
}

IconData _readinessIcon(ReadinessScore score) {
  return switch (score) {
    ReadinessScore.restore => Icons.nights_stay_rounded,
    ReadinessScore.gentle => Icons.self_improvement_rounded,
    ReadinessScore.steady => Icons.spa_rounded,
    ReadinessScore.focused => Icons.psychology_rounded,
    ReadinessScore.strong => Icons.bolt_rounded,
  };
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
  final WorkoutEntity workout;
  final VoidCallback onSubstitute;

  const _MoveTodayCard({required this.workout, required this.onSubstitute});

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
            Text(workout.title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              '${workout.durationMinutes} min • ${workout.intensity} • ${workout.category}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
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
