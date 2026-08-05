import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../application/conception_controller.dart';
import '../../domain/entities/conception_profile.dart';
import '../widgets/conception_widgets.dart';

class ConceptionOnboardingPage extends ConsumerStatefulWidget {
  const ConceptionOnboardingPage({super.key});

  @override
  ConsumerState<ConceptionOnboardingPage> createState() =>
      _ConceptionOnboardingPageState();
}

class _ConceptionOnboardingPageState
    extends ConsumerState<ConceptionOnboardingPage> {
  bool _usesOvulationTests = true;
  bool _tracksBbt = true;
  bool _tracksMucus = true;
  bool _logsIntimacy = false;
  bool _partnerSupport = false;
  bool _prenatalReminder = true;
  bool _cyclesRegular = true;

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(conceptionControllerProvider).profile;
    final dateFormat = DateFormat('d MMMM');

    return ConceptionScaffold(
      title: 'Conception Mode',
      subtitle:
          'A dedicated Trying to Conceive experience for fertility signs, gentle planning, wellness and doctor-ready records.',
      trailing: IconButton(
        tooltip: 'Close',
        onPressed: () => context.go('/'),
        icon: const Icon(Icons.close_rounded),
      ),
      children: [
        PremiumCard(
          color: AppColors.deepPlum,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const TinyPill(
                icon: Icons.favorite_rounded,
                label: 'Trying to conceive',
                color: AppColors.terracottaLight,
              ),
              const SizedBox(height: 14),
              Text(
                'Quevaa will reshape Today, Cycle, Plan, Wellness and Me around conception care.',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'You can leave Conception Mode later without losing your period history, symptoms, notes or wellness records.',
                style: TextStyle(color: Colors.white70, height: 1.45),
              ),
            ],
          ),
        ),
        _SensitiveQuestionCard(
          title: 'When did you start trying?',
          currentValue: dateFormat.format(profile.tryingStartDate),
          why:
              'Quevaa uses this to show a private Trying Duration counter and prepare doctor-ready summaries.',
          use:
              'It will never be used for shame-based streaks or pressure language.',
        ),
        _SensitiveQuestionCard(
          title: 'First day of your most recent period',
          currentValue: dateFormat.format(profile.lastPeriodStartDate),
          why:
              'This anchors the first estimated ovulation range and expected period range.',
          use:
              'Quevaa shows date ranges and confidence, not a single certain ovulation day.',
        ),
        _SensitiveQuestionCard(
          title: 'Previous cycle dates',
          currentValue: '${profile.previousPeriodStartDates.length} saved',
          why:
              'At least three cycles can improve confidence when cycle lengths are consistent.',
          use:
              'Unusual cycles are stored as context, not interpreted as a health condition.',
        ),
        PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tracking preferences',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              _PreferenceSwitch(
                title: 'Cycles are usually regular',
                subtitle:
                    'Used to adjust prediction confidence. You can change this later.',
                value: _cyclesRegular,
                onChanged: (value) => setState(() => _cyclesRegular = value),
              ),
              _PreferenceSwitch(
                title: 'Use ovulation test strips',
                subtitle:
                    'Adds LH test logging and peak-fertility wording without guaranteeing ovulation.',
                value: _usesOvulationTests,
                onChanged: (value) =>
                    setState(() => _usesOvulationTests = value),
              ),
              _PreferenceSwitch(
                title: 'Track basal body temperature',
                subtitle:
                    'Used to look retrospectively for a sustained shift after waking readings.',
                value: _tracksBbt,
                onChanged: (value) => setState(() => _tracksBbt = value),
              ),
              _PreferenceSwitch(
                title: 'Track cervical mucus',
                subtitle:
                    'Used to identify signs of increasing fertility; unsure entries are welcome.',
                value: _tracksMucus,
                onChanged: (value) => setState(() => _tracksMucus = value),
              ),
              _PreferenceSwitch(
                title: 'Log intimacy',
                subtitle:
                    'Optional and protected by an additional privacy setting.',
                value: _logsIntimacy,
                onChanged: (value) => setState(() => _logsIntimacy = value),
              ),
              _PreferenceSwitch(
                title: 'Partner shared-support feature',
                subtitle:
                    'Invitation-only and off by default. Sensitive health details are never shared automatically.',
                value: _partnerSupport,
                onChanged: (value) => setState(() => _partnerSupport = value),
              ),
              _PreferenceSwitch(
                title: 'Prenatal or folic-acid reminder',
                subtitle:
                    'Quevaa can remind you to review support with a clinician; it will not prescribe a dose.',
                value: _prenatalReminder,
                onChanged: (value) => setState(() => _prenatalReminder = value),
              ),
            ],
          ),
        ),
        PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Private preconception checklist',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 10),
              ..._checklist.map(
                (item) => Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.lock_outline_rounded,
                      color: AppColors.sagePrimary,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(item)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const InfoPanel(
                icon: Icons.medical_information_outlined,
                color: AppColors.terracottaPrimary,
                text:
                    'WHO recommends 400 micrograms of folic acid daily from when a woman begins trying to conceive until 12 weeks of pregnancy. Higher doses are only for certain circumstances and should be clinician-directed.',
              ),
            ],
          ),
        ),
        ElevatedButton.icon(
          onPressed: () {
            final updated = profile.copyWith(
              status: ConceptionGoalStatus.tryingToConceive,
              cyclesUsuallyRegular: _cyclesRegular,
              usesOvulationTests: _usesOvulationTests,
              tracksBasalTemperature: _tracksBbt,
              tracksCervicalMucus: _tracksMucus,
              logsIntimacy: _logsIntimacy,
              partnerSupportEnabled: _partnerSupport,
              prenatalReminderEnabled: _prenatalReminder,
            );
            ref
                .read(conceptionControllerProvider.notifier)
                .updateProfile(updated);
            context.go('/');
          },
          icon: const Icon(Icons.spa_rounded, color: Colors.white),
          label: const Text('Enter Conception Mode'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.terracottaPrimary,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _SensitiveQuestionCard extends StatelessWidget {
  final String title;
  final String currentValue;
  final String why;
  final String use;

  const _SensitiveQuestionCard({
    required this.title,
    required this.currentValue,
    required this.why,
    required this.use,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              TextButton(onPressed: () {}, child: const Text('Skip for now')),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            currentValue,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: AppColors.terracottaDark),
          ),
          const SizedBox(height: 12),
          Text(
            'Why Quevaa is asking',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          Text(why),
          const SizedBox(height: 8),
          Text(
            'How this answer is used',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          Text(use),
        ],
      ),
    );
  }
}

class _PreferenceSwitch extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _PreferenceSwitch({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }
}

const _checklist = [
  'Review regular medications with a qualified clinician',
  'Begin appropriate prenatal or folic-acid support',
  'Review vaccinations and existing health conditions',
  'Avoid smoking and recreational drugs',
  'Review alcohol use',
  'Book a preconception appointment where appropriate',
  'Discuss genotype or relevant carrier screening with a clinician',
  'Record known allergies and medical conditions',
];
