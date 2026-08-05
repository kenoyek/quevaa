import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/database/app_database.dart';
import '../../../conception/application/conception_settings_provider.dart';
import '../../application/cycle_workspace_provider.dart';

class CycleWorkspacePage extends ConsumerWidget {
  const CycleWorkspacePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final output = ref.watch(currentCycleOutputProvider);
    final view = ref.watch(cycleCalendarViewProvider).valueOrNull ?? 'Month';
    final logs = ref.watch(cycleLogsInRangeProvider);
    final symptoms = ref.watch(symptomsInRangeProvider);
    final periods = ref.watch(periodHistoryProvider).valueOrNull ?? const [];
    final ttcEnabled = ref.watch(conceptionModeActiveProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgWarmDark : AppColors.bgWarmCream,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(cycleLogsInRangeProvider);
            ref.invalidate(periodHistoryProvider);
          },
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                sliver: SliverToBoxAdapter(
                  child: _CycleHeader(
                    view: view,
                    onViewChanged: (value) => ref
                        .read(cycleWorkspaceControllerProvider.notifier)
                        .setCalendarView(value),
                    onQuickLog: () => _showQuickLogSheet(
                      context,
                      ref,
                      ref.read(selectedCycleDateProvider),
                    ),
                    cycleDay: output.currentCycleDay,
                    phase: output.estimatedPhase,
                    confidence: output.confidence.name,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                sliver: SliverToBoxAdapter(
                  child: _OverviewCards(output: output, periods: periods),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                sliver: SliverToBoxAdapter(
                  child: _CalendarLegend(ttcEnabled: ttcEnabled),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                sliver: SliverToBoxAdapter(
                  child: logs.when(
                    data: (dailyLogs) => symptoms.when(
                      data: (symptomRows) => _CycleCalendar(
                        view: view,
                        dailyLogs: dailyLogs,
                        symptoms: symptomRows,
                        periods: periods,
                        ttcEnabled: ttcEnabled,
                        onSelectDate: (date) {
                          ref.read(selectedCycleDateProvider.notifier).state =
                              date;
                          _showDayDetails(context, ref, date);
                        },
                      ),
                      loading: () => const _LoadingPanel(),
                      error: (error, stack) => const _ErrorPanel(
                        message: 'Cycle symptoms could not be loaded.',
                      ),
                    ),
                    loading: () => const _LoadingPanel(),
                    error: (error, stack) => const _ErrorPanel(
                      message: 'Cycle calendar could not be loaded.',
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                sliver: SliverToBoxAdapter(
                  child: _CycleInsights(
                    periods: periods,
                    logs: logs.valueOrNull ?? const [],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CycleHeader extends StatelessWidget {
  final String view;
  final ValueChanged<String> onViewChanged;
  final VoidCallback onQuickLog;
  final int cycleDay;
  final String phase;
  final String confidence;

  const _CycleHeader({
    required this.view,
    required this.onViewChanged,
    required this.onQuickLog,
    required this.cycleDay,
    required this.phase,
    required this.confidence,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardSurfaceDark : AppColors.cardSurfaceLight,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Cycle', style: theme.textTheme.displaySmall),
              ),
              FilledButton.icon(
                onPressed: onQuickLog,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Quick log'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('Cycle Day $cycleDay', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 4),
          Text(
            'Estimated ${phase.toLowerCase()} phase',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'Prediction confidence: ${_titleCase(confidence)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 16),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'Month',
                label: Text('Month'),
                icon: Icon(Icons.calendar_month_rounded),
              ),
              ButtonSegment(
                value: 'Three months',
                label: Text('3 mo'),
                icon: Icon(Icons.view_week_rounded),
              ),
              ButtonSegment(
                value: 'Year',
                label: Text('Year'),
                icon: Icon(Icons.grid_view_rounded),
              ),
            ],
            selected: {view},
            onSelectionChanged: (selection) => onViewChanged(selection.first),
          ),
        ],
      ),
    );
  }
}

class _OverviewCards extends StatelessWidget {
  final dynamic output;
  final List<CyclePeriod> periods;

  const _OverviewCards({required this.output, required this.periods});

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('d MMM');
    final enough = periods.length >= 2;
    final lastThree = <int>[];
    for (var i = 0; i < periods.length - 1; i++) {
      lastThree.add(
        periods[i + 1].startDate.difference(periods[i].startDate).inDays,
      );
    }
    final recent = lastThree.reversed.take(3).toList().reversed.toList();
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.45,
      ),
      children: [
        _InfoCard(
          icon: Icons.event_available_rounded,
          title: 'Next period',
          body:
              'Estimated ${date.format(output.estimatedPeriodStartMin)}-${date.format(output.estimatedPeriodStartMax)}',
          foot: 'Confidence: ${_titleCase(output.confidence.name)}',
        ),
        _InfoCard(
          icon: Icons.timeline_rounded,
          title: 'Current cycle',
          body: 'Day ${output.currentCycleDay}',
          foot: 'Estimated ${output.medianCycleLength.round()}-day cycle',
        ),
        _InfoCard(
          icon: Icons.insights_rounded,
          title: 'Typical cycle',
          body: enough
              ? '${output.averageCycleLength.round()} days average'
              : 'More logs needed',
          foot: enough
              ? 'Variation: ${output.cycleLengthVariability.toStringAsFixed(1)}'
              : 'Add at least 2 periods',
        ),
        _InfoCard(
          icon: Icons.history_rounded,
          title: 'Recent pattern',
          body: recent.isEmpty ? 'No completed cycles yet' : recent.join(', '),
          foot: recent.isEmpty
              ? 'Start with your latest period'
              : 'Last ${recent.length} cycle lengths',
        ),
      ],
    );
  }
}

class _CycleCalendar extends ConsumerWidget {
  final String view;
  final List<DailyLog> dailyLogs;
  final List<SymptomEntry> symptoms;
  final List<CyclePeriod> periods;
  final bool ttcEnabled;
  final ValueChanged<DateTime> onSelectDate;

  const _CycleCalendar({
    required this.view,
    required this.dailyLogs,
    required this.symptoms,
    required this.periods,
    required this.ttcEnabled,
    required this.onSelectDate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visibleMonth = ref.watch(visibleCycleMonthProvider);
    final selected = ref.watch(selectedCycleDateProvider);
    final output = ref.watch(currentCycleOutputProvider);
    final monthCount = switch (view) {
      'Three months' => 3,
      'Year' => 12,
      _ => 1,
    };
    return Column(
      children: [
        _CalendarToolbar(
          month: visibleMonth,
          showYearJump: view == 'Year',
          onToday: () {
            final now = DateTime.now();
            ref.read(visibleCycleMonthProvider.notifier).state = DateTime(
              now.year,
              now.month,
            );
            ref.read(selectedCycleDateProvider.notifier).state = normalizeDate(
              now,
            );
          },
          onPrevious: () => ref.read(visibleCycleMonthProvider.notifier).state =
              DateTime(visibleMonth.year, visibleMonth.month - monthCount),
          onNext: () => ref.read(visibleCycleMonthProvider.notifier).state =
              DateTime(visibleMonth.year, visibleMonth.month + monthCount),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onHorizontalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0;
            if (velocity.abs() < 150) return;
            ref.read(visibleCycleMonthProvider.notifier).state = DateTime(
              visibleMonth.year,
              visibleMonth.month + (velocity < 0 ? monthCount : -monthCount),
            );
          },
          child: Column(
            children: [
              for (var index = 0; index < monthCount; index++)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: index == monthCount - 1 ? 0 : 16,
                  ),
                  child: _MonthGrid(
                    month: DateTime(
                      visibleMonth.year,
                      visibleMonth.month + index,
                    ),
                    selected: selected,
                    dailyLogs: dailyLogs,
                    symptoms: symptoms,
                    periods: periods,
                    output: output,
                    ttcEnabled: ttcEnabled,
                    onSelectDate: onSelectDate,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MonthGrid extends StatelessWidget {
  final DateTime month;
  final DateTime selected;
  final List<DailyLog> dailyLogs;
  final List<SymptomEntry> symptoms;
  final List<CyclePeriod> periods;
  final dynamic output;
  final bool ttcEnabled;
  final ValueChanged<DateTime> onSelectDate;

  const _MonthGrid({
    required this.month,
    required this.selected,
    required this.dailyLogs,
    required this.symptoms,
    required this.periods,
    required this.output,
    required this.ttcEnabled,
    required this.onSelectDate,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final firstDayOffset = localizations.firstDayOfWeekIndex;
    final first = DateTime(month.year, month.month);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leading = (first.weekday % 7 - firstDayOffset) % 7;
    final cellCount = ((leading + daysInMonth) / 7).ceil() * 7;
    final logsByDate = {
      for (final log in dailyLogs) normalizeDate(log.date): log,
    };
    final symptomsByDate = <DateTime, List<SymptomEntry>>{};
    for (final symptom in symptoms) {
      symptomsByDate
          .putIfAbsent(normalizeDate(symptom.date), () => [])
          .add(symptom);
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _panelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat.yMMMM().format(month),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Center(
                    child: Text(
                      localizations.narrowWeekdays[(firstDayOffset + i) % 7],
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cellCount,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
            ),
            itemBuilder: (context, index) {
              final dayNumber = index - leading + 1;
              if (dayNumber < 1 || dayNumber > daysInMonth) {
                return const SizedBox.shrink();
              }
              final date = DateTime(month.year, month.month, dayNumber);
              final log = logsByDate[date];
              final daySymptoms = symptomsByDate[date] ?? const [];
              final state = _calendarState(
                date,
                periods,
                output,
                ttcEnabled,
                log,
                daySymptoms,
              );
              return _DayCell(
                date: date,
                selected: _sameDate(date, selected),
                state: state,
                onTap: () => onSelectDate(date),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  final DateTime date;
  final bool selected;
  final _CalendarDayState state;
  final VoidCallback onTap;

  const _DayCell({
    required this.date,
    required this.selected,
    required this.state,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final today = _sameDate(date, DateTime.now());
    final bg = state.confirmedPeriod
        ? AppColors.terracottaPrimary
        : state.predictedPeriod
        ? AppColors.terracottaContainer
        : state.fertile
        ? AppColors.sageContainer
        : Colors.transparent;
    final fg = state.confirmedPeriod
        ? Colors.white
        : Theme.of(context).colorScheme.onSurface;
    return Semantics(
      button: true,
      selected: selected,
      label: '${DateFormat.yMMMMd().format(date)}. ${state.semanticLabel}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? AppColors.deepPlum
                  : today
                  ? AppColors.warmGoldPrimary
                  : state.ovulation
                  ? AppColors.purplePrimary
                  : Colors.transparent,
              width: selected ? 2 : 1.4,
            ),
          ),
          child: Stack(
            children: [
              Center(
                child: Text(
                  '${date.day}',
                  style: TextStyle(
                    color: fg,
                    fontWeight: selected || today
                        ? FontWeight.w800
                        : FontWeight.w600,
                  ),
                ),
              ),
              if (state.hasLog)
                const Positioned(
                  right: 5,
                  top: 5,
                  child: Icon(
                    Icons.edit_note_rounded,
                    size: 12,
                    color: AppColors.deepPlum,
                  ),
                ),
              if (state.symptomSeverity > 0)
                Positioned(
                  left: 5,
                  bottom: 5,
                  child: Container(
                    width: 6 + state.symptomSeverity.toDouble(),
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.purplePrimary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              if (state.spotting)
                const Positioned(
                  right: 5,
                  bottom: 5,
                  child: Icon(
                    Icons.circle,
                    size: 7,
                    color: AppColors.terracottaDark,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

void _showDayDetails(BuildContext context, WidgetRef ref, DateTime date) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => Consumer(
      builder: (context, ref, child) {
        final output = ref.watch(currentCycleOutputProvider);
        final log = ref.watch(selectedDayLogProvider).valueOrNull;
        final symptoms =
            ref.watch(selectedDaySymptomsProvider).valueOrNull ?? const [];
        return SafeArea(
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
                    DateFormat.yMMMMEEEEd().format(date),
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  _DetailWrap(
                    items: [
                      'Cycle day ${output.currentCycleDay}',
                      'Estimated ${output.estimatedPhase}',
                      'Confidence ${_titleCase(output.confidence.name)}',
                      log?.flow ?? 'No flow logged',
                      if (log?.spotting ?? false) 'Spotting',
                      if (symptoms.isNotEmpty) '${symptoms.length} symptoms',
                      if ((log?.waterGlasses ?? 0) > 0)
                        '${log!.waterGlasses} glasses water',
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    log?.generalNotes?.isNotEmpty == true
                        ? log!.generalNotes!
                        : 'No private notes for this day yet.',
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        onPressed: () => _showQuickLogSheet(context, ref, date),
                        icon: const Icon(Icons.edit_note_rounded),
                        label: Text(log == null ? 'Log this day' : 'Edit log'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => ref
                            .read(cycleWorkspaceControllerProvider.notifier)
                            .startPeriod(date),
                        icon: const Icon(Icons.water_drop_rounded),
                        label: const Text('Start period'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => ref
                            .read(cycleWorkspaceControllerProvider.notifier)
                            .endLatestPeriod(date),
                        icon: const Icon(Icons.stop_circle_rounded),
                        label: const Text('End period'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => ref
                            .read(cycleWorkspaceControllerProvider.notifier)
                            .saveDailyLog(
                              date: date,
                              flow: 'Spotting',
                              pain: log?.painLevel ?? 0,
                              mood: log?.mood ?? 'Calm',
                              energy: log?.energyLevel ?? 3,
                              stress: log?.stressLevel ?? 2,
                              sleepQuality: log?.sleepQuality ?? 3,
                              water: log?.waterGlasses ?? 0,
                              symptoms: symptoms
                                  .map((e) => e.symptomCategory)
                                  .toList(),
                              notes: log?.generalNotes,
                            ),
                        icon: const Icon(Icons.circle_rounded),
                        label: const Text('Mark spotting'),
                      ),
                      if (log != null)
                        OutlinedButton.icon(
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Delete this daily log?'),
                                content: const Text(
                                  'This removes the symptoms and notes saved for this date. Period history is not deleted.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Keep'),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed == true) {
                              await ref
                                  .read(
                                    cycleWorkspaceControllerProvider.notifier,
                                  )
                                  .deleteSelectedLog(date);
                              if (context.mounted) Navigator.pop(context);
                            }
                          },
                          icon: const Icon(Icons.delete_outline_rounded),
                          label: const Text('Delete log'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

void _showQuickLogSheet(BuildContext context, WidgetRef ref, DateTime date) {
  final formKey = GlobalKey<FormState>();
  var flow = 'None';
  var pain = 0.0;
  var energy = 3.0;
  var stress = 2.0;
  var sleep = 3.0;
  var water = 0.0;
  var mood = 'Calm';
  final notes = TextEditingController();
  final symptoms = <String>{};
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
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Quick log',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(DateFormat.yMMMMEEEEd().format(date)),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: flow,
                    decoration: const InputDecoration(labelText: 'Flow'),
                    items:
                        const [
                              'None',
                              'Spotting',
                              'Light',
                              'Medium',
                              'Heavy',
                              'Very heavy',
                            ]
                            .map(
                              (item) => DropdownMenuItem(
                                value: item,
                                child: Text(item),
                              ),
                            )
                            .toList(),
                    onChanged: (value) => setState(() => flow = value ?? flow),
                  ),
                  _SliderRow(
                    label: 'Pain',
                    value: pain,
                    max: 5,
                    onChanged: (value) => setState(() => pain = value),
                  ),
                  _SliderRow(
                    label: 'Energy',
                    value: energy,
                    min: 1,
                    max: 5,
                    onChanged: (value) => setState(() => energy = value),
                  ),
                  _SliderRow(
                    label: 'Stress',
                    value: stress,
                    max: 5,
                    onChanged: (value) => setState(() => stress = value),
                  ),
                  _SliderRow(
                    label: 'Sleep quality',
                    value: sleep,
                    min: 1,
                    max: 5,
                    onChanged: (value) => setState(() => sleep = value),
                  ),
                  _SliderRow(
                    label: 'Water',
                    value: water,
                    max: 12,
                    onChanged: (value) => setState(() => water = value),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: mood,
                    decoration: const InputDecoration(labelText: 'Mood'),
                    items:
                        const [
                              'Calm',
                              'Happy',
                              'Motivated',
                              'Focused',
                              'Irritable',
                              'Anxious',
                              'Sad',
                              'Sensitive',
                              'Overwhelmed',
                            ]
                            .map(
                              (item) => DropdownMenuItem(
                                value: item,
                                child: Text(item),
                              ),
                            )
                            .toList(),
                    onChanged: (value) => setState(() => mood = value ?? mood),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Symptoms',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final symptom in const [
                        'Cramps',
                        'Headache',
                        'Back pain',
                        'Bloating',
                        'Fatigue',
                        'Acne',
                        'Nausea',
                        'Breast tenderness',
                        'Digestive changes',
                      ])
                        FilterChip(
                          label: Text(symptom),
                          selected: symptoms.contains(symptom),
                          onSelected: (selected) => setState(
                            () => selected
                                ? symptoms.add(symptom)
                                : symptoms.remove(symptom),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: notes,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Private notes',
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () async {
                        await ref
                            .read(cycleWorkspaceControllerProvider.notifier)
                            .saveDailyLog(
                              date: date,
                              flow: flow,
                              pain: pain.round(),
                              mood: mood,
                              energy: energy.round(),
                              stress: stress.round(),
                              sleepQuality: sleep.round(),
                              water: water.round(),
                              symptoms: symptoms.toList(),
                              notes: notes.text,
                            );
                        if (context.mounted) Navigator.pop(context);
                      },
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Save log'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  ).whenComplete(notes.dispose);
}

class _CycleInsights extends StatelessWidget {
  final List<CyclePeriod> periods;
  final List<DailyLog> logs;

  const _CycleInsights({required this.periods, required this.logs});

  @override
  Widget build(BuildContext context) {
    final insights = <String>[];
    if (periods.length >= 3) {
      final lengths = [
        for (var i = 0; i < periods.length - 1; i++)
          periods[i + 1].startDate.difference(periods[i].startDate).inDays,
      ];
      final avg = lengths.reduce((a, b) => a + b) / lengths.length;
      insights.add(
        'Your logged cycles average ${avg.round()} days across ${lengths.length} completed intervals.',
      );
    }
    final painful = logs.where((log) => log.painLevel >= 3).length;
    if (logs.length >= 4 && painful > 0) {
      insights.add(
        'Moderate or stronger pain was recorded on $painful of your recent logged days.',
      );
    }
    final symptomCounts = <String, int>{};
    for (final log in logs) {
      for (final item
          in (jsonDecode(log.customSymptomsJson) as List<dynamic>)
              .cast<String>()) {
        symptomCounts[item] = (symptomCounts[item] ?? 0) + 1;
      }
    }
    if (symptomCounts.isNotEmpty) {
      final top = symptomCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      insights.add(
        '${top.first.key} is your most frequently logged symptom in this view.',
      );
    }
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cycle insights',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 10),
          if (insights.isEmpty)
            const Text(
              'Start by recording the first day of your latest period and a few daily logs. Quevaa will show transparent patterns once there is enough local history.',
            )
          else
            for (final insight in insights)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.insights_rounded,
                      size: 18,
                      color: AppColors.sagePrimary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(insight)),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final String foot;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.foot,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _panelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.terracottaPrimary),
          const Spacer(),
          Text(title, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(
            body,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            foot,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _CalendarToolbar extends StatelessWidget {
  final DateTime month;
  final bool showYearJump;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;

  const _CalendarToolbar({
    required this.month,
    required this.showYearJump,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left_rounded),
          tooltip: 'Previous',
        ),
        Expanded(
          child: Center(
            child: Text(
              DateFormat.yMMM().format(month),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ),
        TextButton(onPressed: onToday, child: const Text('Today')),
        IconButton(
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right_rounded),
          tooltip: 'Next',
        ),
      ],
    );
  }
}

class _CalendarLegend extends StatelessWidget {
  final bool ttcEnabled;

  const _CalendarLegend({required this.ttcEnabled});

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        Icons.water_drop_rounded,
        'Confirmed period',
        AppColors.terracottaPrimary,
      ),
      (Icons.trip_origin_rounded, 'Predicted range', AppColors.terracottaDark),
      (Icons.eco_rounded, 'Fertile window', AppColors.sagePrimary),
      (
        Icons.radio_button_checked_rounded,
        'Estimated ovulation',
        AppColors.purplePrimary,
      ),
      (Icons.edit_note_rounded, 'Log', AppColors.deepPlum),
      if (ttcEnabled)
        (Icons.science_rounded, 'TTC signs', AppColors.warmGoldPrimary),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final item in items)
          Chip(
            avatar: Icon(item.$1, size: 16, color: item.$3),
            label: Text(item.$2),
          ),
      ],
    );
  }
}

class _DetailWrap extends StatelessWidget {
  final List<String> items;

  const _DetailWrap({required this.items});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [for (final item in items) Chip(label: Text(item))],
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.label,
    required this.value,
    this.min = 0,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 92, child: Text(label)),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: (max - min).round(),
            label: value.round().toString(),
            onChanged: onChanged,
          ),
        ),
        SizedBox(width: 26, child: Text(value.round().toString())),
      ],
    );
  }
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      decoration: _panelDecoration(context),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  final String message;

  const _ErrorPanel({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _panelDecoration(context),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.terracottaPrimary,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

_CalendarDayState _calendarState(
  DateTime date,
  List<CyclePeriod> periods,
  dynamic output,
  bool ttcEnabled,
  DailyLog? log,
  List<SymptomEntry> symptoms,
) {
  final confirmedPeriod = periods.any((period) {
    final start = normalizeDate(period.startDate);
    final end = normalizeDate(period.endDate ?? DateTime.now());
    return !date.isBefore(start) && !date.isAfter(end);
  });
  final predictedPeriod =
      !date.isBefore(normalizeDate(output.estimatedPeriodStartMin)) &&
      !date.isAfter(normalizeDate(output.estimatedPeriodStartMax));
  final fertile =
      ttcEnabled &&
      !date.isBefore(normalizeDate(output.fertileWindowStart)) &&
      !date.isAfter(normalizeDate(output.fertileWindowEnd));
  final ovulation =
      ttcEnabled &&
      !date.isBefore(normalizeDate(output.estimatedOvulationStart)) &&
      !date.isAfter(normalizeDate(output.estimatedOvulationEnd));
  final severity = [
    if (log != null) log.painLevel,
    ...symptoms.map((symptom) => symptom.severity),
  ].fold<int>(0, (max, value) => value > max ? value : max);
  final labels = [
    if (confirmedPeriod) 'confirmed period',
    if (predictedPeriod) 'predicted period range',
    if (fertile) 'estimated fertile window',
    if (ovulation) 'estimated ovulation range',
    if (log != null) 'daily log saved',
    if (severity > 0) 'symptom severity $severity',
  ];
  return _CalendarDayState(
    confirmedPeriod: confirmedPeriod,
    predictedPeriod: predictedPeriod,
    fertile: fertile,
    ovulation: ovulation,
    hasLog: log != null,
    spotting: log?.spotting ?? false,
    symptomSeverity: severity,
    semanticLabel: labels.isEmpty ? 'No records.' : labels.join(', '),
  );
}

class _CalendarDayState {
  final bool confirmedPeriod;
  final bool predictedPeriod;
  final bool fertile;
  final bool ovulation;
  final bool hasLog;
  final bool spotting;
  final int symptomSeverity;
  final String semanticLabel;

  const _CalendarDayState({
    required this.confirmedPeriod,
    required this.predictedPeriod,
    required this.fertile,
    required this.ovulation,
    required this.hasLog,
    required this.spotting,
    required this.symptomSeverity,
    required this.semanticLabel,
  });
}

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

bool _sameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _titleCase(String value) => value.isEmpty
    ? value
    : '${value[0].toUpperCase()}${value.substring(1).toLowerCase()}';
