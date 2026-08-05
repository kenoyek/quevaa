import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/basal_temperature.dart';
import '../domain/entities/fertility_observation.dart';
import 'conception_controller.dart';

class FertilityChartState {
  final List<FertilityObservation> observations;
  final List<BasalTemperatureEntry> temperatures;

  const FertilityChartState({
    required this.observations,
    required this.temperatures,
  });
}

final fertilityChartProvider = Provider<FertilityChartState>((ref) {
  final observations =
      ref.watch(conceptionControllerProvider).observations.toList()
        ..sort((a, b) => a.date.compareTo(b.date));
  final temperatures = observations
      .map((entry) => entry.basalTemperature)
      .whereType<BasalTemperatureEntry>()
      .toList();

  return FertilityChartState(
    observations: observations,
    temperatures: temperatures,
  );
});
