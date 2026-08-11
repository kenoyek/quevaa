import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';
import 'package:sqlite3/open.dart';

import '../security/secure_storage_service.dart';
import '../../features/conception/data/tables/conception_tables.dart';

part 'app_database.g.dart';

void _openSqlCipherOnAndroid() {
  if (Platform.isAndroid) {
    open.overrideFor(OperatingSystem.android, openCipherOnAndroid);
  }
}

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
  TextColumn get userName => text().withDefault(const Constant(''))();
  IntColumn get age => integer().nullable()();
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
  TextColumn get flow => text().withDefault(const Constant('None'))();
  BoolColumn get spotting => boolean().withDefault(const Constant(false))();
  IntColumn get energyLevel =>
      integer().withDefault(const Constant(3))(); // 1 to 5
  IntColumn get painLevel =>
      integer().withDefault(const Constant(0))(); // 0 to 5
  TextColumn get mood => text().nullable()();
  IntColumn get stressLevel =>
      integer().withDefault(const Constant(2))(); // 0 to 5
  RealColumn get sleepHours => real().nullable()();
  IntColumn get sleepQuality =>
      integer().withDefault(const Constant(3))(); // 1 to 5
  IntColumn get waterGlasses => integer().withDefault(const Constant(0))();
  TextColumn get appetite => text().nullable()();
  TextColumn get cravings => text().nullable()();
  TextColumn get exercise => text().nullable()();
  TextColumn get medication => text().nullable()();
  TextColumn get supplements => text().nullable()();
  BoolColumn get intimacy => boolean().withDefault(const Constant(false))();
  TextColumn get customSymptomsJson =>
      text().withDefault(const Constant('[]'))();
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
  TextColumn get category => text().withDefault(const Constant('General'))();
  TextColumn get targetPhase => text().withDefault(
    const Constant('All'),
  )(); // Menstrual, Follicular, Ovulation, Luteal, All
  TextColumn get recommendedEnergy =>
      text().withDefault(const Constant('Flexible'))(); // Low, Moderate, High
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get dueDate => dateTime().nullable()();
  DateTimeColumn get scheduledDate => dateTime().nullable()();
  IntColumn get scheduledTimeMinutes => integer().nullable()();
  DateTimeColumn get reminderAt => dateTime().nullable()();
  TextColumn get recurrenceRule => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('Inbox'))();
  DateTimeColumn get completedAt => dateTime().nullable()();
  IntColumn get estimatedDurationMinutes =>
      integer().withDefault(const Constant(30))();
  TextColumn get cycleRecommendationTag => text().nullable()();
  TextColumn get priority => text().withDefault(const Constant('Normal'))();
}

// 11. FocusSessions
class FocusSessions extends Table with AuditColumns {
  TextColumn get title => text()();
  IntColumn get taskId => integer().nullable()();
  DateTimeColumn get startedAt => dateTime().nullable()();
  IntColumn get durationMinutes => integer()();
  IntColumn get breakMinutes => integer().withDefault(const Constant(5))();
  IntColumn get elapsedSeconds => integer().withDefault(const Constant(0))();
  TextColumn get status => text().withDefault(const Constant('Completed'))();
  DateTimeColumn get completedAt => dateTime().nullable()();
}

// 12. Routines
class Routines extends Table with AuditColumns {
  TextColumn get title => text()();
  TextColumn get frequency => text()(); // daily, phase_based
  TextColumn get weekdaysJson => text().withDefault(const Constant('[]'))();
  IntColumn get preferredTimeMinutes => integer().nullable()();
  DateTimeColumn get reminderAt => dateTime().nullable()();
  IntColumn get streakCount => integer().withDefault(const Constant(0))();
  TextColumn get completionHistoryJson =>
      text().withDefault(const Constant('[]'))();
  DateTimeColumn get pausedUntil => dateTime().nullable()();
  DateTimeColumn get archivedAt => dateTime().nullable()();
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
  TextColumn get recipeId => text().withDefault(const Constant(''))();
  TextColumn get recipeTitle => text().nullable()();
  TextColumn get mealType => text()();
  IntColumn get servings => integer().withDefault(const Constant(2))();
  TextColumn get selectedMemberIdsJson =>
      text().withDefault(const Constant('[]'))();
  TextColumn get notes => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('planned'))();
}

// 16. MealLogs
class MealLogs extends Table with AuditColumns {
  DateTimeColumn get loggedAt => dateTime()();
  TextColumn get mealTitle => text()();
  TextColumn get notes => text().nullable()();
}

// 16b. SavedMeals
class SavedMeals extends Table with AuditColumns {
  TextColumn get mealId => text()();
  DateTimeColumn get savedAt => dateTime()();
}

// 16c. MealPreparationEntries
class MealPreparationEntries extends Table with AuditColumns {
  TextColumn get mealId => text()();
  DateTimeColumn get preparedAt => dateTime()();
  DateTimeColumn get date => dateTime()();
  TextColumn get mealType => text()();
  IntColumn get servings => integer().withDefault(const Constant(2))();
  IntColumn get cycleDay => integer().nullable()();
  TextColumn get cyclePhase => text().nullable()();
  IntColumn get rating => integer().nullable()();
  TextColumn get notes => text().nullable()();
}

// 17. PantryItems
class PantryItems extends Table with AuditColumns {
  TextColumn get ingredientId => text().withDefault(const Constant(''))();
  TextColumn get name => text()();
  RealColumn get quantity => real()();
  TextColumn get unit => text()();
  TextColumn get category => text().withDefault(const Constant('General'))();
  BoolColumn get lowStock => boolean().withDefault(const Constant(false))();
  DateTimeColumn get expiryDate => dateTime().nullable()();
  DateTimeColumn get purchaseDate => dateTime().nullable()();
  RealColumn get minimumStockLevel => real().nullable()();
  TextColumn get storageLocation =>
      text().withDefault(const Constant('Pantry'))();
  BoolColumn get opened => boolean().withDefault(const Constant(false))();
  TextColumn get notes => text().nullable()();
}

// 18. ShoppingItems
class ShoppingItems extends Table with AuditColumns {
  TextColumn get ingredientId => text().withDefault(const Constant(''))();
  TextColumn get itemName => text()();
  TextColumn get quantity => text().nullable()();
  RealColumn get requiredQuantity => real().nullable()();
  TextColumn get unit => text().nullable()();
  TextColumn get category => text().withDefault(const Constant('General'))();
  TextColumn get sourceMealTitle => text().nullable()();
  TextColumn get sourceType => text().withDefault(const Constant('manual'))();
  TextColumn get sourceIdsJson => text().withDefault(const Constant('[]'))();
  BoolColumn get manuallyAdded =>
      boolean().withDefault(const Constant(false))();
  RealColumn get estimatedCost => real().nullable()();
  RealColumn get actualCost => real().nullable()();
  BoolColumn get isPurchased => boolean().withDefault(const Constant(false))();
}

// 18b. HouseholdProfiles
class HouseholdProfiles extends Table with AuditColumns {
  TextColumn get householdName => text().nullable()();
  IntColumn get adultCount => integer().withDefault(const Constant(1))();
  IntColumn get childCount => integer().withDefault(const Constant(0))();
  IntColumn get defaultServings => integer().withDefault(const Constant(2))();
  TextColumn get dietaryPreferencesJson =>
      text().withDefault(const Constant('[]'))();
  TextColumn get allergensJson => text().withDefault(const Constant('[]'))();
  TextColumn get dislikedIngredientsJson =>
      text().withDefault(const Constant('[]'))();
  IntColumn get weekdayPrepLimitMinutes =>
      integer().withDefault(const Constant(45))();
  IntColumn get weekendPrepLimitMinutes =>
      integer().withDefault(const Constant(90))();
  IntColumn get avoidRepeatDinnerDays =>
      integer().withDefault(const Constant(4))();
  RealColumn get weeklyBudget => real().nullable()();
  RealColumn get monthlyBudget => real().nullable()();
}

// 18c. FamilyMembers
class FamilyMembers extends Table with AuditColumns {
  TextColumn get name => text()();
  TextColumn get ageGroup => text().withDefault(const Constant('Adult'))();
  TextColumn get dietaryPreferencesJson =>
      text().withDefault(const Constant('[]'))();
  TextColumn get allergensJson => text().withDefault(const Constant('[]'))();
  TextColumn get dislikedIngredientsJson =>
      text().withDefault(const Constant('[]'))();
  TextColumn get notes => text().nullable()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
}

// 18d. LeftoverEntries
class LeftoverEntries extends Table with AuditColumns {
  IntColumn get sourceMealPlanEntryId => integer().nullable()();
  TextColumn get recipeId => text()();
  IntColumn get servingsRemaining => integer()();
  DateTimeColumn get preparedAt => dateTime()();
  DateTimeColumn get useByDate => dateTime().nullable()();
  TextColumn get notes => text().nullable()();
}

// 18e. IngredientPriceHistory
class IngredientPriceHistory extends Table with AuditColumns {
  TextColumn get ingredientId => text()();
  TextColumn get displayName => text()();
  RealColumn get quantity => real()();
  TextColumn get unit => text()();
  RealColumn get price => real()();
  DateTimeColumn get purchasedAt => dateTime()();
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

// 24e. NotificationInboxEntries
class NotificationInboxEntries extends Table with AuditColumns {
  IntColumn get notificationId => integer().unique()();
  TextColumn get category => text()();
  TextColumn get title => text()();
  TextColumn get explicitBody => text()();
  TextColumn get discreetBody => text()();
  DateTimeColumn get scheduledFor => dateTime()();
  DateTimeColumn get deliveredAt => dateTime().nullable()();
  DateTimeColumn get readAt => dateTime().nullable()();
  TextColumn get deepLink => text()();
  TextColumn get payload => text().nullable()();
  TextColumn get priority => text()();
}

// 25. AppSettings
class AppSettings extends Table with AuditColumns {
  TextColumn get themeMode =>
      text().withDefault(const Constant('system'))(); // light, dark, system
  TextColumn get cycleCalendarView =>
      text().withDefault(const Constant('Month'))();
  BoolColumn get hideCycleInPlanner =>
      boolean().withDefault(const Constant(false))();
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

// 28. OnboardingPreferences
class OnboardingPreferences extends Table with AuditColumns {
  // Cycle
  BoolColumn get isIrregular => boolean().withDefault(const Constant(false))();
  TextColumn get contraceptionStatus =>
      text().withDefault(const Constant('None'))();
  // Productivity
  TextColumn get wakeTime => text().withDefault(const Constant('07:00'))();
  TextColumn get sleepTime => text().withDefault(const Constant('22:30'))();
  IntColumn get focusSessionMinutes =>
      integer().withDefault(const Constant(25))();
  TextColumn get workType => text().withDefault(const Constant('Balanced'))();
  // Nutrition
  TextColumn get regionPreference =>
      text().withDefault(const Constant('Pan-Nigerian / All Regions'))();
  TextColumn get dietaryPattern =>
      text().withDefault(const Constant('Flexible / Balanced'))();
  TextColumn get prepTimePreference =>
      text().withDefault(const Constant('30 minutes or less'))();
  // Fitness
  TextColumn get fitnessLevel =>
      text().withDefault(const Constant('Intermediate'))();
  TextColumn get workoutLocation =>
      text().withDefault(const Constant('Home'))();
  BoolColumn get lowImpactOnly =>
      boolean().withDefault(const Constant(false))();
  // Privacy
  BoolColumn get enableDiscreetNotifications =>
      boolean().withDefault(const Constant(true))();
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
    SavedMeals,
    MealPreparationEntries,
    PantryItems,
    ShoppingItems,
    HouseholdProfiles,
    FamilyMembers,
    LeftoverEntries,
    IngredientPriceHistory,
    WorkoutPlans,
    WorkoutSessions,
    ExerciseLogs,
    JournalEntries,
    JournalAttachments,
    NotificationPreferences,
    NotificationPreferenceRows,
    NotificationScheduleStates,
    NotificationCompletionRecords,
    NotificationInboxEntries,
    AppSettings,
    ExportHistory,
    SubscriptionEntitlements,
    OnboardingPreferences,
    // TTC/Conception tables
    ConceptionProfiles,
    FertilityObservations,
    BasalTemperatureEntries,
    CervicalMucusEntries,
    OvulationTestEntries,
    IntimacyEntries,
    PregnancyTestEntries,
    ConceptionCycles,
    FertilityAssessments,
    PreconceptionChecklistItems,
    PartnerSharePermissions,
    FertilityReportExports,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 8;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(notificationPreferenceRows);
        await m.createTable(notificationScheduleStates);
        await m.createTable(notificationCompletionRecords);
      }
      if (from < 3) {
        await m.addColumn(dailyLogs, dailyLogs.flow);
        await m.addColumn(dailyLogs, dailyLogs.spotting);
        await m.addColumn(dailyLogs, dailyLogs.mood);
        await m.addColumn(dailyLogs, dailyLogs.stressLevel);
        await m.addColumn(dailyLogs, dailyLogs.sleepHours);
        await m.addColumn(dailyLogs, dailyLogs.sleepQuality);
        await m.addColumn(dailyLogs, dailyLogs.waterGlasses);
        await m.addColumn(dailyLogs, dailyLogs.appetite);
        await m.addColumn(dailyLogs, dailyLogs.cravings);
        await m.addColumn(dailyLogs, dailyLogs.exercise);
        await m.addColumn(dailyLogs, dailyLogs.medication);
        await m.addColumn(dailyLogs, dailyLogs.supplements);
        await m.addColumn(dailyLogs, dailyLogs.intimacy);
        await m.addColumn(dailyLogs, dailyLogs.customSymptomsJson);

        await m.addColumn(tasks, tasks.category);
        await m.addColumn(tasks, tasks.scheduledDate);
        await m.addColumn(tasks, tasks.scheduledTimeMinutes);
        await m.addColumn(tasks, tasks.reminderAt);
        await m.addColumn(tasks, tasks.recurrenceRule);
        await m.addColumn(tasks, tasks.status);
        await m.addColumn(tasks, tasks.completedAt);
        await m.addColumn(tasks, tasks.estimatedDurationMinutes);
        await m.addColumn(tasks, tasks.cycleRecommendationTag);

        await m.addColumn(focusSessions, focusSessions.taskId);
        await m.addColumn(focusSessions, focusSessions.startedAt);
        await m.addColumn(focusSessions, focusSessions.breakMinutes);
        await m.addColumn(focusSessions, focusSessions.elapsedSeconds);
        await m.addColumn(focusSessions, focusSessions.status);

        await m.addColumn(routines, routines.weekdaysJson);
        await m.addColumn(routines, routines.preferredTimeMinutes);
        await m.addColumn(routines, routines.reminderAt);
        await m.addColumn(routines, routines.streakCount);
        await m.addColumn(routines, routines.completionHistoryJson);
        await m.addColumn(routines, routines.pausedUntil);
        await m.addColumn(routines, routines.archivedAt);

        await m.addColumn(pantryItems, pantryItems.category);
        await m.addColumn(pantryItems, pantryItems.lowStock);
        await m.addColumn(pantryItems, pantryItems.expiryDate);

        await m.addColumn(shoppingItems, shoppingItems.quantity);
        await m.addColumn(shoppingItems, shoppingItems.unit);
        await m.addColumn(shoppingItems, shoppingItems.category);
        await m.addColumn(shoppingItems, shoppingItems.sourceMealTitle);

        await m.addColumn(appSettings, appSettings.cycleCalendarView);
        await m.addColumn(appSettings, appSettings.hideCycleInPlanner);
      }
      if (from < 4) {
        await m.createTable(onboardingPreferences);
      }
      if (from < 5) {
        // TTC/Conception tables
        await m.createTable(conceptionProfiles);
        await m.createTable(fertilityObservations);
        await m.createTable(basalTemperatureEntries);
        await m.createTable(cervicalMucusEntries);
        await m.createTable(ovulationTestEntries);
        await m.createTable(intimacyEntries);
        await m.createTable(pregnancyTestEntries);
        await m.createTable(conceptionCycles);
        await m.createTable(fertilityAssessments);
        await m.createTable(preconceptionChecklistItems);
        await m.createTable(partnerSharePermissions);
        await m.createTable(fertilityReportExports);
      }
      if (from < 6) {
        await m.createTable(savedMeals);
        await m.createTable(mealPreparationEntries);
      }
      if (from < 7) {
        await m.createTable(notificationInboxEntries);
      }
      if (from < 8) {
        await m.addColumn(mealPlans, mealPlans.recipeId);
        await m.addColumn(mealPlans, mealPlans.recipeTitle);
        await m.addColumn(mealPlans, mealPlans.servings);
        await m.addColumn(mealPlans, mealPlans.selectedMemberIdsJson);
        await m.addColumn(mealPlans, mealPlans.notes);
        await m.addColumn(mealPlans, mealPlans.status);

        await m.addColumn(pantryItems, pantryItems.ingredientId);
        await m.addColumn(pantryItems, pantryItems.purchaseDate);
        await m.addColumn(pantryItems, pantryItems.minimumStockLevel);
        await m.addColumn(pantryItems, pantryItems.storageLocation);
        await m.addColumn(pantryItems, pantryItems.opened);
        await m.addColumn(pantryItems, pantryItems.notes);

        await m.addColumn(shoppingItems, shoppingItems.ingredientId);
        await m.addColumn(shoppingItems, shoppingItems.requiredQuantity);
        await m.addColumn(shoppingItems, shoppingItems.sourceType);
        await m.addColumn(shoppingItems, shoppingItems.sourceIdsJson);
        await m.addColumn(shoppingItems, shoppingItems.manuallyAdded);
        await m.addColumn(shoppingItems, shoppingItems.estimatedCost);
        await m.addColumn(shoppingItems, shoppingItems.actualCost);

        await m.createTable(householdProfiles);
        await m.createTable(familyMembers);
        await m.createTable(leftoverEntries);
        await m.createTable(ingredientPriceHistory);
      }
    },
  );

  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      final passphrase = await SecureStorageService()
          .getOrCreateDatabasePassphrase();
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'quevaa_encrypted_db.sqlite'));
      return NativeDatabase.createInBackground(
        file,
        isolateSetup: _openSqlCipherOnAndroid,
        setup: (rawDb) {
          final escaped = passphrase.replaceAll("'", "''");
          rawDb.execute("PRAGMA key = '$escaped';");
        },
      );
    });
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
