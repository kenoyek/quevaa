import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../application/conception_controller.dart';
import '../../domain/entities/basal_temperature.dart';
import '../../domain/entities/cervical_mucus_entry.dart';
import '../../domain/entities/fertility_observation.dart';
import '../../domain/entities/ovulation_test.dart';
import '../../domain/entities/pregnancy_test.dart';
import '../widgets/conception_widgets.dart';

class FertilityLogPage extends ConsumerStatefulWidget {
  const FertilityLogPage({super.key});

  @override
  ConsumerState<FertilityLogPage> createState() => _FertilityLogPageState();
}

class _FertilityLogPageState extends ConsumerState<FertilityLogPage> {
  CervicalMucusType _mucus = CervicalMucusType.unsure;
  OvulationTestResult _lhTest = OvulationTestResult.notTaken;
  PregnancyTestResult _pregnancyTest = PregnancyTestResult.notTaken;
  double _temperature = 36.45;
  bool _poorSleep = false;
  bool _fever = false;
  bool _alcohol = false;
  bool _earlyWake = false;
  bool _disturbed = false;
  bool _intimacy = false;
  bool _insemination = false;
  bool _prenatal = true;
  bool _illness = false;
  int _mood = 3;
  int _energy = 3;
  int _stress = 3;

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(conceptionControllerProvider).profile;

    return ConceptionScaffold(
      title: 'Log fertility signs',
      subtitle:
          'Record only what feels useful today. Unsure and skipped entries are valid data.',
      trailing: IconButton(
        tooltip: 'Done',
        onPressed: () => context.go('/'),
        icon: const Icon(Icons.close_rounded),
      ),
      children: [
        PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle(title: 'Cervical mucus'),
              const Text(
                'Thin, slippery cervical mucus commonly appears near ovulation, but medication, intercourse, breastfeeding, hygiene products and some examinations can affect appearance.',
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: CervicalMucusType.values.map((type) {
                  return ChoiceChip(
                    label: Text(type.label),
                    selected: _mucus == type,
                    onSelected: (_) => setState(() => _mucus = type),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle(title: 'Ovulation test'),
              const Text(
                'A positive urinary LH test suggests ovulation may occur within approximately 24 to 48 hours, but it does not guarantee ovulation occurred.',
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: OvulationTestResult.values.map((result) {
                  return ChoiceChip(
                    label: Text(result.label),
                    selected: _lhTest == result,
                    onSelected: (_) => setState(() => _lhTest = result),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Local photo attachments are not enabled in this build.',
                    ),
                  ),
                ),
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Store photo locally'),
              ),
            ],
          ),
        ),
        PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle(title: 'Basal body temperature'),
              const Text(
                'BBT should be taken after waking and before normal activity. It can help confirm that ovulation has already occurred, not reliably predict it by itself.',
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: _temperature,
                      min: 35.8,
                      max: 37.4,
                      divisions: 32,
                      label: '${_temperature.toStringAsFixed(2)} C',
                      onChanged: (value) =>
                          setState(() => _temperature = value),
                    ),
                  ),
                  SizedBox(
                    width: 70,
                    child: Text('${_temperature.toStringAsFixed(2)} C'),
                  ),
                ],
              ),
              _FlagSwitch(
                label: 'Poor sleep',
                value: _poorSleep,
                onChanged: (value) => setState(() => _poorSleep = value),
              ),
              _FlagSwitch(
                label: 'Fever or illness',
                value: _fever,
                onChanged: (value) => setState(() => _fever = value),
              ),
              _FlagSwitch(
                label: 'Alcohol',
                value: _alcohol,
                onChanged: (value) => setState(() => _alcohol = value),
              ),
              _FlagSwitch(
                label: 'Woke unusually early',
                value: _earlyWake,
                onChanged: (value) => setState(() => _earlyWake = value),
              ),
              _FlagSwitch(
                label: 'Measurement disturbed',
                value: _disturbed,
                onChanged: (value) => setState(() => _disturbed = value),
              ),
            ],
          ),
        ),
        if (profile.logsIntimacy)
          PremiumCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle(title: 'Intimacy'),
                const InfoPanel(
                  icon: Icons.lock_rounded,
                  color: AppColors.deepPlumLight,
                  text:
                      'Intimacy logging is optional and protected by an additional privacy setting. Quevaa never uses failure language or streak pressure.',
                ),
                _FlagSwitch(
                  label: 'Intimacy occurred',
                  value: _intimacy,
                  onChanged: (value) => setState(() => _intimacy = value),
                ),
                _FlagSwitch(
                  label: 'Insemination',
                  value: _insemination,
                  onChanged: (value) => setState(() => _insemination = value),
                ),
              ],
            ),
          ),
        PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle(title: 'Additional observations'),
              _ScoreRow(
                label: 'Mood',
                value: _mood,
                onChanged: (value) => setState(() => _mood = value),
              ),
              _ScoreRow(
                label: 'Energy',
                value: _energy,
                onChanged: (value) => setState(() => _energy = value),
              ),
              _ScoreRow(
                label: 'Stress',
                value: _stress,
                onChanged: (value) => setState(() => _stress = value),
              ),
              _FlagSwitch(
                label: 'Prenatal supplement',
                value: _prenatal,
                onChanged: (value) => setState(() => _prenatal = value),
              ),
              _FlagSwitch(
                label: 'Illness or travel disruption',
                value: _illness,
                onChanged: (value) => setState(() => _illness = value),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: PregnancyTestResult.values.map((result) {
                  return ChoiceChip(
                    label: Text('Pregnancy: ${result.label}'),
                    selected: _pregnancyTest == result,
                    onSelected: (_) => setState(() => _pregnancyTest = result),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        ElevatedButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.check_rounded, color: Colors.white),
          label: const Text('Save fertility log'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.terracottaPrimary,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }

  void _save() {
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    ref
        .read(conceptionControllerProvider.notifier)
        .logObservation(
          FertilityObservation(
            date: day,
            cervicalMucus: CervicalMucusEntry(date: day, type: _mucus),
            ovulationTest: OvulationTestEntry(testedAt: now, result: _lhTest),
            basalTemperature: BasalTemperatureEntry(
              measuredAt: now,
              temperature: _temperature,
              poorSleep: _poorSleep,
              feverOrIllness: _fever,
              alcohol: _alcohol,
              wokeUnusuallyEarly: _earlyWake,
              disturbed: _disturbed,
            ),
            intimacy: _intimacy
                ? IntimacyEntry(
                    occurredAt: now,
                    type: _insemination
                        ? IntimacyType.insemination
                        : IntimacyType.intercourse,
                  )
                : null,
            pregnancyTest: PregnancyTestEntry(
              testedAt: now,
              result: _pregnancyTest,
            ),
            mood: _mood,
            energy: _energy,
            stress: _stress,
            prenatalSupplement: _prenatal,
            illness: _illness || _fever,
          ),
        );
    context.go('/');
  }
}

class _FlagSwitch extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _FlagSwitch({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      value: value,
      onChanged: onChanged,
    );
  }
}

class _ScoreRow extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  const _ScoreRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        Row(
          children: List.generate(5, (index) {
            final score = index + 1;
            return IconButton(
              tooltip: '$label $score',
              constraints: const BoxConstraints.tightFor(width: 34, height: 34),
              padding: EdgeInsets.zero,
              onPressed: () => onChanged(score),
              icon: Icon(
                score <= value ? Icons.circle_rounded : Icons.circle_outlined,
                size: 18,
                color: score <= value
                    ? AppColors.terracottaPrimary
                    : AppColors.textSecondaryLight,
              ),
            );
          }),
        ),
      ],
    );
  }
}
