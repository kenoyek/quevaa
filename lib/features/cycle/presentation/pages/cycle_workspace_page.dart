import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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
                    confidence: formatPredictionConfidence(output.confidence),
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
                      loading: () => _CycleCalendar(
                        view: view,
                        dailyLogs: const [],
                        symptoms: const [],
                        periods: periods,
                        ttcEnabled: ttcEnabled,
                        onSelectDate: (date) {},
                      ),
                      error: (error, stack) => _CycleCalendar(
                        view: view,
                        dailyLogs: const [],
                        symptoms: const [],
                        periods: periods,
                        ttcEnabled: ttcEnabled,
                        onSelectDate: (date) {},
                      ),
                    ),
                    loading: () => const _LoadingPanel(),
                    error: (error, stack) => _CycleCalendar(
                      view: view,
                      dailyLogs: const [],
                      symptoms: const [],
                      periods: periods,
                      ttcEnabled: ttcEnabled,
                      onSelectDate: (date) {},
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
            phase.toLowerCase().contains('phase')
                ? 'Estimated ${phase.toLowerCase()}'
                : 'Estimated ${phase.toLowerCase()} phase',
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
  final CycleEngineOutput output;
  final List<CyclePeriod> periods;

  const _OverviewCards({required this.output, required this.periods});

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('d MMM');
    final primaryPred = output.periodPredictions.firstOrNull;
    final enough = output.hasEnoughData && periods.length >= 2;

    final String nextPeriodBody;
    final String nextPeriodFoot;

    if (primaryPred != null) {
      final bleedingStartStr = df.format(
        primaryPred.predictedBleedingRange.start,
      );
      final bleedingEndStr = df.format(primaryPred.predictedBleedingRange.end);
      final possibleStartStr =
          '${df.format(primaryPred.possibleStartRange.start)}–${df.format(primaryPred.possibleStartRange.end)}';

      nextPeriodBody =
          'Expected: $bleedingStartStr\nDuration: ${primaryPred.expectedDurationDays} days ($bleedingStartStr–$bleedingEndStr)';
      if (output.confidence == PredictionConfidence.low ||
          primaryPred.possibleStartRange.start !=
              primaryPred.estimatedStartDate) {
        nextPeriodFoot =
            'Possible start: $possibleStartStr • Confidence: ${formatPredictionConfidence(output.confidence)}';
      } else {
        nextPeriodFoot =
            'Confidence: ${formatPredictionConfidence(output.confidence)}';
      }
    } else {
      nextPeriodBody = 'Add period history to estimate';
      nextPeriodFoot =
          'Confidence: ${formatPredictionConfidence(output.confidence)}';
    }

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
        childAspectRatio: 0.9,
      ),
      children: [
        _InfoCard(
          icon: Icons.event_available_rounded,
          title: 'Next period',
          body: nextPeriodBody,
          foot: nextPeriodFoot,
        ),
        _InfoCard(
          icon: Icons.timeline_rounded,
          title: 'Current cycle',
          body: output.hasEnoughData
              ? 'Day ${output.currentCycleDay}'
              : 'Data needed',
          foot: 'Estimated ${output.medianCycleLength.round()}-day cycle',
        ),
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
  final CycleEngineOutput output;
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final today = _sameDate(date, DateTime.now());

    Color bg;
    Color fg;
    BorderRadius borderRadius = BorderRadius.circular(12);

    if (state.confirmedPeriod) {
      bg = isDark
          ? AppColors.cycleMenstrualConfirmedDark
          : AppColors.cycleMenstrualConfirmedLight;
      fg = isDark
          ? AppColors.cycleMenstrualConfirmedTextDark
          : AppColors.cycleMenstrualConfirmedTextLight;
    } else if (state.predictedPeriod) {
      bg = isDark
          ? AppColors.cycleMenstrualPredictedDark
          : AppColors.cycleMenstrualPredictedLight;
      fg = theme.colorScheme.onSurface;

      if (state.isStartEdge && state.isEndEdge) {
        borderRadius = BorderRadius.circular(12);
      } else if (state.isStartEdge) {
        borderRadius = const BorderRadius.only(
          topLeft: Radius.circular(12),
          bottomLeft: Radius.circular(12),
        );
      } else if (state.isEndEdge) {
        borderRadius = const BorderRadius.only(
          topRight: Radius.circular(12),
          bottomRight: Radius.circular(12),
        );
      } else {
        borderRadius = BorderRadius.zero;
      }
    } else {
      fg = theme.colorScheme.onSurface;
      bg = switch (state.phase) {
        CycleCalendarPhase.estimatedOvulation =>
          isDark ? AppColors.cycleOvulationDark : AppColors.cycleOvulationLight,
        CycleCalendarPhase.fertileWindow =>
          isDark
              ? AppColors.cycleFertileWindowDark
              : AppColors.cycleFertileWindowLight,
        CycleCalendarPhase.follicular =>
          isDark
              ? AppColors.cycleFollicularDark
              : AppColors.cycleFollicularLight,
        CycleCalendarPhase.luteal =>
          isDark ? AppColors.cycleLutealDark : AppColors.cycleLutealLight,
        CycleCalendarPhase.menstrual =>
          isDark
              ? AppColors.cycleMenstrualPredictedDark
              : AppColors.cycleMenstrualPredictedLight,
        CycleCalendarPhase.unknown => Colors.transparent,
      };
    }

    Color borderColor = Colors.transparent;
    double borderWidth = 1.4;

    if (selected) {
      borderColor = isDark ? AppColors.textPrimaryDark : AppColors.deepPlum;
      borderWidth = 2.2;
    } else if (today) {
      borderColor = AppColors.terracottaPrimary;
      borderWidth = 1.8;
    } else if (state.predictedPeriod) {
      borderColor = isDark
          ? AppColors.cycleMenstrualPredictedBorderDark
          : AppColors.cycleMenstrualPredictedBorderLight;
      borderWidth = 1.2;
    } else if (state.phase == CycleCalendarPhase.estimatedOvulation) {
      borderColor = isDark
          ? AppColors.cycleOvulationBorderDark
          : AppColors.cycleOvulationBorderLight;
      borderWidth = 1.2;
    } else if (state.isUncertainty) {
      borderColor = isDark
          ? AppColors.borderDark
          : AppColors.terracottaLight.withValues(alpha: 0.5);
      borderWidth = 1.0;
    }

    return Semantics(
      button: true,
      selected: selected,
      label: '${DateFormat.yMMMMd().format(date)}. ${state.semanticLabel}',
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: borderRadius,
            border: Border.all(color: borderColor, width: borderWidth),
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
              if (state.phase == CycleCalendarPhase.estimatedOvulation)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: AppColors.warmGoldPrimary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              if (state.hasLog)
                const Positioned(
                  right: 4,
                  top: 4,
                  child: Icon(
                    Icons.edit_note_rounded,
                    size: 11,
                    color: AppColors.deepPlum,
                  ),
                ),
              if (state.symptomSeverity > 0)
                Positioned(
                  left: 4,
                  bottom: 4,
                  child: Container(
                    width: 5 + state.symptomSeverity.toDouble(),
                    height: 3,
                    decoration: BoxDecoration(
                      color: AppColors.purplePrimary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              if (state.spotting)
                const Positioned(
                  right: 4,
                  bottom: 4,
                  child: Icon(
                    Icons.circle,
                    size: 6,
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
      padding: const EdgeInsets.all(10),
      decoration: _panelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, size: 20, color: AppColors.terracottaPrimary),
          const SizedBox(height: 4),
          Text(title, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 2),
          Expanded(
            child: Text(
              body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          Text(
            foot,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final periodAndFertilityItems = [
      (
        Icons.water_drop_rounded,
        'Confirmed period',
        isDark
            ? AppColors.cycleMenstrualConfirmedDark
            : AppColors.cycleMenstrualConfirmedLight,
      ),
      (
        Icons.calendar_today_rounded,
        'Predicted period',
        isDark
            ? AppColors.cycleMenstrualPredictedBorderDark
            : AppColors.cycleMenstrualPredictedBorderLight,
      ),
      (
        Icons.eco_rounded,
        'Fertile window',
        isDark ? AppColors.cycleFertileWindowDark : AppColors.sagePrimary,
      ),
      (
        Icons.radio_button_checked_rounded,
        'Estimated ovulation',
        AppColors.warmGoldPrimary,
      ),
    ];

    final phaseItems = [
      (
        Icons.circle_outlined,
        'Follicular phase',
        isDark ? AppColors.sageLight : AppColors.sageDark,
      ),
      (
        Icons.shield_moon_outlined,
        'Luteal phase',
        isDark ? AppColors.purpleLight : AppColors.purplePrimary,
      ),
      (Icons.edit_note_rounded, 'Log', AppColors.deepPlum),
      if (ttcEnabled)
        (Icons.science_rounded, 'TTC signs', AppColors.warmGoldPrimary),
    ];

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final item in [...periodAndFertilityItems, ...phaseItems])
          Chip(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            avatar: Icon(item.$1, size: 14, color: item.$3),
            label: Text(item.$2, style: const TextStyle(fontSize: 12)),
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

_CalendarDayState _calendarState(
  DateTime date,
  List<CyclePeriod> periods,
  CycleEngineOutput output,
  bool ttcEnabled,
  DailyLog? log,
  List<SymptomEntry> symptoms,
) {
  final d = DateTime(date.year, date.month, date.day);

  final confirmedPeriod = periods.any((period) {
    final start = normalizeDate(period.startDate);
    final end = normalizeDate(period.endDate ?? DateTime.now());
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
  bool isStartEdge = false;
  bool isEndEdge = false;

  if (matchingPred != null && !confirmedPeriod) {
    final start = normalizeDate(matchingPred.predictedBleedingRange.start);
    final end = normalizeDate(matchingPred.predictedBleedingRange.end);
    isStartEdge = _sameDate(d, start);
    isEndEdge = _sameDate(d, end);
  }

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
    phase.displayName,
    if (log != null) 'daily log saved',
    if (severity > 0) 'symptom severity $severity',
  ];

  return _CalendarDayState(
    confirmedPeriod: confirmedPeriod,
    predictedPeriod: predictedPeriod,
    isStartEdge: isStartEdge,
    isEndEdge: isEndEdge,
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
  final bool isStartEdge;
  final bool isEndEdge;
  final bool isUncertainty;
  final CycleCalendarPhase phase;
  final bool hasLog;
  final bool spotting;
  final int symptomSeverity;
  final String semanticLabel;

  const _CalendarDayState({
    required this.confirmedPeriod,
    required this.predictedPeriod,
    this.isStartEdge = false,
    this.isEndEdge = false,
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

String _titleCase(String value) => value.isEmpty
    ? value
    : '${value[0].toUpperCase()}${value.substring(1).toLowerCase()}';
