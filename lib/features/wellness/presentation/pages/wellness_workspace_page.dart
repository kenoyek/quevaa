import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/quevaa_layout.dart';
import '../../../../app/theme/quevaa_spacing.dart';
import '../../../../core/database/app_database.dart';
import '../../../cycle/application/cycle_workspace_provider.dart';
import '../../../nutrition/data/nigerian_recipe_database.dart';
import '../../../recommendations/application/daily_quevaa_plan_provider.dart';
import '../../../workouts/data/workout_catalog.dart';
import '../../../workouts/domain/entities/workout_entity.dart';
import '../../application/wellness_workspace_provider.dart';

class WellnessWorkspacePage extends ConsumerWidget {
  final String? initialSection;

  const WellnessWorkspacePage({super.key, this.initialSection});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final section = ref.watch(wellnessSectionProvider);
    if (initialSection != null &&
        initialSection != section &&
        const [
          'For You',
          'Meals',
          'Movement',
          'Mind',
          'Progress',
        ].contains(initialSection)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          ref.read(wellnessSectionProvider.notifier).state = initialSection!;
        }
      });
    }
    final recommendation = ref.watch(wellnessRecommendationProvider);
    return Scaffold(
      backgroundColor: _pageBg(context),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.symmetric(vertical: QuevaaSpacing.m),
              sliver: SliverToBoxAdapter(
                child: _WellnessHeader(recommendation: recommendation),
              ),
            ),
            SliverToBoxAdapter(
              child: QuevaaSectionTabs(
                segments: const [
                  (
                    value: 'For You',
                    label: 'For You',
                    icon: Icons.auto_awesome_rounded,
                  ),
                  (
                    value: 'Meals',
                    label: 'Meals',
                    icon: Icons.restaurant_rounded,
                  ),
                  (
                    value: 'Movement',
                    label: 'Move',
                    icon: Icons.fitness_center_rounded,
                  ),
                  (value: 'Mind', label: 'Mind', icon: Icons.edit_note_rounded),
                  (
                    value: 'Progress',
                    label: 'Progress',
                    icon: Icons.insights_rounded,
                  ),
                ],
                selected: section,
                onSelectionChanged: (value) =>
                    ref.read(wellnessSectionProvider.notifier).state = value,
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              sliver: SliverToBoxAdapter(
                child: switch (section) {
                  'Meals' => const _MealsWorkspace(),
                  'Movement' => _MovementWorkspace(
                    workout: recommendation.workout,
                  ),
                  'Mind' => _MindWorkspace(
                    prompt: recommendation.journalPrompt,
                  ),
                  'Progress' => const _ProgressWorkspace(),
                  _ => _ForYouWorkspace(recommendation: recommendation),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WellnessHeader extends StatelessWidget {
  final WellnessRecommendation recommendation;

  const _WellnessHeader({required this.recommendation});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: QuevaaSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Wellness', style: theme.textTheme.displaySmall),
          const SizedBox(height: QuevaaSpacing.m),
          Text(
            'Today’s focus',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.terracottaPrimary,
            ),
          ),
          Text(recommendation.focus, style: theme.textTheme.headlineMedium),
          const SizedBox(height: QuevaaSpacing.xxs),
          Text(
            recommendation.reason,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark ? Colors.white60 : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }
}

class _ForYouWorkspace extends ConsumerWidget {
  final WellnessRecommendation recommendation;

  const _ForYouWorkspace({required this.recommendation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        _MealRecommendationCard(recipe: recommendation.meal),
        const SizedBox(height: 12),
        _WorkoutCard(workout: recommendation.workout),
        const SizedBox(height: 12),
        _HydrationCard(target: recommendation.hydrationTarget),
        const SizedBox(height: 12),
        _JournalPrompt(prompt: recommendation.journalPrompt),
      ],
    );
  }
}

class _MealsWorkspace extends ConsumerWidget {
  const _MealsWorkspace();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mealsSection = ref.watch(mealsSectionProvider);
    final dailyPlan = ref.watch(dailyQuevaaPlanProvider);
    final savedIds =
        ref
            .watch(savedMealsStreamProvider)
            .valueOrNull
            ?.map((row) => row.mealId)
            .toSet() ??
        const <String>{};
    final preparedEntries =
        ref.watch(mealPreparationHistoryProvider).valueOrNull ?? const [];
    final today = ref.watch(localTodayProvider);
    final preparedTodayIds = preparedEntries
        .where(
          (entry) =>
              entry.date == today &&
              entry.mealType.isNotEmpty &&
              entry.deletedAt == null,
        )
        .map((entry) => '${entry.mealId}:${entry.mealType}')
        .toSet();
    final pantry = ref.watch(pantryStreamProvider).valueOrNull ?? const [];
    final shopping = ref.watch(shoppingStreamProvider).valueOrNull ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        QuevaaSectionTabs(
          segments: const [
            (value: 'Today', label: 'Today', icon: Icons.today_rounded),
            (
              value: 'Planner',
              label: 'Planner',
              icon: Icons.calendar_month_rounded,
            ),
            (value: 'Pantry', label: 'Pantry', icon: Icons.inventory_2_rounded),
            (
              value: 'Shopping',
              label: 'Shopping',
              icon: Icons.shopping_bag_rounded,
            ),
            (value: 'Saved', label: 'Saved', icon: Icons.favorite_rounded),
            (value: 'History', label: 'History', icon: Icons.history_rounded),
          ],
          selected: mealsSection,
          onSelectionChanged: (value) =>
              ref.read(mealsSectionProvider.notifier).state = value,
        ),
        const SizedBox(height: 12),
        switch (mealsSection) {
          'Planner' => const _MealPlannerPanel(),
          'Pantry' => _PantryPanel(items: pantry, expanded: true),
          'Shopping' => _ShoppingPanel(items: shopping, expanded: true),
          'Saved' => _SavedMealsPanel(savedIds: savedIds),
          'History' => _MealHistoryPanel(entries: preparedEntries),
          _ => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Today’s meals',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 4),
              Text(
                [
                  if (dailyPlan.cycleSnapshot.cycleDay != null)
                    'Cycle Day ${dailyPlan.cycleSnapshot.cycleDay}',
                  dailyPlan.cycleOutput.estimatedPhase,
                ].join(' • '),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'Family meals prioritize household safety, pantry fit, servings, prep time and recent rotation. Your cycle context remains a light personal ranking signal.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              for (final mealType in const [
                'Breakfast',
                'Lunch',
                'Dinner',
                'Snack',
              ])
                if (dailyPlan.meals[mealType] case final recipe?)
                  _MealRecommendationCard(
                    recipe: recipe,
                    compactTitle: mealType == 'Snack'
                        ? 'Optional snack'
                        : mealType,
                    whySuggested:
                        '${recipe.whySuggested(dailyPlan.cycleOutput.estimatedPhase)} For shared meals, Quevaa keeps household safety and preferences first.',
                    isSaved: savedIds.contains(recipe.id),
                    isPrepared: preparedTodayIds.contains(
                      '${recipe.id}:${recipe.mealType}',
                    ),
                  ),
              const SizedBox(height: 12),
              _RecipeSearchPanel(),
            ],
          ),
        },
      ],
    );
  }
}

class _MealPlannerPanel extends ConsumerWidget {
  const _MealPlannerPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(plannerModeProvider);
    final week = ref.watch(weeklyFamilyMealPlanProvider);
    final month = ref.watch(monthlyFamilyMealPlanProvider);
    final profile =
        ref.watch(householdProfileStreamProvider).valueOrNull ??
        const HouseholdProfileModelBridge();
    final storedPlans = ref.watch(mealPlanStreamProvider).valueOrNull ?? [];
    final formatter = DateFormat.MMMd();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HouseholdProfileCard(profile: profile),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: _panelDecoration(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Meal planner',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'Week', label: Text('Week')),
                      ButtonSegment(value: 'Month', label: Text('Month')),
                    ],
                    selected: {mode},
                    onSelectionChanged: (value) =>
                        ref.read(plannerModeProvider.notifier).state =
                            value.single,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                mode == 'Week'
                    ? '${formatter.format(week.weekStart)}-${formatter.format(week.weekStart.add(const Duration(days: 6)))}'
                    : DateFormat.yMMMM().format(month.monthStart),
              ),
              const SizedBox(height: 12),
              if (mode == 'Week') ...[
                _WeeklyPlanStats(
                  summary: week,
                  storedCount: storedPlans.length,
                ),
                const SizedBox(height: 12),
                for (var day = 0; day < 7; day++)
                  _PlannerDayRows(
                    date: week.weekStart.add(Duration(days: day)),
                    slots: week.slots
                        .where(
                          (slot) =>
                              normalizeDate(slot.date) ==
                              normalizeDate(
                                week.weekStart.add(Duration(days: day)),
                              ),
                        )
                        .toList(growable: false),
                  ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      onPressed: () async {
                        await ref
                            .read(wellnessWorkspaceControllerProvider.notifier)
                            .applyGeneratedWeek();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Weekly family plan saved.'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.auto_awesome_rounded),
                      label: const Text('Generate Week'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await ref
                            .read(wellnessWorkspaceControllerProvider.notifier)
                            .generateShoppingListFromWeek(week.weekStart);
                        if (context.mounted) {
                          ref.read(mealsSectionProvider.notifier).state =
                              'Shopping';
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Shopping list generated from this week.',
                              ),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.shopping_bag_rounded),
                      label: const Text('Shopping List'),
                    ),
                  ],
                ),
              ] else ...[
                Text(
                  '${month.plannedMeals} planned meals across ${month.weeks.length} rotating weeks.',
                ),
                const SizedBox(height: 8),
                for (final weekSummary in month.weeks)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_view_week_rounded),
                    title: Text(
                      'Week of ${formatter.format(weekSummary.weekStart)}',
                    ),
                    subtitle: Text(
                      '${weekSummary.plannedMeals} meals • ${weekSummary.uniqueRecipeCount} unique recipes • ${weekSummary.pantryFirstMeals} pantry-first',
                    ),
                  ),
                const Divider(),
                Text(
                  'Monthly staples',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                if (month.monthlyStaples.isEmpty)
                  const Text('Staple shopping appears after pantry gaps exist.')
                else
                  for (final item in month.monthlyStaples.take(8))
                    _LineItem(
                      icon: Icons.inventory_rounded,
                      text:
                          '${item.displayName} — ${item.quantityLabel} ${item.unit}',
                    ),
                const SizedBox(height: 8),
                Text(
                  'Fresh items stay grouped by week instead of becoming one large monthly produce list.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class HouseholdProfileModelBridge {
  const HouseholdProfileModelBridge();

  String get householdName => '';
  int get adults => 1;
  int get children => 0;
  int get effectiveServings => 2;
  List<String> get allergens => const [];
  List<String> get dietaryPreferences => const [];
  int get weekdayPrepLimitMinutes => 45;
  int get weekendPrepLimitMinutes => 90;
}

class _HouseholdProfileCard extends ConsumerWidget {
  final dynamic profile;

  const _HouseholdProfileCard({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  profile.householdName.toString().isEmpty
                      ? 'Household profile'
                      : profile.householdName.toString(),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: 'Edit household',
                onPressed: () => _showHouseholdSheet(context, ref, profile),
                icon: const Icon(Icons.edit_rounded),
              ),
            ],
          ),
          Text(
            '${profile.adults} adult(s), ${profile.children} child(ren) • ${profile.effectiveServings} default servings',
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _MetadataChip(
                label: '${profile.weekdayPrepLimitMinutes} min weekdays',
              ),
              _MetadataChip(
                label: '${profile.weekendPrepLimitMinutes} min weekends',
              ),
              if (profile.allergens.isNotEmpty)
                _MetadataChip(label: 'Avoids ${profile.allergens.join(', ')}'),
              if (profile.dietaryPreferences.isNotEmpty)
                _MetadataChip(
                  label: profile.dietaryPreferences.take(2).join(', '),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeeklyPlanStats extends StatelessWidget {
  final dynamic summary;
  final int storedCount;

  const _WeeklyPlanStats({required this.summary, required this.storedCount});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _MetadataChip(label: '${summary.plannedMeals} meals'),
        _MetadataChip(label: '${summary.uniqueRecipeCount} unique recipes'),
        _MetadataChip(label: '${summary.pantryFirstMeals} pantry-first'),
        _MetadataChip(label: '${summary.expiringIngredientMeals} use-soon'),
        _MetadataChip(label: '$storedCount saved locally'),
      ],
    );
  }
}

class _PlannerDayRows extends StatelessWidget {
  final DateTime date;
  final List<dynamic> slots;

  const _PlannerDayRows({required this.date, required this.slots});

  @override
  Widget build(BuildContext context) {
    final day = DateFormat.E().format(date).toUpperCase();
    final dateLabel = DateFormat.MMMd().format(date);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$day  $dateLabel',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          for (final slot in slots)
            Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white10
                    : AppColors.bgWarmCream,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  SizedBox(width: 72, child: Text(slot.mealType)),
                  Expanded(child: Text(slot.recipe.title)),
                  Text('${slot.servings}p'),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MovementWorkspace extends ConsumerWidget {
  final WorkoutEntity workout;

  const _MovementWorkspace({required this.workout});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions =
        ref.watch(workoutSessionStreamProvider).valueOrNull ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _WorkoutCard(workout: workout, expanded: true),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: _panelDecoration(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Workout history',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              if (sessions.isEmpty)
                const Text('Your completed movement sessions will appear here.')
              else
                for (final session in sessions.take(10))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.sagePrimary,
                    ),
                    title: Text('Workout #${session.workoutPlanId}'),
                    subtitle: Text(
                      '${DateFormat.MMMd().add_jm().format(session.completedAt)} • Exertion ${session.perceivedExertion}/10',
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MindWorkspace extends ConsumerWidget {
  final String prompt;

  const _MindWorkspace({required this.prompt});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final journalStream = ref.watch(journalStreamProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _JournalPrompt(prompt: prompt),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Your reflections',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            FilledButton.icon(
              onPressed: () => _showJournalSheet(context, ref),
              icon: const Icon(Icons.add_rounded),
              label: const Text('New Entry'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        journalStream.when(
          data: (entries) {
            if (entries.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: _panelDecoration(context),
                child: Column(
                  children: [
                    const Icon(
                      Icons.edit_note_rounded,
                      size: 48,
                      color: AppColors.purplePrimary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No private reflections saved yet',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Tap "New Entry" or pick today\'s prompt above to write a private reflection.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }
            return Column(
              children: [
                for (final entry in entries) _JournalEntryTile(entry: entry),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => const Text('Could not load journal entries.'),
        ),
      ],
    );
  }
}

class _JournalEntryTile extends ConsumerWidget {
  final JournalEntry entry;

  const _JournalEntryTile({required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateStr = DateFormat.yMMMd().add_jm().format(entry.createdAt);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    entry.title?.isNotEmpty == true
                        ? entry.title!
                        : 'Private Reflection',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (entry.mood != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.cycleLutealDark
                          : AppColors.purpleContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      entry.mood!,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: isDark
                            ? AppColors.purpleLight
                            : AppColors.purpleDark,
                      ),
                    ),
                  ),
                PopupMenuButton<String>(
                  onSelected: (val) async {
                    if (val == 'edit') {
                      _showJournalSheet(context, ref, entry: entry);
                    } else if (val == 'delete') {
                      await ref
                          .read(wellnessWorkspaceControllerProvider.notifier)
                          .deleteJournalEntry(entry.id);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              entry.encryptedContent,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              dateStr,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
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

class _ProgressWorkspace extends ConsumerWidget {
  const _ProgressWorkspace();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final log = ref.watch(todaysWellnessLogProvider).valueOrNull;
    final sessions =
        ref.watch(workoutSessionStreamProvider).valueOrNull ?? const [];
    final plans = ref.watch(mealPlanStreamProvider).valueOrNull ?? const [];
    final journalCount = ref.watch(journalEntryCountProvider).valueOrNull ?? 0;
    return Column(
      children: [
        _ProgressTile(
          title: 'Water consistency',
          value: '${log?.waterGlasses ?? 0}/8 glasses today',
        ),
        _ProgressTile(
          title: 'Workout completion',
          value: '${sessions.length} movement sessions logged',
        ),
        _ProgressTile(
          title: 'Meal-plan usage',
          value: '${plans.length} meals planned for the next 7 days',
        ),
        _ProgressTile(
          title: 'Journal consistency',
          value: '$journalCount private reflections saved',
        ),
      ],
    );
  }
}

class _MealRecommendationCard extends ConsumerWidget {
  final NigerianRecipe recipe;
  final String? compactTitle;
  final String? whySuggested;
  final bool isSaved;
  final bool isPrepared;

  const _MealRecommendationCard({
    required this.recipe,
    this.compactTitle,
    this.whySuggested,
    this.isSaved = false,
    this.isPrepared = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: QuevaaSpacing.m),
      padding: const EdgeInsets.all(QuevaaSpacing.m),
      decoration: _panelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.terracottaContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(QuevaaSpacing.s),
                ),
                child: const Icon(
                  Icons.restaurant_rounded,
                  color: AppColors.terracottaPrimary,
                ),
              ),
              const SizedBox(width: QuevaaSpacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      compactTitle ?? 'Recommended meal',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: AppColors.terracottaPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(recipe.title, style: theme.textTheme.titleLarge),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: QuevaaSpacing.s),
          Wrap(
            spacing: QuevaaSpacing.xs,
            runSpacing: QuevaaSpacing.xxs,
            children: [
              _MetadataChip(label: recipe.mealType),
              _MetadataChip(label: recipe.region),
              _MetadataChip(label: '${recipe.totalMinutes} min'),
              _MetadataChip(label: recipe.difficulty),
              _MetadataChip(label: recipe.budgetLevel),
            ],
          ),
          const SizedBox(height: QuevaaSpacing.s),
          Text(
            recipe.description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark ? Colors.white70 : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: QuevaaSpacing.s),
          Text(
            whySuggested ?? 'Nutrients: ${recipe.keyNutrients}',
            style: theme.textTheme.bodySmall?.copyWith(
              fontStyle: FontStyle.italic,
              color: AppColors.sagePrimary,
            ),
          ),
          const SizedBox(height: QuevaaSpacing.m),
          Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: isPrepared
                      ? null
                      : () => _confirmPrepared(context, ref, recipe),
                  icon: Icon(
                    isPrepared
                        ? Icons.check_circle_rounded
                        : Icons.check_rounded,
                  ),
                  label: Text(isPrepared ? 'Prepared Today' : 'Mark Prepared'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.terracottaPrimary,
                  ),
                ),
              ),
              const SizedBox(height: QuevaaSpacing.xs),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await ref
                            .read(wellnessWorkspaceControllerProvider.notifier)
                            .toggleSavedMeal(recipe);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isSaved
                                    ? 'Removed from saved meals.'
                                    : 'Saved meal.',
                              ),
                            ),
                          );
                        }
                      },
                      icon: Icon(
                        isSaved
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        size: 18,
                      ),
                      label: Text(isSaved ? 'Saved' : 'Save'),
                    ),
                  ),
                  const SizedBox(width: QuevaaSpacing.xs),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showMealDetailSheet(
                        context,
                        ref,
                        recipe,
                        initialTab: 0,
                      ),
                      icon: const Icon(Icons.menu_book_rounded, size: 18),
                      label: const Text('View Recipe'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: QuevaaSpacing.xs),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showMealDetailSheet(
                        context,
                        ref,
                        recipe,
                        initialTab: 1,
                      ),
                      icon: const Icon(
                        Icons.format_list_bulleted_rounded,
                        size: 18,
                      ),
                      label: const Text('Ingredients'),
                    ),
                  ),
                  const SizedBox(width: QuevaaSpacing.xs),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => ref
                          .read(wellnessWorkspaceControllerProvider.notifier)
                          .showAnotherMeal(recipe.mealType),
                      icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                      label: const Text('Another'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetadataChip extends StatelessWidget {
  final String label;

  const _MetadataChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: QuevaaSpacing.xs,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : AppColors.bgWarmCream,
        borderRadius: BorderRadius.circular(QuevaaSpacing.xxs),
        border: Border.all(
          color: isDark ? Colors.white24 : AppColors.borderLight,
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

Future<void> _confirmPrepared(
  BuildContext context,
  WidgetRef ref,
  NigerianRecipe recipe,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Mark this meal as prepared?'),
      content: Text(
        'Quevaa will add ${recipe.title} to your meal history for today.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Mark Prepared'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  await ref
      .read(wellnessWorkspaceControllerProvider.notifier)
      .markMealPrepared(recipe);
  if (context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Meal marked as prepared.')));
  }
}

void _showMealDetailSheet(
  BuildContext context,
  WidgetRef ref,
  NigerianRecipe recipe, {
  int initialTab = 0,
}) {
  var servings = recipe.servings;
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        final scale = servings / recipe.servings;
        return DefaultTabController(
          length: 3,
          initialIndex: initialTab,
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                0,
                20,
                20 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.82,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppColors.terracottaContainer.withValues(
                              alpha: 0.35,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.restaurant_menu_rounded),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                recipe.title,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                recipe.description,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _MetadataChip(label: recipe.mealType),
                        _MetadataChip(label: '${recipe.totalMinutes} min'),
                        _MetadataChip(label: '$servings servings'),
                        _MetadataChip(label: recipe.targetPhase),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Why Quevaa suggested this',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(recipe.whySuggested(recipe.targetPhase)),
                    const SizedBox(height: 12),
                    const TabBar(
                      tabs: [
                        Tab(text: 'Recipe'),
                        Tab(text: 'Ingredients'),
                        Tab(text: 'Notes'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          ListView(
                            children: [
                              const SizedBox(height: 12),
                              for (final step in recipe.instructions)
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: CircleAvatar(
                                    child: Text(step.stepNumber.toString()),
                                  ),
                                  title: Text(step.title),
                                  subtitle: Text(
                                    '${step.instruction}\nAbout ${step.estimatedMinutes} min',
                                  ),
                                ),
                            ],
                          ),
                          ListView(
                            children: [
                              const SizedBox(height: 12),
                              SegmentedButton<int>(
                                segments: const [
                                  ButtonSegment(value: 1, label: Text('1')),
                                  ButtonSegment(value: 2, label: Text('2')),
                                  ButtonSegment(value: 4, label: Text('4')),
                                  ButtonSegment(value: 6, label: Text('6')),
                                ],
                                selected: {servings},
                                onSelectionChanged: (value) =>
                                    setState(() => servings = value.single),
                              ),
                              const SizedBox(height: 12),
                              for (final ingredient in recipe.ingredients)
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(
                                    Icons.check_circle_outline_rounded,
                                  ),
                                  title: Text(ingredient.format(scale: scale)),
                                  subtitle: Text(ingredient.category),
                                ),
                              const SizedBox(height: 12),
                              FilledButton.icon(
                                onPressed: () async {
                                  await ref
                                      .read(
                                        wellnessWorkspaceControllerProvider
                                            .notifier,
                                      )
                                      .addRecipeToShoppingList(recipe);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Ingredients added to shopping list.',
                                        ),
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.shopping_bag_rounded),
                                label: const Text(
                                  'Add Ingredients to Shopping List',
                                ),
                              ),
                            ],
                          ),
                          ListView(
                            children: [
                              const SizedBox(height: 12),
                              Text(
                                'Substitutions',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              for (final item in recipe.substitutions)
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(Icons.swap_horiz_rounded),
                                  title: Text(item),
                                ),
                              const SizedBox(height: 12),
                              Text(
                                'Serving suggestions',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              for (final item in recipe.servingSuggestions)
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(
                                    Icons.room_service_rounded,
                                  ),
                                  title: Text(item),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _WorkoutCard extends ConsumerWidget {
  final WorkoutEntity workout;
  final bool expanded;

  const _WorkoutCard({required this.workout, this.expanded = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(QuevaaSpacing.m),
      decoration: _panelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Today’s movement',
            style: theme.textTheme.labelLarge?.copyWith(
              color: AppColors.sagePrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: QuevaaSpacing.xxs),
          Text(workout.title, style: theme.textTheme.titleLarge),
          const SizedBox(height: QuevaaSpacing.xs),
          Wrap(
            spacing: QuevaaSpacing.xs,
            runSpacing: QuevaaSpacing.xxs,
            children: [
              _MetadataChip(label: '${workout.durationMinutes} min'),
              _MetadataChip(label: workout.intensity),
              _MetadataChip(label: workout.equipmentRequired.join(', ')),
            ],
          ),
          const SizedBox(height: QuevaaSpacing.s),
          Text(
            'Suggested as a movement option based on today’s logged energy, pain, sleep, and recent activity.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark ? Colors.white60 : AppColors.textSecondaryLight,
            ),
          ),
          if (expanded) ...[
            const SizedBox(height: QuevaaSpacing.m),
            Text(
              'Preparation',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: QuevaaSpacing.xxs),
            const Text(
              WorkoutEntity.preWorkoutSafetyPrompt,
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: QuevaaSpacing.s),
            for (final exercise in [
              ...workout.warmup,
              ...workout.mainExercises,
              ...workout.cooldown,
            ])
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: const Icon(
                  Icons.play_circle_outline_rounded,
                  size: 20,
                  color: AppColors.sagePrimary,
                ),
                title: Text(exercise.name),
                subtitle: Text(
                  '${exercise.durationOrReps}. ${exercise.modification}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
          ],
          const SizedBox(height: QuevaaSpacing.m),
          Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => ref
                      .read(wellnessWorkspaceControllerProvider.notifier)
                      .completeWorkout(workout),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Start Workout'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.sagePrimary,
                  ),
                ),
              ),
              const SizedBox(height: QuevaaSpacing.xs),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showWorkoutAlternatives(context, ref),
                      icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                      label: const Text('Replace'),
                    ),
                  ),
                  const SizedBox(width: QuevaaSpacing.xs),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await ref
                            .read(wellnessWorkspaceControllerProvider.notifier)
                            .markRestDay();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Rest day saved.')),
                          );
                        }
                      },
                      icon: const Icon(
                        Icons.self_improvement_rounded,
                        size: 18,
                      ),
                      label: const Text('Rest Day'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HydrationCard extends ConsumerWidget {
  final int target;

  const _HydrationCard({required this.target});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final log = ref.watch(todaysWellnessLogProvider).valueOrNull;
    final current = log?.waterGlasses ?? 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Hydration', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: (current / target).clamp(0, 1)),
          const SizedBox(height: 8),
          Text('$current of $target glasses logged today'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              for (final glasses in [4, 6, 8, 10])
                FilledButton.tonal(
                  onPressed: () => ref
                      .read(wellnessWorkspaceControllerProvider.notifier)
                      .logWater(glasses),
                  child: Text('$glasses'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _JournalPrompt extends ConsumerWidget {
  final String prompt;

  const _JournalPrompt({required this.prompt});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Daily reflection prompt',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(prompt),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: () =>
                    _showJournalSheet(context, ref, initialContent: prompt),
                icon: const Icon(Icons.edit_note_rounded),
                label: const Text('Write Reflection'),
              ),
              OutlinedButton.icon(
                onPressed: () => ref
                    .read(wellnessWorkspaceControllerProvider.notifier)
                    .addJournalPrompt(prompt),
                icon: const Icon(Icons.bookmark_add_rounded),
                label: const Text('Save Prompt'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

void _showJournalSheet(
  BuildContext context,
  WidgetRef ref, {
  JournalEntry? entry,
  String? initialContent,
}) {
  final titleController = TextEditingController(text: entry?.title ?? '');
  final contentController = TextEditingController(
    text: entry?.encryptedContent ?? initialContent ?? '',
  );
  var mood = entry?.mood ?? 'Calm';

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            0,
            20,
            20 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  entry == null ? 'New journal entry' : 'Edit journal entry',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title (optional)',
                    hintText: 'e.g. Quiet moment, Evening reflection',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: mood,
                  decoration: const InputDecoration(labelText: 'Mood'),
                  items:
                      const [
                            'Calm',
                            'Reflective',
                            'Grateful',
                            'Hopeful',
                            'Anxious',
                            'Tired',
                            'Energized',
                          ]
                          .map(
                            (m) => DropdownMenuItem(value: m, child: Text(m)),
                          )
                          .toList(),
                  onChanged: (val) => setState(() => mood = val ?? mood),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contentController,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Reflection notes',
                    hintText: 'Write your private thoughts...',
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () async {
                      if (contentController.text.trim().isEmpty) return;
                      await ref
                          .read(wellnessWorkspaceControllerProvider.notifier)
                          .saveJournalEntry(
                            id: entry?.id,
                            title: titleController.text,
                            content: contentController.text,
                            mood: mood,
                          );
                      if (context.mounted) Navigator.pop(context);
                    },
                    icon: const Icon(Icons.check_rounded),
                    label: Text(entry == null ? 'Save Entry' : 'Update Entry'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ).whenComplete(() {
    titleController.dispose();
    contentController.dispose();
  });
}

class _SavedMealsPanel extends ConsumerWidget {
  final Set<String> savedIds;

  const _SavedMealsPanel({required this.savedIds});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedRecipes = NigerianRecipeDatabase.recipes
        .where((recipe) => savedIds.contains(recipe.id))
        .toList(growable: false);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Saved meals', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (savedRecipes.isEmpty)
            const Text(
              'No saved meals yet. Save recipes you would like to make again.',
            )
          else
            for (final recipe in savedRecipes)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.favorite_rounded),
                title: Text(recipe.title),
                subtitle: Text(
                  '${recipe.mealType} • ${recipe.totalMinutes} min',
                ),
                onTap: () => _showMealDetailSheet(context, ref, recipe),
                trailing: IconButton(
                  tooltip: 'Unsave',
                  onPressed: () => ref
                      .read(wellnessWorkspaceControllerProvider.notifier)
                      .toggleSavedMeal(recipe),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ),
        ],
      ),
    );
  }
}

class _MealHistoryPanel extends StatelessWidget {
  final List<MealPreparationEntry> entries;

  const _MealHistoryPanel({required this.entries});

  @override
  Widget build(BuildContext context) {
    final active = entries.take(14).toList(growable: false);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Meal history', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (active.isEmpty)
            const Text('Prepared meals will appear here after you mark them.')
          else
            for (final entry in active)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.check_circle_rounded),
                title: Text(_titleForMealId(entry.mealId)),
                subtitle: Text(
                  '${entry.mealType} • ${DateFormat.yMMMd().format(entry.date)}',
                ),
              ),
        ],
      ),
    );
  }
}

class _RecipeSearchPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final recipes = NigerianRecipeDatabase.recipes;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Recipes', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          for (final recipe in recipes.take(5))
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.menu_book_rounded),
              title: Text(recipe.title),
              subtitle: Text(
                '${recipe.mealType} • ${recipe.targetPhase} • ${recipe.keyNutrients}',
              ),
            ),
        ],
      ),
    );
  }
}

String _titleForMealId(String mealId) {
  return NigerianRecipeDatabase.recipes
      .firstWhere(
        (recipe) => recipe.id == mealId,
        orElse: () => NigerianRecipeDatabase.recipes.first,
      )
      .title;
}

class _PantryPanel extends ConsumerWidget {
  final List<PantryItem> items;
  final bool expanded;

  const _PantryPanel({required this.items, this.expanded = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Pantry',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                onPressed: () => _showPantrySheet(context, ref),
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          if (expanded) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetadataChip(label: '${items.length} items'),
                _MetadataChip(
                  label:
                      '${items.where((item) => item.lowStock).length} low stock',
                ),
                _MetadataChip(
                  label:
                      '${items.where((item) => _expiryStatus(item.expiryDate) == 'Use soon').length} use soon',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final ingredient in const [
                  'Rice',
                  'Eggs',
                  'Tomatoes',
                  'Onions',
                  'Beans',
                  'Yam',
                  'Plantain',
                  'Chicken',
                  'Fish',
                  'Oil',
                ])
                  ActionChip(
                    avatar: const Icon(Icons.add_rounded, size: 18),
                    label: Text(ingredient),
                    onPressed: () => ref
                        .read(wellnessWorkspaceControllerProvider.notifier)
                        .addPantryItem(name: ingredient),
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          if (items.isEmpty)
            const Text('Pantry ingredients can improve local meal suggestions.')
          else
            for (final item in items)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  item.lowStock
                      ? Icons.warning_amber_rounded
                      : Icons.inventory_2_rounded,
                ),
                title: Text(item.name),
                subtitle: Text(
                  [
                    '${_formatQuantity(item.quantity)} ${item.unit}',
                    item.category,
                    _expiryStatus(item.expiryDate),
                    if (item.lowStock) 'Low stock',
                    item.storageLocation,
                  ].where((value) => value.isNotEmpty).join(' • '),
                ),
                trailing: expanded
                    ? Wrap(
                        spacing: 4,
                        children: [
                          IconButton(
                            tooltip: 'Decrease',
                            onPressed: () => ref
                                .read(
                                  wellnessWorkspaceControllerProvider.notifier,
                                )
                                .adjustPantryItem(item, -1),
                            icon: const Icon(Icons.remove_rounded),
                          ),
                          IconButton(
                            tooltip: 'Increase',
                            onPressed: () => ref
                                .read(
                                  wellnessWorkspaceControllerProvider.notifier,
                                )
                                .adjustPantryItem(item, 1),
                            icon: const Icon(Icons.add_rounded),
                          ),
                        ],
                      )
                    : null,
              ),
        ],
      ),
    );
  }
}

class _ShoppingPanel extends ConsumerWidget {
  final List<ShoppingItem> items;
  final bool expanded;

  const _ShoppingPanel({required this.items, this.expanded = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Shopping list',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (items.any((item) => item.isPurchased))
                TextButton(
                  onPressed: () => ref
                      .read(wellnessWorkspaceControllerProvider.notifier)
                      .clearCompletedShoppingItems(),
                  child: const Text('Clear done'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (expanded) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetadataChip(label: '${items.length} items'),
                _MetadataChip(
                  label:
                      '${items.where((item) => !item.isPurchased).length} remaining',
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final week = ref.read(plannerWeekStartProvider);
                    await ref
                        .read(wellnessWorkspaceControllerProvider.notifier)
                        .generateShoppingListFromWeek(week);
                  },
                  icon: const Icon(Icons.calendar_view_week_rounded),
                  label: const Text('Generate From Week'),
                ),
                FilledButton.icon(
                  onPressed: items.any((item) => item.isPurchased)
                      ? () => ref
                            .read(wellnessWorkspaceControllerProvider.notifier)
                            .finishShoppingTrip()
                      : null,
                  icon: const Icon(Icons.inventory_2_rounded),
                  label: const Text('Finish Shopping'),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          if (items.isEmpty)
            const Text('Add ingredients from a meal or enter pantry needs.')
          else
            for (final category in _shoppingCategories(items))
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(category, style: Theme.of(context).textTheme.titleSmall),
                  for (final item in items.where(
                    (item) => item.category == category,
                  ))
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: item.isPurchased,
                      onChanged: (_) => ref
                          .read(wellnessWorkspaceControllerProvider.notifier)
                          .toggleShoppingItem(item),
                      title: Text(
                        [
                          item.itemName,
                          if (item.quantity != null && item.unit != null)
                            '${item.quantity} ${item.unit}',
                        ].join(' — '),
                      ),
                      subtitle: item.sourceMealTitle == null
                          ? null
                          : Text('From ${item.sourceMealTitle}'),
                      secondary: IconButton(
                        tooltip: 'Remove',
                        onPressed: () => ref
                            .read(wellnessWorkspaceControllerProvider.notifier)
                            .removeShoppingItem(item),
                        icon: const Icon(Icons.delete_outline_rounded),
                      ),
                    ),
                ],
              ),
        ],
      ),
    );
  }
}

class _LineItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _LineItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.sagePrimary),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _ProgressTile extends StatelessWidget {
  final String title;
  final String value;

  const _ProgressTile({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(context),
      child: Row(
        children: [
          const Icon(Icons.insights_rounded, color: AppColors.sagePrimary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                Text(value),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

void _showHouseholdSheet(BuildContext context, WidgetRef ref, dynamic profile) {
  final name = TextEditingController(text: profile.householdName.toString());
  final adults = TextEditingController(text: profile.adults.toString());
  final children = TextEditingController(text: profile.children.toString());
  final servings = TextEditingController(
    text: profile.effectiveServings.toString(),
  );
  final allergens = TextEditingController(
    text: (profile.allergens as List).join(', '),
  );
  final prefs = TextEditingController(
    text: (profile.dietaryPreferences as List).join(', '),
  );
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Household profile',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: name,
                decoration: const InputDecoration(
                  labelText: 'Household name (optional)',
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: adults,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Adults'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: children,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Children'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: servings,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Default meal servings',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: allergens,
                decoration: const InputDecoration(
                  labelText: 'Allergens to exclude',
                  hintText: 'peanut, fish, egg',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: prefs,
                decoration: const InputDecoration(
                  labelText: 'Dietary preferences',
                  hintText: 'Vegetarian, No fish',
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    await ref
                        .read(wellnessWorkspaceControllerProvider.notifier)
                        .saveHouseholdProfile(
                          householdName: name.text,
                          adults: int.tryParse(adults.text) ?? 1,
                          children: int.tryParse(children.text) ?? 0,
                          defaultServings: int.tryParse(servings.text),
                          allergens: _csv(allergens.text),
                          dietaryPreferences: _csv(prefs.text),
                        );
                    if (context.mounted) Navigator.pop(context);
                  },
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Save household'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  ).whenComplete(() {
    name.dispose();
    adults.dispose();
    children.dispose();
    servings.dispose();
    allergens.dispose();
    prefs.dispose();
  });
}

void _showPantrySheet(BuildContext context, WidgetRef ref) {
  final name = TextEditingController();
  final quantity = TextEditingController(text: '1');
  var unit = 'pieces';
  var storage = 'Pantry';
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            0,
            20,
            20 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Ingredient'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: quantity,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Quantity'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: unit,
                      decoration: const InputDecoration(labelText: 'Unit'),
                      items:
                          const [
                                'g',
                                'kg',
                                'ml',
                                'L',
                                'cup',
                                'tbsp',
                                'tsp',
                                'pieces',
                                'bunch',
                                'pack',
                                'can',
                                'bag',
                              ]
                              .map(
                                (item) => DropdownMenuItem(
                                  value: item,
                                  child: Text(item),
                                ),
                              )
                              .toList(),
                      onChanged: (value) =>
                          setState(() => unit = value ?? unit),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: storage,
                decoration: const InputDecoration(labelText: 'Storage'),
                items: const ['Pantry', 'Fridge', 'Freezer']
                    .map(
                      (item) =>
                          DropdownMenuItem(value: item, child: Text(item)),
                    )
                    .toList(),
                onChanged: (value) =>
                    setState(() => storage = value ?? storage),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    await ref
                        .read(wellnessWorkspaceControllerProvider.notifier)
                        .addPantryItem(
                          name: name.text,
                          quantity: double.tryParse(quantity.text) ?? 1,
                          unit: unit,
                          storageLocation: storage,
                        );
                    if (context.mounted) Navigator.pop(context);
                  },
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Add pantry item'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  ).whenComplete(() {
    name.dispose();
    quantity.dispose();
  });
}

void _showWorkoutAlternatives(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose movement',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            for (final option in bundledWorkoutCatalog)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.fitness_center_rounded),
                title: Text(option.title),
                subtitle: Text(
                  '${option.durationMinutes} min • ${option.intensity}',
                ),
                trailing: FilledButton.tonal(
                  onPressed: () async {
                    await ref
                        .read(wellnessWorkspaceControllerProvider.notifier)
                        .completeWorkout(option);
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Use'),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

Color _pageBg(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? AppColors.bgWarmDark
    : AppColors.bgWarmCream;

BoxDecoration _panelDecoration(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return BoxDecoration(
    color: isDark ? AppColors.cardSurfaceDark : AppColors.cardSurfaceLight,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(
      color: isDark ? AppColors.borderDark : AppColors.borderLight,
    ),
  );
}

String _expiryStatus(DateTime? expiryDate) {
  if (expiryDate == null) return '';
  final today = normalizeDate(DateTime.now());
  final expiry = normalizeDate(expiryDate);
  final days = expiry.difference(today).inDays;
  if (days < 0) return 'Expired';
  if (days == 0) return 'Expiring today';
  if (days <= 3) return 'Use soon';
  return 'Fresh';
}

List<String> _shoppingCategories(List<ShoppingItem> items) {
  final categories = items.map((item) => item.category).toSet().toList();
  categories.sort((a, b) {
    const order = [
      'Produce',
      'Meat/Fish',
      'Grains & Staples',
      'Beans & Legumes',
      'Dairy',
      'Spices & Seasonings',
      'Canned/Packaged',
      'Frozen',
      'Household',
      'Other',
      'General',
    ];
    final aIndex = order.indexOf(a);
    final bIndex = order.indexOf(b);
    if (aIndex == -1 && bIndex == -1) return a.compareTo(b);
    if (aIndex == -1) return 1;
    if (bIndex == -1) return -1;
    return aIndex.compareTo(bIndex);
  });
  return categories;
}

List<String> _csv(String value) {
  return value
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

String _formatQuantity(double value) {
  if (value == value.roundToDouble()) return value.round().toString();
  return value.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
}
