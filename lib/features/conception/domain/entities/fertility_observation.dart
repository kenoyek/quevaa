import 'basal_temperature.dart';
import 'cervical_mucus_entry.dart';
import 'ovulation_test.dart';
import 'pregnancy_test.dart';

enum PelvicSensation { none, mildTwinge, cramping, pressure, unsure }

enum IntimacyType { intercourse, insemination }

class IntimacyEntry {
  final DateTime occurredAt;
  final IntimacyType type;
  final bool? protected;
  final String? notes;

  const IntimacyEntry({
    required this.occurredAt,
    this.type = IntimacyType.intercourse,
    this.protected,
    this.notes,
  });
}

class FertilityObservation {
  final DateTime date;
  final CervicalMucusEntry? cervicalMucus;
  final OvulationTestEntry? ovulationTest;
  final BasalTemperatureEntry? basalTemperature;
  final IntimacyEntry? intimacy;
  final PregnancyTestEntry? pregnancyTest;
  final PelvicSensation pelvicSensation;
  final bool spotting;
  final int libido;
  final int mood;
  final int energy;
  final double sleepHours;
  final int stress;
  final bool medicationLogged;
  final bool prenatalSupplement;
  final bool illness;
  final bool travel;
  final String? privateNote;

  const FertilityObservation({
    required this.date,
    this.cervicalMucus,
    this.ovulationTest,
    this.basalTemperature,
    this.intimacy,
    this.pregnancyTest,
    this.pelvicSensation = PelvicSensation.none,
    this.spotting = false,
    this.libido = 3,
    this.mood = 3,
    this.energy = 3,
    this.sleepHours = 7,
    this.stress = 3,
    this.medicationLogged = false,
    this.prenatalSupplement = false,
    this.illness = false,
    this.travel = false,
    this.privateNote,
  });
}
