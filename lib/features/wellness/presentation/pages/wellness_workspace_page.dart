import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/quevaa_layout.dart';
import '../../../../app/theme/quevaa_spacing.dart';
import '../../../../core/database/app_database.dart';
import '../../../nutrition/data/nigerian_recipe_database.dart';
import '../../../workouts/domain/entities/workout_entity.dart';
import '../../application/wellness_workspace_provider.dart';

class WellnessWorkspacePage extends ConsumerWidget {
  const WellnessWorkspacePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final section = ref.watch(wellnessSectionProvider);
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
    final plans = ref.watch(mealPlanStreamProvider).valueOrNull ?? const [];
    final pantry = ref.watch(pantryStreamProvider).valueOrNull ?? const [];
    final shopping = ref.watch(shoppingStreamProvider).valueOrNull ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Meals', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        for (final mealType in const ['Breakfast', 'Lunch', 'Dinner', 'Snack'])
          _MealRecommendationCard(
            recipe: _recipeForType(mealType),
            compactTitle: mealType,
          ),
        const SizedBox(height: 12),
        _MealPlanPanel(plans: plans),
        const SizedBox(height: 12),
        _RecipeSearchPanel(),
        const SizedBox(height: 12),
        _PantryPanel(items: pantry),
        const SizedBox(height: 12),
        _ShoppingPanel(items: shopping),
      ],
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

  const _MealRecommendationCard({required this.recipe, this.compactTitle});

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
              const _MetadataChip(
                label: '30 min',
              ), // Placeholder for duration if not in entity
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
            'Nutrients: ${recipe.keyNutrients}',
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
                  onPressed: () => ref
                      .read(wellnessWorkspaceControllerProvider.notifier)
                      .markMealPrepared(recipe),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Mark as Prepared'),
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
                      onPressed: () => ref
                          .read(wellnessWorkspaceControllerProvider.notifier)
                          .planMeal(DateTime.now(), recipe),
                      icon: const Icon(Icons.bookmark_add_rounded, size: 18),
                      label: const Text('Save'),
                    ),
                  ),
                  const SizedBox(width: QuevaaSpacing.xs),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => ref
                          .read(wellnessWorkspaceControllerProvider.notifier)
                          .addRecipeToShoppingList(recipe),
                      icon: const Icon(Icons.shopping_bag_rounded, size: 18),
                      label: const Text('Ingredients'),
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

class _MealPlanPanel extends StatelessWidget {
  final List<MealPlan> plans;

  const _MealPlanPanel({required this.plans});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Seven-day meal plan',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          if (plans.isEmpty)
            const Text(
              'Create a meal plan based on your preferences and schedule.',
            )
          else
            for (final plan in plans)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_available_rounded),
                title: Text(plan.mealType),
                subtitle: Text(DateFormat.yMMMd().format(plan.date)),
              ),
        ],
      ),
    );
  }
}

class _RecipeSearchPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const recipes = NigerianRecipeDatabase.recipes;
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

class _PantryPanel extends ConsumerWidget {
  final List<PantryItem> items;

  const _PantryPanel({required this.items});

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
                  '${item.quantity} ${item.unit}${item.lowStock ? ' • low stock' : ''}',
                ),
              ),
        ],
      ),
    );
  }
}

class _ShoppingPanel extends ConsumerWidget {
  final List<ShoppingItem> items;

  const _ShoppingPanel({required this.items});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Shopping list', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (items.isEmpty)
            const Text('Add ingredients from a meal or enter pantry needs.')
          else
            for (final item in items)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: item.isPurchased,
                onChanged: (_) => ref
                    .read(wellnessWorkspaceControllerProvider.notifier)
                    .toggleShoppingItem(item),
                title: Text(item.itemName),
                subtitle: item.sourceMealTitle == null
                    ? null
                    : Text('From ${item.sourceMealTitle}'),
              ),
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

void _showPantrySheet(BuildContext context, WidgetRef ref) {
  final name = TextEditingController();
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Ingredient'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () async {
                  await ref
                      .read(wellnessWorkspaceControllerProvider.notifier)
                      .addPantryItem(name: name.text);
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
  ).whenComplete(name.dispose);
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

NigerianRecipe _recipeForType(String mealType) {
  return NigerianRecipeDatabase.recipes.firstWhere(
    (recipe) => recipe.mealType == mealType,
    orElse: () => NigerianRecipeDatabase.recipes.first,
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
