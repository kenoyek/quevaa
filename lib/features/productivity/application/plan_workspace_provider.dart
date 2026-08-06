import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../../cycle/application/cycle_workspace_provider.dart';
import '../../notifications/application/notification_preferences_provider.dart';
import '../../notifications/domain/services/notification_scheduler.dart';
import '../domain/entities/task_entity.dart';
import '../domain/productivity_engine.dart';

final planSectionProvider = StateProvider<String>((ref) => 'Today');

final taskStreamProvider = StreamProvider<List<Task>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.tasks)
        ..where(
          (tbl) => tbl.deletedAt.isNull() & tbl.status.isNotIn(['Archived']),
        )
        ..orderBy([
          (tbl) => OrderingTerm.asc(tbl.scheduledDate),
          (tbl) => OrderingTerm.desc(tbl.priority),
          (tbl) => OrderingTerm.asc(tbl.createdAt),
        ]))
      .watch();
});

final todayTasksProvider = Provider<List<Task>>((ref) {
  final tasks = ref.watch(taskStreamProvider).valueOrNull ?? const [];
  final today = normalizeDate(DateTime.now());
  return tasks.where((task) {
    final scheduled = task.scheduledDate == null
        ? null
        : normalizeDate(task.scheduledDate!);
    final due = task.dueDate == null ? null : normalizeDate(task.dueDate!);
    return scheduled == today || due == today || task.status == 'Planned';
  }).toList();
});

final rankedTodayTasksProvider = Provider<List<Task>>((ref) {
  final tasks = ref.watch(todayTasksProvider);
  final log = ref.watch(selectedDayLogProvider).valueOrNull;
  final ranked = ProductivityEngine.rankTasks(
    tasks: [
      for (final task in tasks)
        TaskEntity(
          id: task.id,
          title: task.title,
          description: task.description,
          category: task.category,
          energyTag: _energyFromString(task.recommendedEnergy),
          priority: _priorityForEngine(task.priority),
          isCompleted: task.isCompleted || task.status == 'Completed',
          dueDate: task.dueDate,
          estimatedMinutes: task.estimatedDurationMinutes,
          targetPhase: task.targetPhase,
        ),
    ],
    userEnergyLevel: log?.energyLevel ?? 3,
    userPainLevel: log?.painLevel ?? 0,
  );
  final ids = ranked.map((task) => task.id).toList();
  return [...tasks]
    ..sort((a, b) => ids.indexOf(a.id).compareTo(ids.indexOf(b.id)));
});

final routineStreamProvider = StreamProvider<List<Routine>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.routines)
        ..where((tbl) => tbl.deletedAt.isNull() & tbl.archivedAt.isNull())
        ..orderBy([(tbl) => OrderingTerm.asc(tbl.preferredTimeMinutes)]))
      .watch();
});

final focusSessionStreamProvider = StreamProvider<List<FocusSession>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.focusSessions)
        ..where((tbl) => tbl.deletedAt.isNull())
        ..orderBy([(tbl) => OrderingTerm.desc(tbl.startedAt)]))
      .watch();
});

final weeklyPlanSummaryProvider = Provider<WeeklyPlanSummary>((ref) {
  final tasks = ref.watch(taskStreamProvider).valueOrNull ?? const [];
  final sessions =
      ref.watch(focusSessionStreamProvider).valueOrNull ?? const [];
  final now = DateTime.now();
  final weekStart = normalizeDate(
    now.subtract(Duration(days: now.weekday - 1)),
  );
  final weekEnd = weekStart.add(const Duration(days: 7));
  final completed = tasks
      .where(
        (task) =>
            task.completedAt != null &&
            !task.completedAt!.isBefore(weekStart) &&
            task.completedAt!.isBefore(weekEnd),
      )
      .length;
  final focusMinutes = sessions
      .where(
        (session) =>
            session.completedAt != null &&
            !session.completedAt!.isBefore(weekStart) &&
            session.completedAt!.isBefore(weekEnd),
      )
      .fold<int>(0, (total, session) => total + session.durationMinutes);
  return WeeklyPlanSummary(
    completedTasks: completed,
    focusMinutes: focusMinutes,
    plannedTasks: tasks.where((task) => task.status == 'Planned').length,
  );
});

final planWorkspaceControllerProvider =
    NotifierProvider<PlanWorkspaceController, bool>(
      PlanWorkspaceController.new,
    );

class WeeklyPlanSummary {
  final int completedTasks;
  final int focusMinutes;
  final int plannedTasks;

  const WeeklyPlanSummary({
    required this.completedTasks,
    required this.focusMinutes,
    required this.plannedTasks,
  });
}

class PlanWorkspaceController extends Notifier<bool> {
  @override
  bool build() => false;

  AppDatabase get _db => ref.read(appDatabaseProvider);

  Future<void> saveTask({
    int? id,
    required String title,
    String? notes,
    String category = 'General',
    String priority = 'Normal',
    String energy = 'Flexible',
    DateTime? dueDate,
    DateTime? scheduledDate,
    int? scheduledTimeMinutes,
    int? reminderMinutes,
    String? recurrenceRule,
    int estimatedDurationMinutes = 30,
    String status = 'Planned',
  }) async {
    if (state || title.trim().isEmpty) return;
    state = true;
    try {
      final now = DateTime.now();
      final companion = TasksCompanion(
        title: Value(title.trim()),
        description: Value(
          notes?.trim().isEmpty ?? true ? null : notes!.trim(),
        ),
        category: Value(category),
        priority: Value(priority),
        recommendedEnergy: Value(energy),
        dueDate: Value(dueDate == null ? null : normalizeDate(dueDate)),
        scheduledDate: Value(
          scheduledDate == null ? null : normalizeDate(scheduledDate),
        ),
        scheduledTimeMinutes: Value(scheduledTimeMinutes),
        reminderAt: Value(
          reminderMinutes == null || scheduledDate == null
              ? null
              : normalizeDate(
                  scheduledDate,
                ).add(Duration(minutes: reminderMinutes)),
        ),
        recurrenceRule: Value(recurrenceRule),
        estimatedDurationMinutes: Value(estimatedDurationMinutes),
        status: Value(status),
        updatedAt: Value(now),
      );
      if (id == null) {
        await _db
            .into(_db.tasks)
            .insert(
              companion.copyWith(
                uuid: Value(localUuid('task')),
                createdAt: Value(now),
                updatedAt: Value(now),
              ),
            );
      } else {
        await (_db.update(
          _db.tasks,
        )..where((tbl) => tbl.id.equals(id))).write(companion);
      }
      // Reconcile notifications after saving a task
      await ref.read(notificationSchedulerProvider).reconcileNotifications(
        NotificationReconciliationReason.taskChanged,
      );
    } finally {
      state = false;
    }
  }

  Future<void> completeTask(Task task, {required bool completed}) async {
    final now = DateTime.now();
    await (_db.update(_db.tasks)..where((tbl) => tbl.id.equals(task.id))).write(
      TasksCompanion(
        isCompleted: Value(completed),
        status: Value(completed ? 'Completed' : 'Planned'),
        completedAt: Value(completed ? now : null),
        updatedAt: Value(now),
      ),
    );
    // Reconcile notifications after completing a task
    await ref.read(notificationSchedulerProvider).reconcileNotifications(
      NotificationReconciliationReason.taskChanged,
    );
  }

  Future<void> archiveTask(Task task) async {
    await (_db.update(_db.tasks)..where((tbl) => tbl.id.equals(task.id))).write(
      TasksCompanion(
        status: const Value('Archived'),
        deletedAt: Value(DateTime.now()),
      ),
    );
    // Reconcile notifications after archiving a task
    await ref.read(notificationSchedulerProvider).reconcileNotifications(
      NotificationReconciliationReason.taskChanged,
    );
  }

  Future<void> duplicateTask(Task task) async {
    await saveTask(
      title: '${task.title} copy',
      notes: task.description,
      category: task.category,
      priority: task.priority,
      energy: task.recommendedEnergy,
      dueDate: task.dueDate,
      scheduledDate: task.scheduledDate,
      scheduledTimeMinutes: task.scheduledTimeMinutes,
      recurrenceRule: task.recurrenceRule,
      estimatedDurationMinutes: task.estimatedDurationMinutes,
      status: task.status == 'Completed' ? 'Planned' : task.status,
    );
  }

  Future<void> saveRoutine({
    int? id,
    required String title,
    String frequency = 'daily',
    List<int> weekdays = const [],
    int? preferredTimeMinutes,
  }) async {
    if (state || title.trim().isEmpty) return;
    state = true;
    try {
      final now = DateTime.now();
      final companion = RoutinesCompanion(
        title: Value(title.trim()),
        frequency: Value(frequency),
        weekdaysJson: Value(jsonEncode(weekdays)),
        preferredTimeMinutes: Value(preferredTimeMinutes),
        isActive: const Value(true),
        updatedAt: Value(now),
      );
      if (id == null) {
        await _db
            .into(_db.routines)
            .insert(
              companion.copyWith(
                uuid: Value(localUuid('routine')),
                createdAt: Value(now),
                updatedAt: Value(now),
              ),
            );
      } else {
        await (_db.update(
          _db.routines,
        )..where((tbl) => tbl.id.equals(id))).write(companion);
      }
    } finally {
      state = false;
    }
  }

  Future<void> completeRoutine(Routine routine) async {
    final today = normalizeDate(DateTime.now()).toIso8601String();
    final history = (jsonDecode(routine.completionHistoryJson) as List<dynamic>)
        .cast<String>()
        .toSet();
    history.add(today);
    await (_db.update(
      _db.routines,
    )..where((tbl) => tbl.id.equals(routine.id))).write(
      RoutinesCompanion(
        completionHistoryJson: Value(jsonEncode(history.toList()..sort())),
        streakCount: Value(routine.streakCount + 1),
        updatedAt: Value(DateTime.now()),
      ),
    );
    // Reconcile notifications after completing a routine
    await ref.read(notificationSchedulerProvider).reconcileNotifications(
      NotificationReconciliationReason.taskChanged,
    );
  }

  Future<void> saveFocusSession({
    required String title,
    required int durationMinutes,
    int breakMinutes = 5,
    int? taskId,
  }) async {
    if (state) return;
    state = true;
    try {
      final now = DateTime.now();
      await _db
          .into(_db.focusSessions)
          .insert(
            FocusSessionsCompanion.insert(
              uuid: localUuid('focus'),
              createdAt: now,
              updatedAt: now,
              title: title,
              taskId: Value(taskId),
              startedAt: Value(now),
              durationMinutes: durationMinutes,
              breakMinutes: Value(breakMinutes),
              status: const Value('Completed'),
              completedAt: Value(now.add(Duration(minutes: durationMinutes))),
            ),
          );
    } finally {
      state = false;
    }
  }
}

EnergyTag _energyFromString(String value) {
  return switch (value.toLowerCase()) {
    'low' => EnergyTag.low,
    'moderate' || 'medium' => EnergyTag.moderate,
    'high' => EnergyTag.high,
    _ => EnergyTag.flexible,
  };
}

String _priorityForEngine(String value) {
  return switch (value.toLowerCase()) {
    'urgent' || 'high' => 'High',
    'low' => 'Low',
    _ => 'Medium',
  };
}
