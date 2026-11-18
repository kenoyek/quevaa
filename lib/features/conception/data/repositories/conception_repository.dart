import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/providers/database_provider.dart';
import '../../../../core/security/secure_storage_service.dart';
import '../../domain/entities/basal_temperature.dart' as domain;
import '../../domain/entities/cervical_mucus_entry.dart' as domain;
import '../../domain/entities/conception_profile.dart' as domain;
import '../../domain/entities/fertility_observation.dart' as domain;
import '../../domain/entities/ovulation_test.dart' as domain;
import '../../domain/entities/pregnancy_test.dart' as domain;

class ConceptionRepository {
  final AppDatabase _db;
  ConceptionRepository(this._db);

  Future<domain.ConceptionProfile?> getActiveProfile() async {
    final row =
        await (_db.select(_db.conceptionProfiles)
              ..orderBy([
                (t) => OrderingTerm.desc(t.updatedAt),
                (t) => OrderingTerm.desc(t.id),
              ])
              ..limit(1))
            .getSingleOrNull();
    if (row == null) return null;
    return domain.ConceptionProfile(
      status: _enumValue(
        domain.ConceptionGoalStatus.values,
        row.status,
        domain.ConceptionGoalStatus.paused,
      ),
      tryingStartDate: row.tryingStartDate,
      lastPeriodStartDate: row.lastPeriodStartDate,
      previousPeriodStartDates: _periodDates(row.previousPeriodStartDatesJson),
      typicalCycleLength: row.typicalCycleLength,
      typicalPeriodDuration: row.typicalPeriodDuration,
      cyclesUsuallyRegular: row.cyclesUsuallyRegular,
      contraceptionStoppedDate: row.contraceptionStoppedDate,
      usesOvulationTests: row.usesOvulationTests,
      tracksBasalTemperature: row.tracksBasalTemperature,
      tracksCervicalMucus: row.tracksCervicalMucus,
      logsIntimacy: row.logsIntimacy,
      intimacyExtraPrivacyEnabled: row.intimacyExtraPrivacyEnabled,
      prenatalReminderEnabled: row.prenatalReminderEnabled,
      partnerSupportEnabled: row.partnerSupportEnabled,
      gentleModeEnabled: row.gentleModeEnabled,
      hideCountdown: row.hideCountdown,
      healthConditions: row.healthConditions,
      medications: row.medications,
    );
  }

  Future<void> saveProfile(domain.ConceptionProfile profile) async {
    await _db.transaction(() async {
      final row =
          await (_db.select(_db.conceptionProfiles)
                ..orderBy([
                  (t) => OrderingTerm.desc(t.updatedAt),
                  (t) => OrderingTerm.desc(t.id),
                ])
                ..limit(1))
              .getSingleOrNull();
      final now = DateTime.now();
      final data = ConceptionProfilesCompanion.insert(
        status: profile.status.name,
        tryingStartDate: profile.tryingStartDate,
        lastPeriodStartDate: profile.lastPeriodStartDate,
        previousPeriodStartDatesJson: Value(
          jsonEncode(
            profile.previousPeriodStartDates
                .map((date) => date.toIso8601String())
                .toList(),
          ),
        ),
        createdAt: row?.createdAt ?? now,
        updatedAt: now,
        typicalCycleLength: Value(profile.typicalCycleLength),
        typicalPeriodDuration: Value(profile.typicalPeriodDuration),
        cyclesUsuallyRegular: Value(profile.cyclesUsuallyRegular),
        contraceptionStoppedDate: Value(profile.contraceptionStoppedDate),
        usesOvulationTests: Value(profile.usesOvulationTests),
        tracksBasalTemperature: Value(profile.tracksBasalTemperature),
        tracksCervicalMucus: Value(profile.tracksCervicalMucus),
        logsIntimacy: Value(profile.logsIntimacy),
        intimacyExtraPrivacyEnabled: Value(profile.intimacyExtraPrivacyEnabled),
        prenatalReminderEnabled: Value(profile.prenatalReminderEnabled),
        partnerSupportEnabled: Value(profile.partnerSupportEnabled),
        gentleModeEnabled: Value(profile.gentleModeEnabled),
        hideCountdown: Value(profile.hideCountdown),
        healthConditions: Value(profile.healthConditions),
        medications: Value(profile.medications),
      );
      if (row == null) {
        await _db.into(_db.conceptionProfiles).insert(data);
      } else {
        await (_db.update(
          _db.conceptionProfiles,
        )..where((t) => t.id.equals(row.id))).write(data);
      }
    });
  }

  Future<List<domain.FertilityObservation>> getObservations() async {
    final rows =
        await (_db.select(_db.fertilityObservations)..orderBy([
              (t) => OrderingTerm.desc(t.date),
              (t) => OrderingTerm.desc(t.id),
            ]))
            .get();
    if (rows.isEmpty) return [];
    final temperatures = _latestByDay(
      await getTemperatures(),
      (entry) => entry.measuredAt,
    );
    final mucus = _latestByDay(await getMucusEntries(), (entry) => entry.date);
    final ovulation = _latestByDay(
      await getOvulationTests(),
      (entry) => entry.testedAt,
    );
    final intimacy = _latestByDay(
      await getIntimacyEntries(),
      (entry) => entry.occurredAt,
    );
    final pregnancy = _latestByDay(
      await getPregnancyTests(),
      (entry) => entry.testedAt,
    );
    final result = <domain.FertilityObservation>[];
    final seen = <DateTime>{};
    for (final row in rows) {
      final day = _day(row.date);
      if (!seen.add(day)) continue;
      final temperature = temperatures[day];
      final mucusEntry = mucus[day];
      final ovulationEntry = ovulation[day];
      final intimacyEntry = intimacy[day];
      final pregnancyEntry = pregnancy[day];
      result.add(
        domain.FertilityObservation(
          date: day,
          pelvicSensation: _enumValue(
            domain.PelvicSensation.values,
            row.pelvicSensation,
            domain.PelvicSensation.none,
          ),
          spotting: row.spotting,
          libido: row.libido,
          mood: row.mood,
          energy: row.energy,
          sleepHours: row.sleepHours,
          stress: row.stress,
          medicationLogged: row.medicationLogged,
          prenatalSupplement: row.prenatalSupplement,
          illness: row.illness,
          travel: row.travel,
          privateNote: await _readNote(row.encryptedPrivateNote),
          basalTemperature: temperature == null
              ? null
              : domain.BasalTemperatureEntry(
                  measuredAt: temperature.measuredAt,
                  temperature: temperature.temperature,
                  unit: _enumValue(
                    domain.TemperatureUnit.values,
                    temperature.unit,
                    domain.TemperatureUnit.celsius,
                  ),
                  location: _enumValue(
                    domain.TemperatureLocation.values,
                    temperature.location,
                    domain.TemperatureLocation.other,
                  ),
                  poorSleep: temperature.poorSleep,
                  feverOrIllness: temperature.feverOrIllness,
                  alcohol: temperature.alcohol,
                  wokeUnusuallyEarly: temperature.wokeUnusuallyEarly,
                  disturbed: temperature.disturbed,
                ),
          cervicalMucus: mucusEntry == null
              ? null
              : domain.CervicalMucusEntry(
                  date: mucusEntry.date,
                  type: _enumValue(
                    domain.CervicalMucusType.values,
                    mucusEntry.type,
                    domain.CervicalMucusType.unsure,
                  ),
                  notes: mucusEntry.notes,
                ),
          ovulationTest: ovulationEntry == null
              ? null
              : domain.OvulationTestEntry(
                  testedAt: ovulationEntry.testedAt,
                  result: _enumValue(
                    domain.OvulationTestResult.values,
                    ovulationEntry.result,
                    domain.OvulationTestResult.notTaken,
                  ),
                  brand: ovulationEntry.brand,
                  localPhotoPath: ovulationEntry.localPhotoPath,
                ),
          intimacy: intimacyEntry == null
              ? null
              : domain.IntimacyEntry(
                  occurredAt: intimacyEntry.occurredAt,
                  type: _enumValue(
                    domain.IntimacyType.values,
                    intimacyEntry.type,
                    domain.IntimacyType.intercourse,
                  ),
                  protected: intimacyEntry.protected,
                  notes: await _readNote(intimacyEntry.encryptedNotes),
                ),
          pregnancyTest: pregnancyEntry == null
              ? null
              : domain.PregnancyTestEntry(
                  testedAt: pregnancyEntry.testedAt,
                  result: _enumValue(
                    domain.PregnancyTestResult.values,
                    pregnancyEntry.result,
                    domain.PregnancyTestResult.notTaken,
                  ),
                  localPhotoPath: pregnancyEntry.localPhotoPath,
                ),
        ),
      );
    }
    return result;
  }

  Future<void> saveObservation(domain.FertilityObservation observation) async {
    final day = _day(observation.date);
    final note = await _encryptNote(observation.privateNote);
    final intimacyNote = await _encryptNote(observation.intimacy?.notes);
    await _db.transaction(() async {
      final existing =
          await (_db.select(_db.fertilityObservations)
                ..where((t) => t.date.equals(day))
                ..orderBy([(t) => OrderingTerm.desc(t.id)])
                ..limit(1))
              .getSingleOrNull();
      final data = FertilityObservationsCompanion.insert(
        date: day,
        createdAt: existing?.createdAt ?? DateTime.now(),
        pelvicSensation: Value(observation.pelvicSensation.name),
        encryptedPrivateNote: note == null ? const Value.absent() : Value(note),
        spotting: Value(observation.spotting),
        libido: Value(observation.libido),
        mood: Value(observation.mood),
        energy: Value(observation.energy),
        sleepHours: Value(observation.sleepHours),
        stress: Value(observation.stress),
        medicationLogged: Value(observation.medicationLogged),
        prenatalSupplement: Value(observation.prenatalSupplement),
        illness: Value(observation.illness),
        travel: Value(observation.travel),
      );
      if (existing == null) {
        await _db.into(_db.fertilityObservations).insert(data);
      } else {
        await (_db.update(
          _db.fertilityObservations,
        )..where((t) => t.id.equals(existing.id))).write(data);
      }
      if (observation.cervicalMucus case final entry?) {
        await saveMucusEntry(
          CervicalMucusEntriesCompanion.insert(
            date: entry.date,
            type: entry.type.name,
            notes: Value(entry.notes),
          ),
        );
      }
      if (observation.basalTemperature case final entry?) {
        await saveTemperature(
          BasalTemperatureEntriesCompanion.insert(
            measuredAt: entry.measuredAt,
            temperature: entry.temperature,
            unit: Value(entry.unit.name),
            location: Value(entry.location.name),
            poorSleep: Value(entry.poorSleep),
            feverOrIllness: Value(entry.feverOrIllness),
            alcohol: Value(entry.alcohol),
            wokeUnusuallyEarly: Value(entry.wokeUnusuallyEarly),
            disturbed: Value(entry.disturbed),
          ),
        );
      }
      if (observation.ovulationTest case final entry?
          when entry.result != domain.OvulationTestResult.notTaken) {
        await saveOvulationTest(
          OvulationTestEntriesCompanion.insert(
            testedAt: entry.testedAt,
            result: entry.result.name,
            brand: Value(entry.brand),
            localPhotoPath: Value(entry.localPhotoPath),
          ),
        );
      }
      if (observation.intimacy case final entry?) {
        await saveIntimacyEntry(
          IntimacyEntriesCompanion.insert(
            occurredAt: entry.occurredAt,
            type: entry.type.name,
            protected: Value(entry.protected),
            encryptedNotes: Value(intimacyNote),
          ),
        );
      }
      if (observation.pregnancyTest case final entry?
          when entry.result != domain.PregnancyTestResult.notTaken) {
        await savePregnancyTest(
          PregnancyTestEntriesCompanion.insert(
            testedAt: entry.testedAt,
            result: entry.result.name,
            localPhotoPath: Value(entry.localPhotoPath),
          ),
        );
      }
    });
  }

  // --- BBT ---
  Future<List<BasalTemperatureEntry>> getTemperatures({
    DateTime? from,
    DateTime? to,
  }) async {
    final query = _db.select(_db.basalTemperatureEntries);
    if (from != null && to != null) {
      query.where((tbl) => tbl.measuredAt.isBetweenValues(from, to));
    }
    return await query.get();
  }

  Future<void> saveTemperature(BasalTemperatureEntriesCompanion entry) async {
    await _db.into(_db.basalTemperatureEntries).insert(entry);
  }

  // --- Cervical Mucus ---
  Future<List<CervicalMucusEntry>> getMucusEntries({
    DateTime? from,
    DateTime? to,
  }) async {
    final query = _db.select(_db.cervicalMucusEntries);
    if (from != null && to != null) {
      query.where((tbl) => tbl.date.isBetweenValues(from, to));
    }
    return await query.get();
  }

  Future<void> saveMucusEntry(CervicalMucusEntriesCompanion entry) async {
    await _db.into(_db.cervicalMucusEntries).insert(entry);
  }

  // --- Ovulation Tests ---
  Future<List<OvulationTestEntry>> getOvulationTests({
    DateTime? from,
    DateTime? to,
  }) async {
    final query = _db.select(_db.ovulationTestEntries);
    if (from != null && to != null) {
      query.where((tbl) => tbl.testedAt.isBetweenValues(from, to));
    }
    return await query.get();
  }

  Future<void> saveOvulationTest(OvulationTestEntriesCompanion entry) async {
    await _db.into(_db.ovulationTestEntries).insert(entry);
  }

  // --- Intimacy ---
  Future<List<IntimacyEntry>> getIntimacyEntries({
    DateTime? from,
    DateTime? to,
  }) async {
    final query = _db.select(_db.intimacyEntries);
    if (from != null && to != null) {
      query.where((tbl) => tbl.occurredAt.isBetweenValues(from, to));
    }
    return await query.get();
  }

  Future<void> saveIntimacyEntry(IntimacyEntriesCompanion entry) async {
    await _db.into(_db.intimacyEntries).insert(entry);
  }

  // --- Pregnancy Tests ---
  Future<List<PregnancyTestEntry>> getPregnancyTests() async {
    return await _db.select(_db.pregnancyTestEntries).get();
  }

  Future<void> savePregnancyTest(PregnancyTestEntriesCompanion entry) async {
    await _db.into(_db.pregnancyTestEntries).insert(entry);
  }

  // --- Checklist ---
  Future<List<PreconceptionChecklistItem>> getChecklistItems() async {
    return await _db.select(_db.preconceptionChecklistItems).get();
  }

  Future<void> toggleChecklistItem(int id, bool completed) async {
    await (_db.update(
      _db.preconceptionChecklistItems,
    )..where((t) => t.id.equals(id))).write(
      PreconceptionChecklistItemsCompanion(isCompleted: Value(completed)),
    );
  }

  Future<void> insertDefaultChecklist() async {
    final count = await _db.preconceptionChecklistItems.count().getSingle();
    if (count == 0) {
      await _db.batch((batch) {
        batch.insertAll(_db.preconceptionChecklistItems, [
          PreconceptionChecklistItemsCompanion.insert(
            title: 'Start prenatal vitamins',
          ),
          PreconceptionChecklistItemsCompanion.insert(
            title: 'Schedule preconception checkup',
          ),
          PreconceptionChecklistItemsCompanion.insert(
            title: 'Check rubella immunity',
          ),
        ]);
      });
    }
  }

  // --- Partner Permissions ---
  Future<List<PartnerSharePermission>> getPermissions() async {
    return await _db.select(_db.partnerSharePermissions).get();
  }

  Future<void> togglePermission(int id, bool enabled) async {
    await (_db.update(_db.partnerSharePermissions)
          ..where((t) => t.id.equals(id)))
        .write(PartnerSharePermissionsCompanion(isEnabled: Value(enabled)));
  }
}

DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);

Map<DateTime, T> _latestByDay<T>(List<T> values, DateTime Function(T) time) {
  final days = <DateTime, T>{};
  for (final value in values) {
    final timestamp = time(value);
    final day = _day(timestamp);
    final previous = days[day];
    if (previous == null || !timestamp.isBefore(time(previous))) {
      days[day] = value;
    }
  }
  return days;
}

T _enumValue<T extends Enum>(List<T> values, String name, T fallback) =>
    values.where((value) => value.name == name).firstOrNull ?? fallback;

List<DateTime> _periodDates(String source) {
  try {
    final values = jsonDecode(source);
    if (values is! List) return [];
    return values.whereType<String>().map(DateTime.tryParse).nonNulls.toList();
  } on FormatException {
    return [];
  }
}

Future<String?> _encryptNote(String? note) async {
  if (note == null || note.trim().isEmpty) return null;
  return SecureStorageService().encryptJournalContent(note);
}

Future<String?> _readNote(String? note) async {
  if (note == null) return null;
  try {
    return await SecureStorageService().decryptJournalContent(note);
  } catch (_) {
    return null;
  }
}

final conceptionRepositoryProvider = Provider<ConceptionRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return ConceptionRepository(db);
});
