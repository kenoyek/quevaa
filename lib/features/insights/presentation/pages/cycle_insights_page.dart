import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../application/cycle_insights_provider.dart';
import '../../domain/cycle_insights_analyzer.dart';

class CycleInsightsPage extends ConsumerWidget {
  const CycleInsightsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(cycleInsightsRangeProvider);
    final insightsAsync = ref.watch(cycleInsightsProvider(range));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgWarmDark : AppColors.bgWarmCream,
      appBar: AppBar(
        leading: BackButton(
          onPressed: () => context.canPop() ? context.pop() : context.go('/me'),
        ),
        title: const Text('Cycle Insights'),
      ),
      body: insightsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          message: "We couldn't load your cycle insights.",
          onRetry: () => ref.invalidate(cycleInsightsProvider(range)),
        ),
        data: (insights) {
          if (!insights.hasAnyCycleHistory) {
            return const _EmptyInsightsState();
          }
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _RangeSelector(
                selected: range,
                trackedCycles: insights.trackedCycleCount,
                onChanged: (value) =>
                    ref.read(cycleInsightsRangeProvider.notifier).state = value,
              ),
              const SizedBox(height: 14),
              if (insights.isLowHistory) _LearningCard(insights: insights),
              _CycleOverview(insights: insights),
              if (insights.cycleLengths.length > 1) ...[
                const SizedBox(height: 14),
                _CycleTrend(insights: insights),
              ],
              const SizedBox(height: 14),
              _PeriodDurationCard(insights: insights),
              const SizedBox(height: 14),
              _PatternsSection(insights: insights),
              const SizedBox(height: 14),
              _NoticedSection(insights: insights),
            ],
          );
        },
      ),
    );
  }
}

class _RangeSelector extends StatelessWidget {
  final CycleInsightRange selected;
  final int trackedCycles;
  final ValueChanged<CycleInsightRange> onChanged;

  const _RangeSelector({
    required this.selected,
    required this.trackedCycles,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final options = CycleInsightRange.values.where((range) {
      final limit = range.cycleLimit;
      return limit == null || trackedCycles >= limit || range == selected;
    }).toList();

    return Align(
      alignment: Alignment.centerLeft,
      child: DropdownButton<CycleInsightRange>(
        value: selected,
        items: [
          for (final option in options)
            DropdownMenuItem(value: option, child: Text(option.label)),
        ],
        onChanged: (value) {
          if (value != null) onChanged(value);
        },
      ),
    );
  }
}

class _LearningCard extends StatelessWidget {
  final CycleInsightsResult insights;

  const _LearningCard({required this.insights});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Quevaa is learning your patterns',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                "You've logged ${insights.periodCount} period record${insights.periodCount == 1 ? '' : 's'} so far. Cycle insights become more useful as you continue tracking.",
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Chip('${insights.periodCount} period records'),
                  _Chip(
                    '${insights.energyPattern.observationCount} daily check-ins',
                  ),
                  _Chip(
                    '${insights.symptomPatterns.fold<int>(0, (sum, item) => sum + item.loggedDays)} symptom logs',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CycleOverview extends StatelessWidget {
  final CycleInsightsResult insights;

  const _CycleOverview({required this.insights});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.deepPlum,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your cycle',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.terracottaLight,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _DarkStat('Average cycle', insights.averageCycleLabel),
                _DarkStat('Typical period', insights.averagePeriodLabel),
                _DarkStat('Recent range', insights.cycleRangeLabel),
                _DarkStat('Pattern', insights.regularityLabel),
                _DarkStat('Tracked cycles', '${insights.trackedCycleCount}'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CycleTrend extends StatelessWidget {
  final CycleInsightsResult insights;

  const _CycleTrend({required this.insights});

  @override
  Widget build(BuildContext context) {
    final maxValue = insights.cycleLengths
        .map((point) => point.lengthDays)
        .reduce((a, b) => a > b ? a : b);
    final dateFormat = DateFormat('MMM d');
    return _Section(
      title: 'Cycle length trend',
      children: [
        for (final point in insights.cycleLengths)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                SizedBox(width: 88, child: Text('Cycle ${point.cycleNumber}')),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      minHeight: 10,
                      value: point.lengthDays / maxValue,
                      backgroundColor: AppColors.terracottaContainer,
                      color: AppColors.terracottaPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 86,
                  child: Text(
                    '${point.lengthDays} days',
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
          ),
        Text(
          'Based on period starts from ${dateFormat.format(insights.cycleLengths.first.startDate)} to ${dateFormat.format(insights.cycleLengths.last.startDate)}.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _PeriodDurationCard extends StatelessWidget {
  final CycleInsightsResult insights;

  const _PeriodDurationCard({required this.insights});

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Period duration',
      children: [
        Text('Typical period: ${insights.averagePeriodLabel}'),
        const SizedBox(height: 8),
        if (insights.periodDurations.isEmpty)
          const Text('Period duration appears after completed period records.')
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final duration in insights.periodDurations)
                _Chip('$duration days'),
            ],
          ),
      ],
    );
  }
}

class _PatternsSection extends StatelessWidget {
  final CycleInsightsResult insights;

  const _PatternsSection({required this.insights});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your patterns',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 10),
        _MetricCard(pattern: insights.energyPattern),
        _MetricCard(pattern: insights.painPattern),
        _MetricCard(pattern: insights.sleepPattern),
        _TextPatternCard(pattern: insights.moodPattern),
        _TextPatternCard(pattern: insights.stressPattern),
        _ProductivityCard(pattern: insights.productivityPattern),
        if (insights.ttcPattern != null)
          _TtcCard(pattern: insights.ttcPattern!),
        _SymptomPatterns(patterns: insights.symptomPatterns),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final MetricPattern pattern;

  const _MetricCard({required this.pattern});

  @override
  Widget build(BuildContext context) {
    return _CompactPanel(
      title: pattern.name,
      body: pattern.summary,
      footer: pattern.explanation,
      trailing: pattern.average?.toStringAsFixed(1),
    );
  }
}

class _TextPatternCard extends StatelessWidget {
  final TextPattern pattern;

  const _TextPatternCard({required this.pattern});

  @override
  Widget build(BuildContext context) {
    return _CompactPanel(
      title: pattern.name,
      body: pattern.summary,
      footer: pattern.explanation,
    );
  }
}

class _ProductivityCard extends StatelessWidget {
  final ProductivityPattern pattern;

  const _ProductivityCard({required this.pattern});

  @override
  Widget build(BuildContext context) {
    return _CompactPanel(
      title: 'Productivity',
      body: pattern.summary,
      footer: pattern.explanation,
    );
  }
}

class _TtcCard extends StatelessWidget {
  final TtcPattern pattern;

  const _TtcCard({required this.pattern});

  @override
  Widget build(BuildContext context) {
    return _CompactPanel(
      title: 'TTC observations',
      body: pattern.summary,
      footer:
          'TTC insights are shown only when Trying to Conceive Mode is enabled.',
    );
  }
}

class _SymptomPatterns extends StatelessWidget {
  final List<SymptomPattern> patterns;

  const _SymptomPatterns({required this.patterns});

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Symptoms',
      children: [
        if (patterns.isEmpty)
          const Text('Symptom patterns will appear after symptom logs.')
        else
          for (final pattern in patterns)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(pattern.symptom),
              subtitle: Text(
                '${pattern.timingSummary}. ${pattern.explanation}',
              ),
              trailing: Text('${pattern.loggedDays} days'),
            ),
      ],
    );
  }
}

class _NoticedSection extends StatelessWidget {
  final CycleInsightsResult insights;

  const _NoticedSection({required this.insights});

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Quevaa has noticed',
      children: [
        if (insights.personalInsights.isEmpty)
          const Text('Personal insights will appear as your history grows.')
        else
          for (final insight in insights.personalInsights)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.auto_graph_rounded,
                    color: AppColors.sagePrimary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(insight)),
                ],
              ),
            ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _CompactPanel extends StatelessWidget {
  final String title;
  final String body;
  final String footer;
  final String? trailing;

  const _CompactPanel({
    required this.title,
    required this.body,
    required this.footer,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(
            color: AppColors.sagePrimary.withValues(alpha: 0.2),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Text(body),
                    const SizedBox(height: 6),
                    Text(footer, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 12),
                Text(
                  trailing!,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppColors.terracottaPrimary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DarkStat extends StatelessWidget {
  final String label;
  final String value;

  const _DarkStat(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 138,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;

  const _Chip(this.label);

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      backgroundColor: AppColors.terracottaContainer.withValues(alpha: 0.45),
      side: BorderSide.none,
    );
  }
}

class _EmptyInsightsState extends StatelessWidget {
  const _EmptyInsightsState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.insights_rounded,
              color: AppColors.sagePrimary,
              size: 52,
            ),
            const SizedBox(height: 12),
            Text(
              'Quevaa is learning your patterns',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Log at least one period to begin building your private cycle insights.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
