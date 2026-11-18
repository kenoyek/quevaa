import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/quevaa_layout.dart';
import '../../../../app/theme/quevaa_spacing.dart';
import '../../../../core/database/app_database.dart';
import '../../../cycle/application/cycle_workspace_provider.dart';
import '../../../recommendations/application/daily_quevaa_plan_provider.dart';
import '../../application/plan_workspace_provider.dart';

class PlanWorkspacePage extends ConsumerWidget {
  const PlanWorkspacePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final section = ref.watch(planSectionProvider);
    final tasks = ref.watch(taskStreamProvider);
    final todayTasks = ref.watch(rankedTodayTasksProvider);
    final summary = ref.watch(weeklyPlanSummaryProvider);
    final saving = ref.watch(planWorkspaceControllerProvider);
    final plannedCount = todayTasks
        .where((task) => !task.isCompleted && task.status != 'Completed')
        .length;
    return Scaffold(
      backgroundColor: _pageBg(context),
      floatingActionButton: section == 'Today' && todayTasks.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: saving ? null : () => _showTaskSheet(context, ref),
              icon: const Icon(Icons.add_rounded),
              label: const Text('New Task'),
            ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.symmetric(vertical: QuevaaSpacing.m),
              sliver: SliverToBoxAdapter(
                child: _PlanHeader(plannedCount: plannedCount, saving: saving),
              ),
            ),
            SliverToBoxAdapter(
              child: QuevaaSectionTabs(
                segments: const [
                  (value: 'Today', label: 'Today', icon: Icons.today_rounded),
                  (
                    value: 'Upcoming',
                    label: 'Upcoming',
                    icon: Icons.view_week_rounded,
                  ),
                  (
                    value: 'Routines',
                    label: 'Routines',
                    icon: Icons.repeat_rounded,
                  ),
                  (value: 'Focus', label: 'Focus', icon: Icons.timer_rounded),
                  (
                    value: 'Completed',
                    label: 'Done',
                    icon: Icons.check_circle_rounded,
                  ),
                ],
                selected: section,
                onSelectionChanged: (value) =>
                    ref.read(planSectionProvider.notifier).state = value,
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              sliver: SliverToBoxAdapter(
                child: tasks.when(
                  data: (allTasks) => switch (section) {
                    'Upcoming' => _UpcomingPlan(tasks: allTasks),
                    'Routines' => const _RoutineManager(),
                    'Focus' => _FocusWorkspace(tasks: allTasks),
                    'Completed' => _CompletedTasks(tasks: allTasks),
                    _ => _TodayPlan(tasks: todayTasks, summary: summary),
                  },
                  loading: () => const _PlanLoading(),
                  error: (error, stack) => const _PlanError(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanHeader extends ConsumerWidget {
  final int plannedCount;
  final bool saving;

  const _PlanHeader({required this.plannedCount, required this.saving});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final today = DateFormat.yMMMMEEEEd().format(ref.watch(localTodayProvider));
    final readiness = ref.watch(dailyQuevaaPlanProvider).readiness;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: QuevaaSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text('Plan', style: theme.textTheme.displaySmall),
              ),
              if (saving)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            ],
          ),
          const SizedBox(height: QuevaaSpacing.xxs),
          Text(
            today,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark ? Colors.white70 : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: QuevaaSpacing.m),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                colors: [Color(0xFF482538), Color(0xFF733D59)],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plannedCount == 0
                      ? '${readiness.label} day'
                      : '$plannedCount ${plannedCount == 1 ? 'task' : 'tasks'} left today',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                  ),
                ),
                if (plannedCount == 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    readiness.primaryRecommendation,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFFFFEAF1),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayPlan extends StatelessWidget {
  final List<Task> tasks;
  final WeeklyPlanSummary summary;

  const _TodayPlan({required this.tasks, required this.summary});

  @override
  Widget build(BuildContext context) {
    final active = tasks
        .where((t) => !t.isCompleted && t.status != 'Completed')
        .toList();
    final completed = tasks
        .where((t) => t.isCompleted || t.status == 'Completed')
        .toList();

    final top = active.take(3).toList();
    final remaining = active.skip(3);
    final lowEnergy = remaining
        .where((task) => task.recommendedEnergy.toLowerCase() == 'low')
        .toList();
    final other = remaining
        .where((task) => task.recommendedEnergy.toLowerCase() != 'low')
        .toList();

    if (tasks.isEmpty) {
      return Column(
        children: [
          _WeeklyReview(summary: summary),
          const SizedBox(height: QuevaaSpacing.xl),
          const _PlanEmptyState(),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TaskGroup(
          title: 'Top priorities',
          empty: 'No active tasks for today.',
          tasks: top,
        ),
        if (other.isNotEmpty) ...[
          const SizedBox(height: QuevaaSpacing.m),
          _TaskGroup(title: 'Other tasks', empty: '', tasks: other),
        ],
        if (lowEnergy.isNotEmpty) ...[
          const SizedBox(height: QuevaaSpacing.m),
          _TaskGroup(title: 'Low-energy options', empty: '', tasks: lowEnergy),
        ],
        if (completed.isNotEmpty) ...[
          const SizedBox(height: QuevaaSpacing.m),
          _TaskGroup(
            title: 'Completed today',
            empty: '',
            tasks: completed,
            showCompleted: true,
          ),
        ],
        const SizedBox(height: QuevaaSpacing.m),
        _WeeklyReview(summary: summary),
      ],
    );
  }
}

class _PlanEmptyState extends ConsumerWidget {
  const _PlanEmptyState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(QuevaaSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(QuevaaSpacing.xl),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : AppColors.terracottaContainer,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.task_alt_rounded,
                size: 64,
                color: AppColors.terracottaPrimary,
              ),
            ),
            const SizedBox(height: QuevaaSpacing.xl),
            Text(
              'Your plan is clear',
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: QuevaaSpacing.xs),
            Text(
              'Add a task to start planning today.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark ? Colors.white60 : AppColors.textSecondaryLight,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: QuevaaSpacing.l),
            FilledButton.icon(
              onPressed: () => _showTaskSheet(context, ref),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add your first task'),
            ),
          ],
        ),
      ),
    );
  }
}

class _UpcomingPlan extends ConsumerWidget {
  final List<Task> tasks;

  const _UpcomingPlan({required this.tasks});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(localTodayProvider);
    final upcoming = <DateTime, List<Task>>{};
    for (final task in tasks) {
      final date = task.scheduledDate ?? task.dueDate;
      if (date == null || task.isCompleted || task.status == 'Completed') {
        continue;
      }
      upcoming.putIfAbsent(normalizeDate(date), () => []).add(task);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Upcoming week',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 12),
        for (var offset = 1; offset <= 7; offset++)
          _DayAgenda(
            date: DateTime(today.year, today.month, today.day + offset),
            tasks:
                upcoming[DateTime(
                  today.year,
                  today.month,
                  today.day + offset,
                )] ??
                const [],
          ),
        const SizedBox(height: 12),
        _TaskGroup(
          title: 'Unscheduled inbox',
          empty: 'No unscheduled tasks waiting.',
          tasks: tasks
              .where(
                (task) =>
                    task.scheduledDate == null &&
                    task.dueDate == null &&
                    task.status != 'Completed',
              )
              .toList(),
        ),
      ],
    );
  }
}

class _RoutineManager extends ConsumerWidget {
  const _RoutineManager();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routines = ref.watch(routineStreamProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Routines',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            FilledButton.icon(
              onPressed: () => _showRoutineSheet(context, ref),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Routine'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        routines.when(
          data: (items) => items.isEmpty
              ? const _EmptyPanel(
                  message:
                      'Build supportive routines like hydration, stretching, reflection, or supplements.',
                )
              : Column(
                  children: [
                    for (final routine in items) _RoutineTile(routine: routine),
                  ],
                ),
          loading: () => const _PlanLoading(),
          error: (error, stack) => const _PlanError(),
        ),
      ],
    );
  }
}

class _FocusWorkspace extends ConsumerWidget {
  final List<Task> tasks;

  const _FocusWorkspace({required this.tasks});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions =
        ref.watch(focusSessionStreamProvider).valueOrNull ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Focus', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final minutes in const [15, 25, 45, 60])
              FilledButton.tonalIcon(
                onPressed: () => _startFocus(context, ref, minutes: minutes),
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text('$minutes min'),
              ),
          ],
        ),
        const SizedBox(height: 16),
        _TaskGroup(
          title: 'Attach to a task',
          empty: 'Add a task first, then start a focused session for it.',
          tasks: tasks
              .where((task) => task.status != 'Completed')
              .take(4)
              .toList(),
          focusMode: true,
        ),
        const SizedBox(height: 16),
        _SessionHistory(sessions: sessions),
      ],
    );
  }
}

class _CompletedTasks extends StatelessWidget {
  final List<Task> tasks;

  const _CompletedTasks({required this.tasks});

  @override
  Widget build(BuildContext context) {
    final completed = tasks
        .where((task) => task.status == 'Completed' || task.isCompleted)
        .toList();
    return _TaskGroup(
      title: 'Completed work',
      empty: 'Completed tasks will appear here.',
      tasks: completed,
      showCompleted: true,
    );
  }
}

class _TaskGroup extends StatelessWidget {
  final String title;
  final String empty;
  final List<Task> tasks;
  final bool showCompleted;
  final bool focusMode;

  const _TaskGroup({
    required this.title,
    required this.empty,
    required this.tasks,
    this.showCompleted = false,
    this.focusMode = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(QuevaaSpacing.m),
      decoration: _panelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: QuevaaSpacing.xs),
          if (tasks.isEmpty)
            if (empty.isNotEmpty)
              Text(
                empty,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              )
            else
              const SizedBox.shrink()
          else
            for (final task in tasks)
              _TaskTile(
                task: task,
                showCompleted: showCompleted,
                focusMode: focusMode,
              ),
        ],
      ),
    );
  }
}

class _TaskTile extends ConsumerWidget {
  final Task task;
  final bool showCompleted;
  final bool focusMode;

  const _TaskTile({
    required this.task,
    required this.showCompleted,
    required this.focusMode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completed = task.isCompleted || task.status == 'Completed';
    return Semantics(
      button: true,
      label:
          '${task.title}, ${task.priority} priority, ${task.recommendedEnergy} energy',
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: Checkbox(
            value: completed,
            onChanged: (value) => ref
                .read(planWorkspaceControllerProvider.notifier)
                .completeTask(task, completed: value ?? false),
          ),
          onTap: focusMode
              ? () => _startFocus(
                  context,
                  ref,
                  minutes: task.estimatedDurationMinutes.clamp(15, 60),
                  task: task,
                )
              : () => _showTaskSheet(context, ref, task: task),
          title: Text(
            task.title,
            style: TextStyle(
              decoration: completed ? TextDecoration.lineThrough : null,
              color: completed
                  ? Theme.of(context).colorScheme.onSurfaceVariant
                  : null,
            ),
          ),
          subtitle: Text(
            [
              task.category,
              task.priority,
              '${task.estimatedDurationMinutes} min',
              '${task.recommendedEnergy} energy',
              if (task.dueDate != null)
                'Due ${DateFormat.MMMd().format(task.dueDate!)}',
            ].join(' • '),
          ),
          trailing: PopupMenuButton<String>(
            tooltip: 'Task actions',
            onSelected: (value) async {
              final controller = ref.read(
                planWorkspaceControllerProvider.notifier,
              );
              switch (value) {
                case 'edit':
                  _showTaskSheet(context, ref, task: task);
                case 'duplicate':
                  await controller.duplicateTask(task);
                case 'focus':
                  await _startFocus(
                    context,
                    ref,
                    minutes: task.estimatedDurationMinutes.clamp(15, 60),
                    task: task,
                  );
                case 'delete':
                  final confirmed = await _confirm(
                    context,
                    'Archive this task?',
                    'It will be removed from your active plan.',
                  );
                  if (confirmed) await controller.archiveTask(task);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit')),
              const PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
              if (!completed)
                const PopupMenuItem(value: 'focus', child: Text('Start focus')),
              const PopupMenuItem(value: 'delete', child: Text('Archive')),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayAgenda extends StatelessWidget {
  final DateTime date;
  final List<Task> tasks;

  const _DayAgenda({required this.date, required this.tasks});

  @override
  Widget build(BuildContext context) {
    final overloaded = tasks.length > 5;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: _panelDecoration(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              DateFormat.E().add_MMMd().format(date),
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          Expanded(
            child: tasks.isEmpty
                ? const Text('Open')
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (overloaded)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 6),
                          child: Text(
                            'A little full. Consider moving flexible tasks.',
                          ),
                        ),
                      for (final task in tasks)
                        Text(
                          '• ${task.title}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _RoutineTile extends ConsumerWidget {
  final Routine routine;

  const _RoutineTile({required this.routine});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.repeat_rounded, color: AppColors.sagePrimary),
        title: Text(routine.title),
        subtitle: Text(
          'Completed ${routine.streakCount} times. ${routine.frequency}',
        ),
        trailing: FilledButton.tonal(
          onPressed: () => ref
              .read(planWorkspaceControllerProvider.notifier)
              .completeRoutine(routine),
          child: const Text('Done'),
        ),
      ),
    );
  }
}

class _WeeklyReview extends StatelessWidget {
  final WeeklyPlanSummary summary;

  const _WeeklyReview({required this.summary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final metrics = [
      (label: 'completed', value: '${summary.completedTasks}'),
      (label: 'focus min', value: '${summary.focusMinutes}'),
      (label: 'planned', value: '${summary.plannedTasks}'),
    ];

    final hasProgress =
        summary.completedTasks > 0 ||
        summary.focusMinutes > 0 ||
        summary.plannedTasks > 0;

    return Container(
      padding: const EdgeInsets.all(QuevaaSpacing.m),
      decoration: _panelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_graph_rounded,
                color: AppColors.purplePrimary,
                size: 20,
              ),
              const SizedBox(width: QuevaaSpacing.xs),
              Text(
                'This week',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.purpleLight : AppColors.purpleDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: QuevaaSpacing.s),
          if (!hasProgress)
            Text(
              'Your weekly progress will appear here.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDark ? Colors.white60 : AppColors.textSecondaryLight,
              ),
            )
          else
            Wrap(
              spacing: QuevaaSpacing.m,
              runSpacing: QuevaaSpacing.xs,
              children: metrics.map((m) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      m.value,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: QuevaaSpacing.xxs),
                    Text(
                      m.label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? Colors.white60
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

Future<void> _startFocus(
  BuildContext context,
  WidgetRef ref, {
  required int minutes,
  Task? task,
}) async {
  final controller = ref.read(planWorkspaceControllerProvider.notifier);
  final title = task?.title ?? '$minutes-minute focus';
  final finished = await showDialog<bool>(
    context: context,
    builder: (_) => _FocusTimer(title: title, minutes: minutes),
  );
  if (finished != true || !context.mounted) return;
  try {
    await controller.saveFocusSession(
      title: title,
      durationMinutes: minutes,
      taskId: task?.id,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Focus session logged.')));
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save your focus session.')),
      );
    }
  }
}

class _FocusTimer extends StatefulWidget {
  const _FocusTimer({required this.title, required this.minutes});

  final String title;
  final int minutes;

  @override
  State<_FocusTimer> createState() => _FocusTimerState();
}

class _FocusTimerState extends State<_FocusTimer> {
  late final Stopwatch _clock;
  late final Timer _ticker;

  @override
  void initState() {
    super.initState();
    _clock = Stopwatch()..start();
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _ticker.cancel();
    _clock.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.minutes * 60;
    final remaining = (total - _clock.elapsed.inSeconds).clamp(0, total);
    final seconds = (remaining % 60).toString().padLeft(2, '0');
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${remaining ~/ 60}:$seconds',
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(value: (total - remaining) / total),
          if (remaining == 0)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text('Session complete.'),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(remaining == 0 ? 'Discard' : 'End session'),
        ),
        if (remaining == 0)
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save session'),
          ),
      ],
    );
  }
}

class _SessionHistory extends StatelessWidget {
  final List<FocusSession> sessions;

  const _SessionHistory({required this.sessions});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Session history',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          if (sessions.isEmpty)
            const Text('Focus sessions completed locally will appear here.')
          else
            for (final session in sessions.take(8))
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.timer_rounded),
                title: Text(session.title),
                subtitle: Text(
                  '${session.durationMinutes} min • ${session.completedAt == null ? 'In progress' : DateFormat.MMMd().add_jm().format(session.completedAt!)}',
                ),
              ),
        ],
      ),
    );
  }
}

void _showTaskSheet(BuildContext context, WidgetRef ref, {Task? task}) {
  final title = TextEditingController(text: task?.title);
  final notes = TextEditingController(text: task?.description);
  var category = task?.category ?? 'General';
  var priority = task?.priority ?? 'Normal';
  var energy = task?.recommendedEnergy ?? 'Flexible';
  var duration = (task?.estimatedDurationMinutes ?? 30)
      .clamp(5, 180)
      .toDouble();
  final today = ref.read(localTodayProvider);
  DateTime? scheduled = task == null ? today : task.scheduledDate;
  final formKey = GlobalKey<FormState>();
  var saving = false;
  String? saveError;
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
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task == null ? 'Add task' : 'Edit task',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: title,
                    decoration: const InputDecoration(labelText: 'Title'),
                    validator: (value) => (value?.trim().isEmpty ?? true)
                        ? 'Enter a task title.'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: notes,
                    decoration: const InputDecoration(labelText: 'Notes'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items:
                        const [
                              'General',
                              'Work',
                              'Home',
                              'Care',
                              'Admin',
                              'Creative',
                            ]
                            .map(
                              (item) => DropdownMenuItem(
                                value: item,
                                child: Text(item),
                              ),
                            )
                            .toList(),
                    onChanged: (value) =>
                        setState(() => category = value ?? category),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: priority,
                    decoration: const InputDecoration(labelText: 'Priority'),
                    items: const ['Low', 'Normal', 'High', 'Urgent']
                        .map(
                          (item) =>
                              DropdownMenuItem(value: item, child: Text(item)),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => priority = value ?? priority),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: energy,
                    decoration: const InputDecoration(
                      labelText: 'Energy requirement',
                    ),
                    items: const ['Low', 'Moderate', 'High', 'Flexible']
                        .map(
                          (item) =>
                              DropdownMenuItem(value: item, child: Text(item)),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => energy = value ?? energy),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      scheduled == null
                          ? 'No scheduled date'
                          : 'Scheduled ${DateFormat.yMMMd().format(scheduled!)}',
                    ),
                    trailing: scheduled == null
                        ? const Icon(Icons.calendar_today_rounded)
                        : IconButton(
                            onPressed: () => setState(() => scheduled = null),
                            tooltip: 'Clear scheduled date',
                            icon: const Icon(Icons.close_rounded),
                          ),
                    onTap: () async {
                      final date = scheduled ?? today;
                      final earliest = DateTime(
                        today.year - 1,
                        today.month,
                        today.day,
                      );
                      final latest = DateTime(
                        today.year + 3,
                        today.month,
                        today.day,
                      );
                      final picked = await showDatePicker(
                        context: context,
                        firstDate: date.isBefore(earliest) ? date : earliest,
                        lastDate: date.isAfter(latest) ? date : latest,
                        initialDate: date,
                        currentDate: today,
                      );
                      if (context.mounted && picked != null) {
                        setState(() => scheduled = picked);
                      }
                    },
                  ),
                  Row(
                    children: [
                      const SizedBox(width: 110, child: Text('Duration')),
                      Expanded(
                        child: Slider(
                          value: duration,
                          min: 5,
                          max: 180,
                          divisions: 35,
                          label: '${duration.round()} min',
                          onChanged: (value) =>
                              setState(() => duration = value),
                        ),
                      ),
                      Text('${duration.round()}m'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (saveError != null)
                    Text(
                      saveError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: saving
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;
                              setState(() {
                                saving = true;
                                saveError = null;
                              });
                              try {
                                final previousDate = task?.scheduledDate;
                                final followsSchedule =
                                    task?.dueDate == previousDate;
                                await ref
                                    .read(
                                      planWorkspaceControllerProvider.notifier,
                                    )
                                    .saveTask(
                                      id: task?.id,
                                      title: title.text,
                                      notes: notes.text,
                                      category: category,
                                      priority: priority,
                                      energy: energy,
                                      scheduledDate: scheduled,
                                      dueDate: followsSchedule
                                          ? scheduled
                                          : task?.dueDate,
                                      scheduledTimeMinutes:
                                          task?.scheduledTimeMinutes,
                                      reminderMinutes: previousDate == null
                                          ? null
                                          : task?.reminderAt
                                                ?.difference(previousDate)
                                                .inMinutes,
                                      recurrenceRule: task?.recurrenceRule,
                                      estimatedDurationMinutes: duration
                                          .round(),
                                      status: task?.status ?? 'Planned',
                                    );
                                if (context.mounted) Navigator.pop(context);
                              } catch (_) {
                                if (context.mounted) {
                                  setState(() {
                                    saving = false;
                                    saveError =
                                        'Could not finish saving this task. Try again.';
                                  });
                                }
                              }
                            },
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Save task'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  ).whenComplete(() {
    title.dispose();
    notes.dispose();
  });
}

void _showRoutineSheet(BuildContext context, WidgetRef ref) {
  final title = TextEditingController();
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: title,
              decoration: const InputDecoration(labelText: 'Routine name'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () async {
                  await ref
                      .read(planWorkspaceControllerProvider.notifier)
                      .saveRoutine(title: title.text);
                  if (context.mounted) Navigator.pop(context);
                },
                icon: const Icon(Icons.check_rounded),
                label: const Text('Save routine'),
              ),
            ),
          ],
        ),
      ),
    ),
  ).whenComplete(title.dispose);
}

Future<bool> _confirm(BuildContext context, String title, String body) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continue'),
            ),
          ],
        ),
      ) ??
      false;
}

class _EmptyPanel extends StatelessWidget {
  final String message;

  const _EmptyPanel({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(context),
      child: Text(message),
    );
  }
}

class _PlanLoading extends StatelessWidget {
  const _PlanLoading();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(30),
      child: CircularProgressIndicator(),
    ),
  );
}

class _PlanError extends StatelessWidget {
  const _PlanError();

  @override
  Widget build(BuildContext context) => const _EmptyPanel(
    message: 'Your local plan could not be loaded. Please try again.',
  );
}

Color _pageBg(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? AppColors.bgWarmDark
    : AppColors.bgWarmCream;

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
