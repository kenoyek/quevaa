import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../widgets/conception_widgets.dart';

class ConceptionWellnessPage extends StatelessWidget {
  const ConceptionWellnessPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ConceptionScaffold(
      title: 'Wellness',
      subtitle:
          'Preconception meals, movement, hydration, self-care and Nigerian market planning.',
      children: [
        const InfoPanel(
          icon: Icons.restaurant_rounded,
          color: AppColors.sagePrimary,
          text:
              'Quevaa uses “preconception wellness meals,” not foods that promise pregnancy. Balanced nutrition supports health but no meal guarantees conception.',
        ),
        const SizedBox(height: 14),
        PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle(title: 'Seven-day preconception meal plan'),
              ..._meals.map(
                (meal) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.restaurant_menu_rounded,
                    color: AppColors.terracottaPrimary,
                  ),
                  title: Text(meal.title),
                  subtitle: Text(meal.subtitle),
                  trailing: TinyPill(
                    icon: Icons.payments_outlined,
                    label: meal.budget,
                    color: AppColors.sagePrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle(title: 'Meal planner tools'),
              _WellnessTool(label: 'Cook with what I have'),
              _WellnessTool(label: 'Low-budget alternatives'),
              _WellnessTool(label: 'Nigerian market categories'),
              _WellnessTool(label: 'Partner meal plan'),
              _WellnessTool(label: 'Hydration reminders'),
              _WellnessTool(label: 'Optional caffeine tracking'),
            ],
          ),
        ),
        const PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle(title: 'Emotional support prompts'),
              _Prompt('What support would feel helpful today?'),
              _Prompt('What is within your control this week?'),
              _Prompt('How did tracking make you feel today?'),
              _Prompt('Would you prefer fewer fertility reminders?'),
              _Prompt('What would help you feel connected to your partner?'),
            ],
          ),
        ),
      ],
    );
  }
}

class _WellnessTool extends StatelessWidget {
  final String label;

  const _WellnessTool({required this.label});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(
        Icons.check_circle_outline_rounded,
        color: AppColors.sagePrimary,
      ),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}

class _Prompt extends StatelessWidget {
  final String text;

  const _Prompt(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text('“$text”'),
    );
  }
}

class _MealOption {
  final String title;
  final String subtitle;
  final String budget;

  const _MealOption({
    required this.title,
    required this.subtitle,
    required this.budget,
  });
}

const _meals = [
  _MealOption(
    title: 'Beans and plantain',
    subtitle:
        'Folate-supportive option. Add vegetables; swap plantain for sweet potato.',
    budget: 'Low',
  ),
  _MealOption(
    title: 'Moi moi with vegetables',
    subtitle:
        'Protein-balanced. Contains beans; note egg or fish allergens where added.',
    budget: 'Low',
  ),
  _MealOption(
    title: 'Ugu-based soup with fish',
    subtitle:
        'Iron-containing. Serve with swallow, rice or yam based on preference.',
    budget: 'Mid',
  ),
  _MealOption(
    title: 'Grilled fish, vegetables and rice',
    subtitle:
        'Balanced protein and carbohydrates. Household serving size: 2-4.',
    budget: 'Mid',
  ),
  _MealOption(
    title: 'Avocado and egg combination',
    subtitle:
        'Quick meal. Prep time: 15 minutes; substitute beans for egg allergy.',
    budget: 'Mid',
  ),
];
