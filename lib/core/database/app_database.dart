import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

// --- Base Mixin for Standard Audit Columns ---
mixin AuditColumns on Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  IntColumn get schemaVersion => integer().withDefault(const Constant(1))();
  TextColumn get source => text().withDefault(
    const Constant('manual'),
  )(); // manual, imported, generated
}

// 1. UserProfiles
class UserProfiles extends Table with AuditColumns {
  TextColumn get userName => text().withDefault(const Constant('Adaora'))();
  IntColumn get averageCycleLength =>
      integer().withDefault(const Constant(28))();
  IntColumn get averagePeriodLength =>
      integer().withDefault(const Constant(5))();
  DateTimeColumn get lastPeriodStartDate => dateTime().nullable()();
  BoolColumn get isBiometricEnabled =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get isPinEnabled => boolean().withDefault(const Constant(false))();
  TextColumn get userPinHash => text().nullable()();
  TextColumn get primaryGoal =>
      text().withDefault(const Constant('Understand my period'))();
}

// 2. ConsentRecords
class ConsentRecords extends Table with AuditColumns {
  TextColumn get consentType => text()(); // terms, privacy, medical_disclaimer
  BoolColumn get isGranted => boolean()();
  DateTimeColumn get grantedAt => dateTime()();
  TextColumn get policyVersion => text()();
}

// 3. CyclePeriods
class CyclePeriods extends Table with AuditColumns {
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()();
  IntColumn get flowIntensity => integer().withDefault(
    const Constant(2),
  )(); // 1: Spotting, 2: Light, 3: Medium, 4: Heavy
  BoolColumn get isOngoing => boolean().withDefault(const Constant(false))();
  TextColumn get notes => text().nullable()();
}

// 4. CyclePredictions
class CyclePredictions extends Table with AuditColumns {
  DateTimeColumn get estimatedPeriodStartMin => dateTime()();
  DateTimeColumn get estimatedPeriodStartMax => dateTime()();
  DateTimeColumn get estimatedOvulationDate => dateTime()();
  DateTimeColumn get fertileWindowStart => dateTime()();
  DateTimeColumn get fertileWindowEnd => dateTime()();
  TextColumn get confidenceScore =>
      text().withDefault(const Constant('Medium'))(); // Low, Medium, High
  TextColumn get disclaimerText => text()();
}

// 5. DailyLogs
class DailyLogs extends Table with AuditColumns {
  DateTimeColumn get date => dateTime()();
  IntColumn get energyLevel =>
      integer().withDefault(const Constant(3))(); // 1 to 5
  IntColumn get painLevel =>
      integer().withDefault(const Constant(0))(); // 0 to 5
  TextColumn get generalNotes => text().nullable()();
}

// 6. SymptomEntries
class SymptomEntries extends Table with AuditColumns {
  DateTimeColumn get date => dateTime()();
  TextColumn get symptomCategory =>
      text()(); // Cramps, Headache, Bloating, Acne, Fatigue, etc.
  IntColumn get severity =>
      integer().withDefault(const Constant(1))(); // 1 to 5
  TextColumn get notes => text().nullable()();
}

// 7. MoodEntries
class MoodEntries extends Table with AuditColumns {
  DateTimeColumn get date => dateTime()();
  TextColumn get moodType =>
      text()(); // Happy, Anxious, Calm, Irritable, Energetic, Sad
  IntColumn get intensity =>
      integer().withDefault(const Constant(3))(); // 1 to 5
}

// 8. SleepEntries
class SleepEntries extends Table with AuditColumns {
  DateTimeColumn get date => dateTime()();
  RealColumn get durationHours => real()();
  IntColumn get sleepQuality =>
      integer().withDefault(const Constant(3))(); // 1 to 5
}

// 9. HydrationEntries
class HydrationEntries extends Table with AuditColumns {
  DateTimeColumn get date => dateTime()();
  IntColumn get glassesDrank => integer().withDefault(const Constant(0))();
  IntColumn get targetGlasses => integer().withDefault(const Constant(8))();
}

// 10. Tasks
class Tasks extends Table with AuditColumns {
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get targetPhase => text().withDefault(
    const Constant('All'),
  )(); // Menstrual, Follicular, Ovulation, Luteal, All
  TextColumn get recommendedEnergy =>
      text().withDefault(const Constant('Medium'))(); // Low, Medium, High
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get dueDate => dateTime().nullable()();
  TextColumn get priority => text().withDefault(const Constant('Medium'))();
}

// 11. FocusSessions
class FocusSessions extends Table with AuditColumns {
  TextColumn get title => text()();
  IntColumn get durationMinutes => integer()();
  DateTimeColumn get completedAt => dateTime()();
}

// 12. Routines
class Routines extends Table with AuditColumns {
  TextColumn get title => text()();
  TextColumn get frequency => text()(); // daily, phase_based
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}

// 13. Meals
class Meals extends Table with AuditColumns {
  TextColumn get title => text()(); // e.g., Ugu & Plantain Porridge
  TextColumn get mealType => text()(); // Breakfast, Lunch, Dinner, Snack
  TextColumn get targetPhase =>
      text()(); // Menstrual, Follicular, Ovulation, Luteal
  TextColumn get description => text()();
  TextColumn get nutrients => text()(); // e.g., Iron & Magnesium
}

// 14. Recipes
class Recipes extends Table with AuditColumns {
  TextColumn get title => text()();
  TextColumn get ingredientsJson => text()();
  TextColumn get instructions => text()();
  TextColumn get prepTimeMinutes => text().nullable()();
}

// 15. MealPlans
class MealPlans extends Table with AuditColumns {
  DateTimeColumn get date => dateTime()();
  IntColumn get mealId => integer()();
  TextColumn get mealType => text()();
}

// 16. MealLogs
class MealLogs extends Table with AuditColumns {
  DateTimeColumn get loggedAt => dateTime()();
  TextColumn get mealTitle => text()();
  TextColumn get notes => text().nullable()();
}

// 17. PantryItems
class PantryItems extends Table with AuditColumns {
  TextColumn get name => text()();
  RealColumn get quantity => real()();
  TextColumn get unit => text()();
}

// 18. ShoppingItems
class ShoppingItems extends Table with AuditColumns {
  TextColumn get itemName => text()();
  BoolColumn get isPurchased => boolean().withDefault(const Constant(false))();
}

// 19. WorkoutPlans
class WorkoutPlans extends Table with AuditColumns {
  TextColumn get title => text()();
  TextColumn get category =>
      text()(); // Yin Yoga, Walking, HIIT, Strength, Pilates
  TextColumn get targetPhase => text()();
  IntColumn get durationMinutes => integer()();
  TextColumn get intensity => text()(); // Gentle, Moderate, High
}

// 20. WorkoutSessions
class WorkoutSessions extends Table with AuditColumns {
  IntColumn get workoutPlanId => integer()();
  DateTimeColumn get completedAt => dateTime()();
  IntColumn get perceivedExertion => integer()(); // 1 to 10
}

// 21. ExerciseLogs
class ExerciseLogs extends Table with AuditColumns {
  TextColumn get exerciseName => text()();
  IntColumn get sets => integer()();
  IntColumn get reps => integer()();
}

// 22. JournalEntries
class JournalEntries extends Table with AuditColumns {
  TextColumn get title => text().nullable()();
  TextColumn get encryptedContent => text()();
  TextColumn get mood => text().nullable()();
  TextColumn get tagsJson => text().withDefault(const Constant('[]'))();
}

// 23. JournalAttachments
class JournalAttachments extends Table with AuditColumns {
  IntColumn get journalEntryId => integer()();
  TextColumn get encryptedFilePath => text()();
  TextColumn get fileType => text()(); // image, audio
}

// 24. NotificationPreferences
class NotificationPreferences extends Table with AuditColumns {
  BoolColumn get periodReminders =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get phaseChangeAlerts =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get hydrationReminders =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get mealPrepReminders =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get discreetNotificationContent =>
      boolean().withDefault(const Constant(true))();
}

// 24b. NotificationPreferenceRows
class NotificationPreferenceRows extends Table with AuditColumns {
  BoolColumn get enabled => boolean().withDefault(const Constant(false))();
  BoolColumn get permissionInvitationSeen =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get permissionPreviouslyDeclined =>
      boolean().withDefault(const Constant(false))();
  TextColumn get privacyMode =>
      text().withDefault(const Constant('discreet'))();
  IntColumn get quietStartMinutes =>
      integer().withDefault(const Constant(1260))();
  IntColumn get quietEndMinutes => integer().withDefault(const Constant(480))();
  IntColumn get dailyCap => integer().withDefault(const Constant(4))();
  BoolColumn get soundEnabled => boolean().withDefault(const Constant(true))();
  BoolColumn get vibrationEnabled =>
      boolean().withDefault(const Constant(true))();
  TextColumn get lastKnownTimezone =>
      text().withDefault(const Constant('UTC'))();
  DateTimeColumn get lastReconciliationAt => dateTime().nullable()();
  IntColumn get notificationScheduleVersion =>
      integer().withDefault(const Constant(1))();
  TextColumn get categoryEnabledJson =>
      text().withDefault(const Constant('{}'))();
  TextColumn get categoryTimesJson =>
      text().withDefault(const Constant('{}'))();
}

// 24c. NotificationScheduleStates
class NotificationScheduleStates extends Table with AuditColumns {
  IntColumn get notificationId => integer().unique()();
  TextColumn get notificationType => text()();
  DateTimeColumn get scheduledAt => dateTime()();
  TextColumn get timezoneName => text()();
  TextColumn get route => text()();
  TextColumn get localRecordId => text().nullable()();
  TextColumn get priority => text()();
  TextColumn get fingerprint => text()();
  BoolColumn get isPending => boolean().withDefault(const Constant(true))();
}

// 24d. NotificationCompletionRecords
class NotificationCompletionRecords extends Table with AuditColumns {
  IntColumn get notificationId => integer()();
  TextColumn get notificationType => text()();
  TextColumn get localRecordId => text().nullable()();
  DateTimeColumn get completedAt => dateTime()();
  TextColumn get action => text()();
}

// 25. AppSettings
class AppSettings extends Table with AuditColumns {
  TextColumn get themeMode =>
      text().withDefault(const Constant('system'))(); // light, dark, system
  BoolColumn get isAppLockEnabled =>
      boolean().withDefault(const Constant(false))();
  IntColumn get autoLockInactivitySeconds =>
      integer().withDefault(const Constant(120))();
}

// 26. ExportHistory
class ExportHistory extends Table with AuditColumns {
  DateTimeColumn get exportedAt => dateTime()();
  TextColumn get exportType => text()(); // json, pdf, quevaa_encrypted
  TextColumn get destination => text()();
}

// 27. SubscriptionEntitlements
class SubscriptionEntitlements extends Table with AuditColumns {
  TextColumn get tier =>
      text().withDefault(const Constant('free'))(); // free, premium
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get expiresAt => dateTime().nullable()();
}

@DriftDatabase(
  tables: [
    UserProfiles,
    ConsentRecords,
    CyclePeriods,
    CyclePredictions,
    DailyLogs,
    SymptomEntries,
    MoodEntries,
    SleepEntries,
    HydrationEntries,
    Tasks,
    FocusSessions,
    Routines,
    Meals,
    Recipes,
    MealPlans,
    MealLogs,
    PantryItems,
    ShoppingItems,
    WorkoutPlans,
    WorkoutSessions,
    ExerciseLogs,
    JournalEntries,
    JournalAttachments,
    NotificationPreferences,
    NotificationPreferenceRows,
    NotificationScheduleStates,
    NotificationCompletionRecords,
    AppSettings,
    ExportHistory,
    SubscriptionEntitlements,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(notificationPreferenceRows);
        await m.createTable(notificationScheduleStates);
        await m.createTable(notificationCompletionRecords);
      }
    },
  );

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'quevaa_encrypted_db',
      native: DriftNativeOptions(
        databaseDirectory: () async {
          final dir = await getApplicationDocumentsDirectory();
          return dir.path;
        },
      ),
    );
  }

  /// Complete secure deletion workflow purging all local user records.
  Future<void> deleteAllUserData() async {
    await transaction(() async {
      for (final table in allTables) {
        await delete(table).go();
      }
    });
  }
}
