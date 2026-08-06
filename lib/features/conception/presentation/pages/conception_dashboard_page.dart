import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/models/prediction_confidence.dart';
import '../../application/conception_controller.dart';
import '../../application/fertility_dashboard_provider.dart';
import '../../domain/entities/fertility_assessment.dart';
import '../widgets/conception_widgets.dart';

class ConceptionDashboardPage extends ConsumerWidget {
  const ConceptionDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assessment = ref.watch(fertilityDashboardProvider);
    final state = ref.watch(conceptionControllerProvider);
    final controller = ref.read(conceptionControllerProvider.notifier);
    final theme = Theme.of(context);

    return ConceptionScaffold(
      title: 'Today',
      subtitle:
          'Conception dashboard for fertility observations, care planning and calm next steps.',
      trailing: IconButton(
        tooltip: 'Notifications',
        onPressed: () => context.go('/notifications/settings'),
        icon: const Icon(Icons.notifications_none_rounded),
      ),
      children: [
        _HeroAssessmentCard(
          assessment: assessment,
        ).animate().fadeIn(duration: 450.ms).slideY(begin: 0.06, end: 0),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: () => context.go('/conception/log'),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Log fertility signs'),
            ),
            OutlinedButton.icon(
              onPressed: () => context.go('/conception/log'),
              icon: const Icon(Icons.science_rounded),
              label: const Text('Log ovulation test'),
            ),
            OutlinedButton.icon(
              onPressed: () => context.go('/conception/log'),
              icon: const Icon(Icons.thermostat_rounded),
              label: const Text('Add temperature'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Today's fertility card",
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: 10),
              TinyPill(
                icon: Icons.eco_rounded,
                label: assessment.status.label,
                color: _statusColor(assessment.status),
              ),
              const SizedBox(height: 12),
              Text('Why this changed', style: theme.textTheme.labelLarge),
              const SizedBox(height: 4),
              Text(assessment.explanation),
              const SizedBox(height: 12),
              Text('Relevant observations', style: theme.textTheme.labelLarge),
              const SizedBox(height: 6),
              ...assessment.relevantObservations.map(_BulletLine.new),
              const SizedBox(height: 12),
              Text(
                'What could improve confidence',
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: 6),
              ...assessment.confidenceImprovements.map(_BulletLine.new),
            ],
          ),
        ),
        const InfoPanel(
          icon: Icons.favorite_border_rounded,
          color: AppColors.deepPlumLight,
          text:
              'Having sex every day or every other day during the fertile window generally provides the highest opportunity for conception. Choose a frequency that works comfortably for both partners.',
        ),
        const SizedBox(height: 14),
        PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle(
                title: 'Daily checklist',
                actionLabel: state.profile.gentleModeEnabled
                    ? 'Gentle mode on'
                    : 'Gentle mode',
                onAction: controller.pausePredictionsForCycle,
              ),
              ...assessment.dailyChecklist.map(
                (item) => ChecklistTile(
                  title: item,
                  value: state.completedChecklistItems.contains(item),
                  onChanged: (_) => controller.toggleChecklistItem(item),
                ),
              ),
            ],
          ),
        ),
        PremiumCard(
          color: AppColors.sageContainer,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Trying for ${state.profile.tryingCycleCount} cycles',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: AppColors.sageDark,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your records are available whenever you wish to discuss them with a clinician. Quevaa can prepare a selectable report with cycle dates, observations, tests, BBT and questions.',
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => context.go('/me'),
                icon: const Icon(Icons.description_rounded),
                label: const Text('Review doctor-ready report'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeroAssessmentCard extends StatelessWidget {
  final FertilityAssessment assessment;

  const _HeroAssessmentCard({required this.assessment});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('d MMM');

    return PremiumCard(
      color: AppColors.deepPlum,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TinyPill(
                icon: Icons.calendar_today_rounded,
                label: 'Cycle Day ${assessment.cycleDay}',
                color: AppColors.terracottaLight,
              ),
              const Spacer(),
              TinyPill(
                icon: Icons.insights_rounded,
                label: 'Confidence: ${formatPredictionConfidence(assessment.confidence)}',
                color: AppColors.sageLight,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            assessment.status.label,
            style: theme.textTheme.displaySmall?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            'Estimated ovulation: ${dateFormat.format(assessment.ovulationRangeStart)}-${dateFormat.format(assessment.ovulationRangeEnd)}',
            style: const TextStyle(color: Colors.white70, fontSize: 15),
          ),
          const SizedBox(height: 8),
          Text(
            'Fertile window: ${dateFormat.format(assessment.fertileWindowStart)}-${dateFormat.format(assessment.fertileWindowEnd)}',
            style: const TextStyle(color: Colors.white70, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

class _BulletLine extends StatelessWidget {
  final String text;

  const _BulletLine(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_outline_rounded,
            color: AppColors.sagePrimary,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

Color _statusColor(FertilityStatus status) {
  switch (status) {
    case FertilityStatus.period:
      return AppColors.mutedRose;
    case FertilityStatus.fertilityPreparing:
    case FertilityStatus.fertilityRising:
      return AppColors.sagePrimary;
    case FertilityStatus.highFertility:
    case FertilityStatus.peakFertilitySigns:
      return AppColors.terracottaPrimary;
    case FertilityStatus.ovulationLikelyPassed:
    case FertilityStatus.waitingAndTesting:
      return AppColors.deepPlumLight;
  }
}
