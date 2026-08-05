import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../application/fertility_chart_provider.dart';
import '../../application/fertility_dashboard_provider.dart';
import '../../domain/entities/fertility_observation.dart';
import '../widgets/conception_widgets.dart';

class TemperatureChartPage extends ConsumerWidget {
  const TemperatureChartPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chart = ref.watch(fertilityChartProvider);
    final assessment = ref.watch(fertilityDashboardProvider);
    final dateFormat = DateFormat('d MMM');

    return ConceptionScaffold(
      title: 'Cycle',
      subtitle:
          'Fertility observations, ovulation estimates, temperature pattern and cycle comparison.',
      children: [
        PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle(title: 'Calendar layers'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _layers
                    .map(
                      (layer) => FilterChip(
                        selected: true,
                        label: Text(layer),
                        onSelected: (_) {},
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
        PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Estimated fertile window',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 10),
              Text(
                '${dateFormat.format(assessment.fertileWindowStart)}-${dateFormat.format(assessment.fertileWindowEnd)}',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: AppColors.terracottaDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Estimated ovulation: ${dateFormat.format(assessment.ovulationRangeStart)}-${dateFormat.format(assessment.ovulationRangeEnd)}',
              ),
              const SizedBox(height: 12),
              const InfoPanel(
                icon: Icons.insights_rounded,
                color: AppColors.sagePrimary,
                text:
                    'Even with regular cycles, fertile windows can vary. Quevaa shows ranges and confidence instead of a single certain date.',
              ),
            ],
          ),
        ),
        PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle(title: 'Basal temperature chart'),
              SizedBox(
                height: 220,
                child: chart.temperatures.length < 2
                    ? const Center(
                        child: Text('Add two or more waking temperatures.'),
                      )
                    : LineChart(_lineData(chart.observations)),
              ),
              const SizedBox(height: 12),
              const InfoPanel(
                icon: Icons.thermostat_rounded,
                color: AppColors.terracottaPrimary,
                text:
                    'Quevaa requires a sustained pattern across later readings before labeling ovulation as likely. One high temperature is never enough.',
              ),
            ],
          ),
        ),
        const PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle(title: 'Cycle comparison'),
              ...[
                _ComparisonRow(
                  label: 'Fertile-window comparison',
                  value: '3 cycles ready',
                ),
                _ComparisonRow(
                  label: 'LH-test comparison',
                  value: '2 tests this cycle',
                ),
                _ComparisonRow(
                  label: 'Ovulation estimate by cycle',
                  value: 'Range based',
                ),
                _ComparisonRow(
                  label: 'Luteal-phase estimate',
                  value: 'Waiting for confirmation',
                ),
                _ComparisonRow(
                  label: 'Pregnancy-test history',
                  value: 'Private',
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

LineChartData _lineData(List<FertilityObservation> observations) {
  final sorted =
      observations.where((entry) => entry.basalTemperature != null).toList()
        ..sort((a, b) => a.date.compareTo(b.date));

  final spots = <FlSpot>[
    for (var i = 0; i < sorted.length; i++)
      FlSpot(i.toDouble(), sorted[i].basalTemperature!.celsius),
  ];

  return LineChartData(
    gridData: FlGridData(
      drawVerticalLine: false,
      getDrawingHorizontalLine: (_) =>
          const FlLine(color: AppColors.borderLight, strokeWidth: 1),
    ),
    titlesData: const FlTitlesData(
      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
    ),
    borderData: FlBorderData(show: false),
    minY: 35.8,
    maxY: 37.4,
    lineBarsData: [
      LineChartBarData(
        spots: spots,
        isCurved: true,
        barWidth: 3,
        color: AppColors.terracottaPrimary,
        belowBarData: BarAreaData(
          show: true,
          color: AppColors.terracottaPrimary.withValues(alpha: 0.10),
        ),
        dotData: FlDotData(
          getDotPainter: (spot, percent, bar, index) {
            final disturbed =
                !(sorted[index].basalTemperature?.isReliable ?? true);
            return FlDotCirclePainter(
              radius: disturbed ? 5 : 4,
              color: disturbed ? AppColors.warmGold : AppColors.deepPlum,
              strokeWidth: 2,
              strokeColor: Colors.white,
            );
          },
        ),
      ),
    ],
  );
}

class _ComparisonRow extends StatelessWidget {
  final String label;
  final String value;

  const _ComparisonRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.deepPlumLight,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

const _layers = [
  'Period',
  'Estimated fertile window',
  'Cervical mucus',
  'Ovulation tests',
  'BBT',
  'Intimacy',
  'Pregnancy tests',
  'Symptoms',
  'Medication',
  'Appointments',
];
