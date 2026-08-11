import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/providers/database_provider.dart';

class ConceptionRepository {
  final AppDatabase _db;
  ConceptionRepository(this._db);

  // --- Profile ---
  Future<ConceptionProfile?> getActiveProfile() async {
    return await _db.select(_db.conceptionProfiles).getSingleOrNull();
  }

  Future<void> saveProfile(ConceptionProfilesCompanion profile) async {
    await _db.into(_db.conceptionProfiles).insertOnConflictUpdate(profile);
  }

  // --- Fertility Observations ---
  Future<List<FertilityObservation>> getObservations({
    DateTime? from,
    DateTime? to,
  }) async {
    final query = _db.select(_db.fertilityObservations);
    if (from != null && to != null) {
      query.where((tbl) => tbl.date.isBetweenValues(from, to));
    }
    return await query.get();
  }

  Future<void> saveObservation(FertilityObservationsCompanion obs) async {
    await _db.into(_db.fertilityObservations).insertOnConflictUpdate(obs);
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

final conceptionRepositoryProvider = Provider<ConceptionRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return ConceptionRepository(db);
});
