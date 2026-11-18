import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../app/theme/app_colors.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/models/prediction_confidence.dart';
import '../../../conception/application/conception_settings_provider.dart';
import '../../application/cycle_workspace_provider.dart';
import '../../domain/cycle_engine.dart';
import '../../domain/models/cycle_calendar_phase.dart';
import '../../domain/models/cycle_engine_output.dart';
import '../../domain/models/period_prediction.dart';

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

    final selected = ref.watch(selectedCycleDateProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgWarmDark : const Color(0xFFFCF7F9),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final inset = width > 672 ? (width - 640) / 2 : 16.0;
            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(cycleLogsInRangeProvider);
                ref.invalidate(symptomsInRangeProvider);
                ref.invalidate(periodHistoryProvider);
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(inset, 20, inset, 12),
                    sliver: SliverToBoxAdapter(
                      child: _CycleHeader(
                        output: output,
                        onQuickLog: () =>
                            _showQuickLogSheet(context, ref, selected),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(inset, 0, inset, 16),
                    sliver: SliverToBoxAdapter(
                      child: _CycleCalendar(
                        view: view,
                        dailyLogs: logs.valueOrNull ?? const [],
                        symptoms: symptoms.valueOrNull ?? const [],
                        periods: periods,
                        ttcEnabled: ttcEnabled,
                        onViewChanged: (value) => ref
                            .read(cycleWorkspaceControllerProvider.notifier)
                            .setCalendarView(value),
                        onSelectDate: (date) {
                          ref.read(selectedCycleDateProvider.notifier).state =
                              date;
                          _showDayDetails(context, ref, date);
                        },
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(inset, 0, inset, 16),
                    sliver: SliverToBoxAdapter(
                      child: _OverviewCards(output: output, periods: periods),
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(inset, 0, inset, 100),
                    sliver: SliverToBoxAdapter(
                      child: _CycleInsights(
                        periods: periods,
                        logs: logs.valueOrNull ?? const [],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CycleHeader extends StatelessWidget {
  const _CycleHeader({required this.output, required this.onQuickLog});

  final CycleEngineOutput output;
  final VoidCallback onQuickLog;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final prediction = output.periodPredictions.firstOrNull;
    final phase = output.estimatedPhase.toLowerCase();
    final phaseLabel = phase.startsWith('estimated')
        ? output.estimatedPhase
        : 'Estimated $phase phase';
    final format = DateFormat.MMMd(Localizations.localeOf(context).toString());
    final nextPeriod = prediction == null
        ? null
        : '${format.format(prediction.predictedBleedingRange.start)} – '
              '${format.format(prediction.predictedBleedingRange.end)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text('Cycle', style: theme.textTheme.displaySmall),
              ),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF773D5B),
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 48),
              ),
              onPressed: onQuickLog,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Quick log'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF482538), Color(0xFF733D59)],
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nextPeriod == null
                          ? 'Cycle overview'
                          : 'Next period · estimated',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: const Color(0xFFFFDDE9),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      nextPeriod ?? 'Start tracking your cycle',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      output.hasEnoughData
                          ? 'Cycle day ${output.currentCycleDay} · ${formatPredictionConfidence(output.confidence)} confidence'
                          : 'Log a period to start seeing estimates.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFFFFEAF1),
                      ),
                    ),
                    if (output.hasEnoughData) ...[
                      const SizedBox(height: 2),
                      Text(
                        phaseLabel,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFFFFDDE9),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const CircleAvatar(
                radius: 22,
                backgroundColor: Color(0x33FFFFFF),
                foregroundColor: Color(0xFFFFDDE9),
                child: Icon(Icons.water_drop_outlined, size: 22),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OverviewCards extends StatelessWidget {
  final CycleEngineOutput output;
  final List<CyclePeriod> periods;

  const _OverviewCards({required this.output, required this.periods});

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('d MMM');
    final primaryPred = output.periodPredictions.firstOrNull;
    final enough = output.hasEnoughData && periods.length >= 2;

    final possibleStart = primaryPred == null
        ? null
        : '${df.format(primaryPred.possibleStartRange.start)} – '
              '${df.format(primaryPred.possibleStartRange.end)}';
    final lastThree = <int>[];
    for (var i = 0; i < periods.length - 1; i++) {
      lastThree.add(
        periods[i + 1].startDate.difference(periods[i].startDate).inDays,
      );
    }
    final recent = lastThree.reversed.take(3).toList().reversed.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (primaryPred != null) ...[
          _InfoCard(
            icon: Icons.event_available_outlined,
            title: 'Period estimates',
            body: 'Possible start: $possibleStart',
            foot:
                'Estimated bleeding duration: ${primaryPred.expectedDurationDays} days',
          ),
          const SizedBox(height: 10),
        ],
        _InfoCard(
          icon: Icons.insights_rounded,
          title: 'Typical cycle',
          body: enough
              ? '${output.averageCycleLength.round()} days average'
              : 'Based on cycle settings',
          foot: enough
              ? 'Variation: ${output.cycleLengthVariability.toStringAsFixed(1)}'
              : 'Predictions will improve as you log more periods',
        ),
        const SizedBox(height: 10),
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
  final ValueChanged<String> onViewChanged;

  const _CycleCalendar({
    required this.view,
    required this.dailyLogs,
    required this.symptoms,
    required this.periods,
    required this.ttcEnabled,
    required this.onSelectDate,
    required this.onViewChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final visibleMonth = ref.watch(visibleCycleMonthProvider);
    final selected = ref.watch(selectedCycleDateProvider);
    final output = ref.watch(currentCycleOutputProvider);
    final today = ref.watch(localTodayProvider);
    final monthCount = switch (view) {
      'Three months' => 3,
      'Year' => 12,
      _ => 1,
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
      decoration: _panelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<String>(
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (!states.contains(WidgetState.selected)) return null;
                return dark ? const Color(0xFF533346) : const Color(0xFFF3DDE7);
              }),
              foregroundColor: WidgetStatePropertyAll(
                theme.colorScheme.onSurface,
              ),
              side: WidgetStatePropertyAll(
                BorderSide(
                  color: dark ? AppColors.borderDark : AppColors.borderLight,
                ),
              ),
              minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
            ),
            segments: const [
              ButtonSegment(value: 'Month', label: Text('Month')),
              ButtonSegment(value: 'Three months', label: Text('3 months')),
              ButtonSegment(value: 'Year', label: Text('Year')),
            ],
            selected: {view},
            showSelectedIcon: false,
            onSelectionChanged: (selection) => onViewChanged(selection.first),
          ),
          const SizedBox(height: 8),
          _CalendarToolbar(
            month: visibleMonth,
            monthCount: monthCount,
            onToday: () {
              final now = today;
              ref.read(visibleCycleMonthProvider.notifier).state = DateTime(
                now.year,
                now.month,
              );
              ref.read(selectedCycleDateProvider.notifier).state =
                  normalizeDate(now);
            },
            onPrevious: () =>
                ref.read(visibleCycleMonthProvider.notifier).state = DateTime(
                  visibleMonth.year,
                  visibleMonth.month - monthCount,
                ),
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
                visibleMonth.month +
                    ((velocity < 0) ==
                            (Directionality.of(context) == TextDirection.ltr)
                        ? monthCount
                        : -monthCount),
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
                      today: today,
                      showTitle: monthCount > 1,
                      dailyLogs: dailyLogs,
                      symptoms: symptoms,
                      periods: periods,
                      output: output,
                      onSelectDate: onSelectDate,
                    ),
                  ),
              ],
            ),
          ),
          _CalendarLegend(ttcEnabled: ttcEnabled),
        ],
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  final DateTime month;
  final DateTime selected;
  final DateTime today;
  final bool showTitle;
  final List<DailyLog> dailyLogs;
  final List<SymptomEntry> symptoms;
  final List<CyclePeriod> periods;
  final CycleEngineOutput output;
  final ValueChanged<DateTime> onSelectDate;

  const _MonthGrid({
    required this.month,
    required this.selected,
    required this.today,
    required this.showTitle,
    required this.dailyLogs,
    required this.symptoms,
    required this.periods,
    required this.output,
    required this.onSelectDate,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final firstDayOffset = localizations.firstDayOfWeekIndex;
    final locale = Localizations.localeOf(context).toString();
    final shortWeekday = DateFormat.E(locale);
    final fullWeekday = DateFormat.EEEE(locale);
    final weekdays = [
      for (var i = 0; i < 7; i++)
        DateTime.utc(2024, 1, 7 + (firstDayOffset + i) % 7),
    ];
    final first = DateTime(month.year, month.month);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leading = ((first.weekday % 7 - firstDayOffset) % 7 + 7) % 7;
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTitle) ...[
          Text(
            localizations.formatMonthYear(month),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
        ],
        Row(
          children: [
            for (final weekday in weekdays)
              Expanded(
                child: Semantics(
                  label: fullWeekday.format(weekday),
                  excludeSemantics: true,
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        shortWeekday.format(weekday),
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
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
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
            mainAxisExtent: 50,
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
              today,
              log,
              daySymptoms,
            );
            return _DayCell(
              date: date,
              selected: _sameDate(date, selected),
              today: _sameDate(date, today),
              state: state,
              onTap: () => onSelectDate(date),
            );
          },
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.selected,
    required this.today,
    required this.state,
    required this.onTap,
  });

  final DateTime date;
  final bool selected;
  final bool today;
  final _CalendarDayState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final localizations = MaterialLocalizations.of(context);
    final background = state.confirmedPeriod
        ? (dark ? const Color(0xFF813A59) : const Color(0xFF8E365B))
        : state.predictedPeriod
        ? (dark ? const Color(0xFF512A3D) : const Color(0xFFF7DFE9))
        : switch (state.phase) {
            CycleCalendarPhase.estimatedOvulation =>
              dark
                  ? AppColors.cycleOvulationDark
                  : AppColors.cycleOvulationLight,
            CycleCalendarPhase.fertileWindow =>
              dark
                  ? AppColors.cycleFertileWindowDark
                  : AppColors.cycleFertileWindowLight,
            CycleCalendarPhase.follicular =>
              dark
                  ? AppColors.cycleFollicularDark
                  : AppColors.cycleFollicularLight,
            CycleCalendarPhase.luteal =>
              dark ? AppColors.cycleLutealDark : AppColors.cycleLutealLight,
            CycleCalendarPhase.menstrual =>
              dark
                  ? AppColors.cycleMenstrualPredictedDark
                  : AppColors.cycleMenstrualPredictedLight,
            CycleCalendarPhase.unknown => Colors.transparent,
          };
    final ink = state.confirmedPeriod
        ? Colors.white
        : theme.colorScheme.onSurface;
    final outline = dark ? const Color(0xFFF6AFCB) : const Color(0xFF773D5B);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(selected || today ? 13 : 10),
      side: selected || today
          ? BorderSide(
              color: state.confirmedPeriod && dark ? Colors.white : outline,
              width: selected ? 2 : 1,
            )
          : BorderSide.none,
    );
    final phaseMarker = state.confirmedPeriod
        ? Icons.water_drop_rounded
        : state.predictedPeriod
        ? Icons.water_drop_outlined
        : state.isUncertainty
        ? Icons.more_horiz_rounded
        : switch (state.phase) {
            CycleCalendarPhase.estimatedOvulation =>
              Icons.radio_button_checked_rounded,
            CycleCalendarPhase.fertileWindow => Icons.eco_outlined,
            CycleCalendarPhase.follicular => Icons.circle_outlined,
            CycleCalendarPhase.luteal => Icons.nightlight_outlined,
            _ => null,
          };
    final label =
        '${localizations.formatFullDate(date)}'
        '${today ? ', today' : ''}. ${state.semanticLabel}';

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: background,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                top: 4,
                left: 0,
                right: 0,
                bottom: 16,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${date.day}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: ink,
                      fontWeight: selected || today
                          ? FontWeight.w800
                          : FontWeight.w600,
                      decoration: today ? TextDecoration.underline : null,
                      decorationColor: ink,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 5,
                child: Row(
                  children: [
                    if (phaseMarker != null)
                      Icon(phaseMarker, size: 10, color: ink),
                    if (state.hasLog)
                      Icon(Icons.edit_note_rounded, size: 10, color: ink),
                    if (state.spotting || state.symptomSeverity > 0)
                      Icon(Icons.circle, size: 5, color: ink),
                  ],
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
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (context) => Consumer(
      builder: (context, ref, child) {
        final selectedSnapshot = ref.watch(selectedDayCycleSnapshotProvider);
        final output = ref.watch(currentCycleOutputProvider);
        final log = ref.watch(selectedDayLogProvider).valueOrNull;
        final symptoms =
            ref.watch(selectedDaySymptomsProvider).valueOrNull ?? const [];
        final periods =
            ref.watch(periodHistoryProvider).valueOrNull ?? const [];

        final historyRecords = periods
            .map(
              (p) =>
                  CyclePeriodRecord(startDate: p.startDate, endDate: p.endDate),
            )
            .toList();

        final hasConfirmedPeriodOnDate = periods.any((p) {
          final start = normalizeDate(p.startDate);
          final end = normalizeDate(p.endDate ?? DateTime.now());
          return !date.isBefore(start) && !date.isAfter(end);
        });

        final hasOngoingPeriod = periods.any((p) => p.isOngoing);

        final d = DateTime(date.year, date.month, date.day);
        PeriodPrediction? matchingPred;
        for (final pred in output.periodPredictions) {
          if (pred.isBleedingDay(d)) {
            matchingPred = pred;
            break;
          }
        }

        final phase = output.getCalendarPhase(d, history: historyRecords);

        final detailChips = <String>[];

        if (hasConfirmedPeriodOnDate) {
          detailChips.add('Confirmed Period');
          detailChips.add('Estimated menstrual phase');
        } else if (matchingPred != null) {
          final dayNum =
              d.difference(matchingPred.predictedBleedingRange.start).inDays +
              1;
          detailChips.add('Predicted period day $dayNum');
          detailChips.add('Estimated menstrual phase');
        } else {
          switch (phase) {
            case CycleCalendarPhase.estimatedOvulation:
              detailChips.add('Estimated ovulation');
              detailChips.add('Within your estimated fertile window');
            case CycleCalendarPhase.fertileWindow:
              detailChips.add('Estimated fertile window');
            case CycleCalendarPhase.follicular:
              detailChips.add('Estimated follicular phase');
            case CycleCalendarPhase.luteal:
              detailChips.add('Estimated luteal phase');
            case CycleCalendarPhase.menstrual:
              detailChips.add('Estimated menstrual phase');
            case CycleCalendarPhase.unknown:
              if (selectedSnapshot.hasEnoughData) {
                detailChips.add('Cycle day ${selectedSnapshot.cycleDay}');
              }
          }
        }

        if (selectedSnapshot.hasEnoughData &&
            selectedSnapshot.cycleDay != null) {
          detailChips.add('Cycle day ${selectedSnapshot.cycleDay}');
        }

        detailChips.add(
          'Confidence ${formatPredictionConfidence(output.confidence)}',
        );

        if (log != null && log.flow != 'None') {
          detailChips.add(log.flow);
        }
        if (log?.spotting ?? false) {
          detailChips.add('Spotting');
        }
        if (symptoms.isNotEmpty) {
          detailChips.add('${symptoms.length} symptoms');
        }
        if ((log?.waterGlasses ?? 0) > 0) {
          detailChips.add('${log!.waterGlasses} glasses water');
        }

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
                  _DetailWrap(items: detailChips),
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
                      if (!hasConfirmedPeriodOnDate)
                        OutlinedButton.icon(
                          onPressed: () {
                            ref
                                .read(cycleWorkspaceControllerProvider.notifier)
                                .startPeriod(date);
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.water_drop_rounded),
                          label: const Text('Start period'),
                        ),
                      if (hasOngoingPeriod)
                        OutlinedButton.icon(
                          onPressed: () {
                            ref
                                .read(cycleWorkspaceControllerProvider.notifier)
                                .endLatestPeriod(date);
                            Navigator.pop(context);
                          },
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
                              sleepHours: log?.sleepHours,
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

Future<void> _showQuickLogSheet(
  BuildContext context,
  WidgetRef ref,
  DateTime date,
) async {
  final DailyLog? existing;
  try {
    existing = await ref.read(selectedDayLogProvider.future);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load the selected day.')),
      );
    }
    return;
  }
  if (!context.mounted ||
      !_sameDate(date, ref.read(selectedCycleDateProvider))) {
    return;
  }
  final formKey = GlobalKey<FormState>();
  var flow = existing?.flow ?? 'None';
  if (flow.toLowerCase() == 'very heavy') flow = 'Very Heavy';
  final flows = {
    'None',
    'Spotting',
    'Light',
    'Medium',
    'Heavy',
    'Very Heavy',
    flow,
  };
  var pain = (existing?.painLevel ?? 0).clamp(0, 5).toDouble();
  var energy = (existing?.energyLevel ?? 3).clamp(1, 5).toDouble();
  var stress = (existing?.stressLevel ?? 2).clamp(0, 5).toDouble();
  var sleep = (existing?.sleepQuality ?? 3).clamp(1, 5).toDouble();
  final waterMax = (existing?.waterGlasses ?? 0).clamp(12, 100).toDouble();
  var water = (existing?.waterGlasses ?? 0).clamp(0, waterMax).toDouble();
  var mood = existing?.mood ?? 'Calm';
  final moods = {
    'Calm',
    'Happy',
    'Motivated',
    'Focused',
    'Irritable',
    'Anxious',
    'Sad',
    'Sensitive',
    'Overwhelmed',
    mood,
  };
  final notes = TextEditingController(text: existing?.generalNotes);
  final symptoms = _loggedSymptoms(existing).toSet();
  final symptomChoices = {
    'Cramps',
    'Headache',
    'Back pain',
    'Bloating',
    'Fatigue',
    'Acne',
    'Nausea',
    'Breast tenderness',
    'Digestive changes',
    ...symptoms,
  };
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 560),
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
                    items: flows
                        .map(
                          (item) =>
                              DropdownMenuItem(value: item, child: Text(item)),
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
                    max: waterMax,
                    onChanged: (value) => setState(() => water = value),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: mood,
                    decoration: const InputDecoration(labelText: 'Mood'),
                    items: moods
                        .map(
                          (item) =>
                              DropdownMenuItem(value: item, child: Text(item)),
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
                      for (final symptom in symptomChoices)
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
                              sleepHours: existing?.sleepHours,
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

List<String> _loggedSymptoms(DailyLog? log) {
  if (log == null) return const [];
  try {
    final decoded = jsonDecode(log.customSymptomsJson);
    return decoded is List ? decoded.whereType<String>().toList() : const [];
  } on FormatException {
    return const [];
  }
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
      for (final item in _loggedSymptoms(log)) {
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
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _panelDecoration(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.labelLarge),
                const SizedBox(height: 4),
                Text(body, style: theme.textTheme.titleSmall),
                const SizedBox(height: 3),
                Text(foot, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarToolbar extends StatelessWidget {
  const _CalendarToolbar({
    required this.month,
    required this.monthCount,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
  });

  final DateTime month;
  final int monthCount;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final isLtr = Directionality.of(context) == TextDirection.ltr;
    final interval = switch (monthCount) {
      3 => 'three months',
      12 => 'year',
      _ => 'month',
    };
    final heading = monthCount == 1
        ? localizations.formatMonthYear(month)
        : '${DateFormat.yMMM().format(month)} – '
              '${DateFormat.yMMM().format(DateTime(month.year, month.month + monthCount - 1))}';
    return Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            liveRegion: true,
            child: Text(heading, style: Theme.of(context).textTheme.titleLarge),
          ),
        ),
        TextButton(onPressed: onToday, child: const Text('Today')),
        IconButton(
          onPressed: onPrevious,
          icon: Icon(
            isLtr ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
          ),
          tooltip: 'Previous $interval',
        ),
        IconButton(
          onPressed: onNext,
          icon: Icon(
            isLtr ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
          ),
          tooltip: 'Next $interval',
        ),
      ],
    );
  }
}

class _CalendarLegend extends StatelessWidget {
  const _CalendarLegend({required this.ttcEnabled});

  final bool ttcEnabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final items = [
      (
        Icons.water_drop_rounded,
        'Logged period',
        dark ? const Color(0xFFF6AFCB) : const Color(0xFF8E365B),
      ),
      (
        Icons.water_drop_outlined,
        'Predicted period',
        dark ? const Color(0xFFF6AFCB) : const Color(0xFF8E365B),
      ),
      (
        Icons.more_horiz_rounded,
        'Possible period start',
        theme.colorScheme.onSurface,
      ),
      (
        Icons.eco_outlined,
        'Estimated fertile window',
        dark ? AppColors.sageLight : AppColors.sageDark,
      ),
      (
        Icons.radio_button_checked_rounded,
        'Estimated ovulation',
        dark ? AppColors.warmGoldLight : AppColors.cycleOvulationBorderLight,
      ),
      (
        Icons.circle_outlined,
        'Follicular phase',
        dark ? AppColors.sageLight : AppColors.sageDark,
      ),
      (
        Icons.nightlight_outlined,
        'Luteal phase',
        dark ? const Color(0xFFC4A7D5) : AppColors.purpleLight,
      ),
      (Icons.edit_note_rounded, 'Daily log saved', theme.colorScheme.onSurface),
      (Icons.circle, 'Spotting or symptoms', theme.colorScheme.onSurface),
    ];

    Widget item((IconData, String, Color) entry) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(entry.$1, size: 14, color: entry.$3),
        const SizedBox(width: 4),
        Flexible(child: Text(entry.$2, style: theme.textTheme.bodySmall)),
      ],
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: items.take(2).map(item).toList(),
          ),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 8),
            title: Text('Calendar key', style: theme.textTheme.labelLarge),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            shape: const Border(),
            collapsedShape: const Border(),
            children: [
              Wrap(
                spacing: 14,
                runSpacing: 8,
                children: items.skip(2).map(item).toList(),
              ),
              if (ttcEnabled)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Tap a date to see cycle and fertility details.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ],
      ),
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

_CalendarDayState _calendarState(
  DateTime date,
  List<CyclePeriod> periods,
  CycleEngineOutput output,
  DateTime today,
  DailyLog? log,
  List<SymptomEntry> symptoms,
) {
  final d = DateTime(date.year, date.month, date.day);

  final confirmedPeriod = periods.any((period) {
    final start = normalizeDate(period.startDate);
    final end = normalizeDate(period.endDate ?? today);
    return !d.isBefore(start) && !d.isAfter(end);
  });

  PeriodPrediction? matchingPred;
  for (final pred in output.periodPredictions) {
    if (pred.isBleedingDay(d)) {
      matchingPred = pred;
      break;
    }
  }

  final bool predictedPeriod = matchingPred != null && !confirmedPeriod;
  bool isUncertainty = false;
  if (!confirmedPeriod && !predictedPeriod) {
    for (final pred in output.periodPredictions) {
      if (pred.isUncertaintyDay(d)) {
        isUncertainty = true;
        break;
      }
    }
  }

  final historyRecords = periods
      .map((p) => CyclePeriodRecord(startDate: p.startDate, endDate: p.endDate))
      .toList();
  final phase = output.getCalendarPhase(d, history: historyRecords);

  final severity = [
    if (log != null) log.painLevel,
    ...symptoms.map((symptom) => symptom.severity),
  ].fold<int>(0, (max, value) => value > max ? value : max);

  final labels = [
    if (confirmedPeriod) 'confirmed period',
    if (predictedPeriod) 'predicted period day',
    if (isUncertainty) 'possible start window',
    if (!confirmedPeriod && !predictedPeriod) phase.displayName,
    if (log?.spotting ?? false) 'spotting',
    if (log != null) 'daily log saved',
    if (severity > 0) 'symptom severity $severity',
  ];

  return _CalendarDayState(
    confirmedPeriod: confirmedPeriod,
    predictedPeriod: predictedPeriod,
    isUncertainty: isUncertainty,
    phase: phase,
    hasLog: log != null,
    spotting: log?.spotting ?? false,
    symptomSeverity: severity,
    semanticLabel: labels.isEmpty ? 'No records.' : labels.join(', '),
  );
}

class _CalendarDayState {
  final bool confirmedPeriod;
  final bool predictedPeriod;
  final bool isUncertainty;
  final CycleCalendarPhase phase;
  final bool hasLog;
  final bool spotting;
  final int symptomSeverity;
  final String semanticLabel;

  const _CalendarDayState({
    required this.confirmedPeriod,
    required this.predictedPeriod,
    this.isUncertainty = false,
    required this.phase,
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
