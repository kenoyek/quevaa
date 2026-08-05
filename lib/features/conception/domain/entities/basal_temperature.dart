enum TemperatureUnit { celsius, fahrenheit }

enum TemperatureLocation { oral, vaginal, wearable, other }

class BasalTemperatureEntry {
  final DateTime measuredAt;
  final double temperature;
  final TemperatureUnit unit;
  final TemperatureLocation location;
  final bool poorSleep;
  final bool feverOrIllness;
  final bool alcohol;
  final bool wokeUnusuallyEarly;
  final bool disturbed;

  const BasalTemperatureEntry({
    required this.measuredAt,
    required this.temperature,
    this.unit = TemperatureUnit.celsius,
    this.location = TemperatureLocation.oral,
    this.poorSleep = false,
    this.feverOrIllness = false,
    this.alcohol = false,
    this.wokeUnusuallyEarly = false,
    this.disturbed = false,
  });

  bool get isReliable {
    return !poorSleep &&
        !feverOrIllness &&
        !alcohol &&
        !wokeUnusuallyEarly &&
        !disturbed;
  }

  double get celsius {
    if (unit == TemperatureUnit.celsius) return temperature;
    return (temperature - 32) * 5 / 9;
  }
}
