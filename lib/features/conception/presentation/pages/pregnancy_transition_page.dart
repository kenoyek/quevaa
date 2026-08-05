import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../application/conception_controller.dart';
import '../widgets/conception_widgets.dart';

class PregnancyTransitionPage extends ConsumerWidget {
  const PregnancyTransitionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(conceptionControllerProvider);
    final controller = ref.read(conceptionControllerProvider.notifier);

    return ConceptionScaffold(
      title: 'Me',
      subtitle:
          'Reports, privacy settings, partner sharing and transition options.',
      children: [
        PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle(title: 'Doctor-ready fertility report'),
              const Text(
                'Selectable PDF export requires biometric or PIN verification before generating or sharing.',
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _reportSections
                    .map(
                      (section) => FilterChip(
                        selected: true,
                        label: Text(section),
                        onSelected: (_) {},
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.lock_rounded),
                label: const Text('Verify and generate report'),
              ),
            ],
          ),
        ),
        PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle(title: 'Partner Support'),
              const Text(
                'Invitation-only and off by default. You choose each category. Access can be revoked immediately.',
              ),
              const SizedBox(height: 8),
              ..._shareable.map(
                (permission) => SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(permission),
                  value: state.partnerSharePermissions.contains(permission),
                  onChanged: (_) =>
                      controller.togglePartnerSharePermission(permission),
                ),
              ),
              const InfoPanel(
                icon: Icons.visibility_off_rounded,
                color: AppColors.terracottaPrimary,
                text:
                    'Never shared by default: intimacy history, journal entries, pregnancy-test results, cervical mucus, medical conditions, past pregnancy information or specific symptoms.',
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
                'Positive pregnancy-test transition',
                style: Theme.of(
                  context,
                ).textTheme.headlineMedium?.copyWith(color: AppColors.sageDark),
              ),
              const SizedBox(height: 8),
              const Text(
                'If a positive result is recorded, Quevaa offers Early Pregnancy Mode without automatically switching or showing celebratory animation.',
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: () {},
                    child: const Text('Retest later'),
                  ),
                  OutlinedButton(
                    onPressed: () {},
                    child: const Text('Contact a clinician'),
                  ),
                  FilledButton(
                    onPressed: () {},
                    child: const Text('Offer Early Pregnancy Mode'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const InfoPanel(
          icon: Icons.emergency_rounded,
          color: AppColors.terracottaDark,
          text:
              'Get medical help for severe pain, faintness, heavy bleeding or concerning pain with a suspected or confirmed pregnancy. This guidance must be medically reviewed and localised before release.',
        ),
        OutlinedButton.icon(
          onPressed: controller.leaveConceptionMode,
          icon: const Icon(Icons.exit_to_app_rounded),
          label: const Text('Leave Conception Mode without deleting records'),
        ),
      ],
    );
  }
}

const _shareable = [
  'Fertile window approaching',
  'Support requested',
  'Shared supplement reminder',
  'Shopping list',
  'Meal plan',
  'Appointment',
  'I would appreciate rest today',
  'I would appreciate company today',
];

const _reportSections = [
  'Trying start date',
  'Period dates',
  'Cycle lengths',
  'Fertile-window estimates',
  'Cervical mucus',
  'Ovulation tests',
  'BBT chart',
  'Possible ovulation dates',
  'Pregnancy-test results',
  'Medication and supplement log',
  'Symptoms',
  'Appointment questions',
  'Algorithm version',
  'Confidence explanation',
];
