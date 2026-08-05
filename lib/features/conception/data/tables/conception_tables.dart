import 'package:drift/drift.dart';

class ConceptionProfiles extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get status => text()();
  DateTimeColumn get tryingStartDate => dateTime()();
  DateTimeColumn get lastPeriodStartDate => dateTime()();
  TextColumn get previousPeriodStartDatesJson =>
      text().withDefault(const Constant('[]'))();
  IntColumn get typicalCycleLength =>
      integer().withDefault(const Constant(28))();
  IntColumn get typicalPeriodDuration =>
      integer().withDefault(const Constant(5))();
  BoolColumn get cyclesUsuallyRegular =>
      boolean().withDefault(const Constant(true))();
  DateTimeColumn get contraceptionStoppedDate => dateTime().nullable()();
  BoolColumn get usesOvulationTests =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get tracksBasalTemperature =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get tracksCervicalMucus =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get logsIntimacy => boolean().withDefault(const Constant(false))();
  BoolColumn get intimacyExtraPrivacyEnabled =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get prenatalReminderEnabled =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get partnerSupportEnabled =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get gentleModeEnabled =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get hideCountdown =>
      boolean().withDefault(const Constant(false))();
  TextColumn get healthConditions => text().nullable()();
  TextColumn get medications => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

class FertilityObservations extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime()();
  TextColumn get pelvicSensation =>
      text().withDefault(const Constant('none'))();
  BoolColumn get spotting => boolean().withDefault(const Constant(false))();
  IntColumn get libido => integer().withDefault(const Constant(3))();
  IntColumn get mood => integer().withDefault(const Constant(3))();
  IntColumn get energy => integer().withDefault(const Constant(3))();
  RealColumn get sleepHours => real().withDefault(const Constant(7))();
  IntColumn get stress => integer().withDefault(const Constant(3))();
  BoolColumn get medicationLogged =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get prenatalSupplement =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get illness => boolean().withDefault(const Constant(false))();
  BoolColumn get travel => boolean().withDefault(const Constant(false))();
  TextColumn get encryptedPrivateNote => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}

class BasalTemperatureEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get measuredAt => dateTime()();
  RealColumn get temperature => real()();
  TextColumn get unit => text().withDefault(const Constant('celsius'))();
  TextColumn get location => text().withDefault(const Constant('oral'))();
  BoolColumn get poorSleep => boolean().withDefault(const Constant(false))();
  BoolColumn get feverOrIllness =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get alcohol => boolean().withDefault(const Constant(false))();
  BoolColumn get wokeUnusuallyEarly =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get disturbed => boolean().withDefault(const Constant(false))();
}

class CervicalMucusEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime()();
  TextColumn get type => text()();
  TextColumn get notes => text().nullable()();
}

class OvulationTestEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get testedAt => dateTime()();
  TextColumn get result => text()();
  TextColumn get brand => text().nullable()();
  TextColumn get localPhotoPath => text().nullable()();
}

class IntimacyEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get occurredAt => dateTime()();
  TextColumn get type => text()();
  BoolColumn get protected => boolean().nullable()();
  TextColumn get encryptedNotes => text().nullable()();
}

class PregnancyTestEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get testedAt => dateTime()();
  TextColumn get result => text()();
  TextColumn get localPhotoPath => text().nullable()();
}

class ConceptionCycles extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get periodStart => dateTime()();
  DateTimeColumn get periodEnd => dateTime().nullable()();
  DateTimeColumn get possibleOvulationStart => dateTime().nullable()();
  DateTimeColumn get possibleOvulationEnd => dateTime().nullable()();
  TextColumn get archivedReason => text().nullable()();
}

class FertilityAssessments extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get assessedAt => dateTime()();
  TextColumn get status => text()();
  TextColumn get confidence => text()();
  DateTimeColumn get fertileWindowStart => dateTime()();
  DateTimeColumn get fertileWindowEnd => dateTime()();
  DateTimeColumn get ovulationRangeStart => dateTime()();
  DateTimeColumn get ovulationRangeEnd => dateTime()();
  TextColumn get algorithmVersion => text()();
}

class PreconceptionChecklistItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get completedAt => dateTime().nullable()();
}

class PartnerSharePermissions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get permission => text()();
  BoolColumn get isEnabled => boolean().withDefault(const Constant(false))();
  DateTimeColumn get revokedAt => dateTime().nullable()();
}

class FertilityReportExports extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get exportedAt => dateTime()();
  TextColumn get includedSectionsJson => text()();
  TextColumn get destination => text()();
  TextColumn get algorithmVersion => text()();
}
