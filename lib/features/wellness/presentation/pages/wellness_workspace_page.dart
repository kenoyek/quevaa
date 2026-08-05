import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
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
              padding: const EdgeInsets.all(20),
              sliver: SliverToBoxAdapter(
                child: _WellnessHeader(recommendation: recommendation),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverToBoxAdapter(
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'For You',
                      label: Text('For You'),
                      icon: Icon(Icons.auto_awesome_rounded),
                    ),
                    ButtonSegment(
                      value: 'Meals',
                      label: Text('Meals'),
                      icon: Icon(Icons.restaurant_rounded),
                    ),
                    ButtonSegment(
                      value: 'Movement',
                      label: Text('Move'),
                      icon: Icon(Icons.fitness_center_rounded),
                    ),
                    ButtonSegment(
                      value: 'Mind',
                      label: Text('Mind'),
                      icon: Icon(Icons.edit_note_rounded),
                    ),
                    ButtonSegment(
                      value: 'Progress',
                      label: Text('Progress'),
                      icon: Icon(Icons.insights_rounded),
                    ),
                  ],
                  selected: {section},
                  onSelectionChanged: (value) =>
                      ref.read(wellnessSectionProvider.notifier).state =
                          value.first,
                ),
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _panelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Wellness', style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 8),
          Text(
            'Today’s focus: ${recommendation.focus}',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 6),
          Text(recommendation.reason),
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
    final count = ref.watch(journalEntryCountProvider).valueOrNull ?? 0;
    return Column(
      children: [
        _JournalPrompt(prompt: prompt),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: _panelDecoration(context),
          child: Row(
            children: [
              const Icon(Icons.lock_rounded, color: AppColors.deepPlum),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '$count private journal entries are stored locally.',
                ),
              ),
            ],
          ),
        ),
      ],
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
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: AppColors.terracottaContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.restaurant_rounded,
                  color: AppColors.terracottaPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      compactTitle ?? 'Recommended meal',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    Text(
                      recipe.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      '${recipe.mealType} • ${recipe.region} • ${recipe.keyNutrients}',
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(recipe.description),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: () => ref
                    .read(wellnessWorkspaceControllerProvider.notifier)
                    .planMeal(DateTime.now(), recipe),
                icon: const Icon(Icons.bookmark_add_rounded),
                label: const Text('Save'),
              ),
              OutlinedButton.icon(
                onPressed: () => ref
                    .read(wellnessWorkspaceControllerProvider.notifier)
                    .markMealPrepared(recipe),
                icon: const Icon(Icons.check_rounded),
                label: const Text('Prepared'),
              ),
              OutlinedButton.icon(
                onPressed: () => ref
                    .read(wellnessWorkspaceControllerProvider.notifier)
                    .addRecipeToShoppingList(recipe),
                icon: const Icon(Icons.shopping_bag_rounded),
                label: const Text('Add ingredients'),
              ),
            ],
          ),
        ],
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Today’s movement',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 4),
          Text(workout.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            '${workout.durationMinutes} min • ${workout.intensity} • ${workout.equipmentRequired.join(', ')}',
          ),
          const SizedBox(height: 8),
          const Text(
            'Suggested as a movement option based on today’s logged energy, pain, sleep, and recent activity.',
          ),
          if (expanded) ...[
            const SizedBox(height: 12),
            const Text(WorkoutEntity.preWorkoutSafetyPrompt),
            const SizedBox(height: 10),
            for (final exercise in [
              ...workout.warmup,
              ...workout.mainExercises,
              ...workout.cooldown,
            ])
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.play_circle_outline_rounded),
                title: Text(exercise.name),
                subtitle: Text(
                  '${exercise.durationOrReps}. ${exercise.modification}',
                ),
              ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () => ref
                    .read(wellnessWorkspaceControllerProvider.notifier)
                    .completeWorkout(workout),
                icon: const Icon(Icons.check_rounded),
                label: const Text('Complete'),
              ),
              OutlinedButton.icon(
                onPressed: () => _showWorkoutAlternatives(context, ref),
                icon: const Icon(Icons.swap_horiz_rounded),
                label: const Text('Replace'),
              ),
              OutlinedButton.icon(
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
                icon: const Icon(Icons.self_improvement_rounded),
                label: const Text('Rest day'),
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
            'Mind and journal',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(prompt),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => ref
                .read(wellnessWorkspaceControllerProvider.notifier)
                .addJournalPrompt(prompt),
            icon: const Icon(Icons.edit_note_rounded),
            label: const Text('Save private reflection prompt'),
          ),
        ],
      ),
    );
  }
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
