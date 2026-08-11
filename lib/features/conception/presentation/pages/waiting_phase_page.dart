import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../application/conception_controller.dart';
import '../../application/fertility_dashboard_provider.dart';
import '../widgets/conception_widgets.dart';

class WaitingPhasePage extends ConsumerWidget {
  const WaitingPhasePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assessment = ref.watch(fertilityDashboardProvider);
    final controller = ref.read(conceptionControllerProvider.notifier);
    final dateFormat = DateFormat('d MMMM');
    final daysAfterOvulation = DateTime.now()
        .difference(assessment.ovulationRangeEnd)
        .inDays;
    final recommendedTestDate = assessment.expectedPeriodStart;

    return ConceptionScaffold(
      title: 'Plan',
      subtitle:
          'Intimacy, testing, appointment reminders and gentle emotional controls.',
      children: [
        PremiumCard(
          color: AppColors.deepPlum,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const TinyPill(
                icon: Icons.nightlight_round,
                label: 'Waiting phase',
                color: AppColors.warmGold,
              ),
              const SizedBox(height: 16),
              Text(
                daysAfterOvulation > 0
                    ? 'Estimated $daysAfterOvulation days after ovulation'
                    : 'Fertile window planning',
                style: Theme.of(
                  context,
                ).textTheme.headlineMedium?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                'Expected period range: ${dateFormat.format(assessment.expectedPeriodStart)}-${dateFormat.format(assessment.expectedPeriodEnd)}',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 6),
              Text(
                'Recommended test date: ${dateFormat.format(recommendedTestDate)}',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
        const InfoPanel(
          icon: Icons.science_outlined,
          color: AppColors.terracottaPrimary,
          text:
              'Most home pregnancy tests can be used from the first day of a missed period. If the expected period is unknown, NHS guidance recommends testing at least 21 days after the last unprotected intercourse.',
        ),
        const SizedBox(height: 14),
        PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle(title: 'Testing journey'),
              _PlanAction(
                icon: Icons.science_rounded,
                title: 'Log pregnancy test',
                subtitle: 'Negative, positive, unclear or retest planned.',
                onTap: () => context.go('/conception/log'),
              ),
              _PlanAction(
                icon: Icons.calendar_month_rounded,
                title: 'Plan appointment',
                subtitle:
                    'Prepare questions and records for a clinician when useful.',
                onTap: () => _showLocalNotice(
                  context,
                  'Appointment planning will use your local task planner.',
                ),
              ),
              _PlanAction(
                icon: Icons.favorite_border_rounded,
                title: 'Journal prompt',
                subtitle: 'What support would feel helpful today?',
                onTap: () => context.go('/wellness'),
              ),
            ],
          ),
        ),
        PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle(title: 'Emotional controls'),
              _ControlButton(
                label: 'Pause fertility predictions for this cycle',
                onPressed: controller.pausePredictionsForCycle,
              ),
              _ControlButton(
                label: 'Hide countdown',
                onPressed: () => _showLocalNotice(
                  context,
                  'Countdown hidden for this view.',
                ),
              ),
              _ControlButton(
                label: 'Hide pregnancy-test prompts',
                onPressed: () => _showLocalNotice(
                  context,
                  'Pregnancy-test prompts reduced for this cycle.',
                ),
              ),
              _ControlButton(
                label: 'Reduce reminders',
                onPressed: () => context.push('/notifications/settings'),
              ),
              _ControlButton(
                label: 'Remove intimacy scheduling',
                onPressed: () => _showLocalNotice(
                  context,
                  'Intimacy scheduling is off by default and remains private.',
                ),
              ),
              _ControlButton(
                label: 'Archive a difficult cycle privately',
                onPressed: () => _showLocalNotice(
                  context,
                  'Private cycle archive controls are marked for release hardening.',
                ),
              ),
            ],
          ),
        ),
        const InfoPanel(
          icon: Icons.favorite_rounded,
          color: AppColors.sagePrimary,
          text:
              'Tracking can feel intense. You can reduce fertility reminders or switch to gentle mode at any point.',
        ),
      ],
    );
  }
}

void _showLocalNotice(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

class _PlanAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _PlanAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.terracottaPrimary),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}

class _ControlButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _ControlButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: OutlinedButton(
        onPressed: onPressed,
        child: Align(alignment: Alignment.centerLeft, child: Text(label)),
      ),
    );
  }
}
