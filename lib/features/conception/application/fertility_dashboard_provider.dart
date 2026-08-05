import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/engines/fertility_engine.dart';
import '../domain/entities/fertility_assessment.dart';
import 'conception_controller.dart';

final fertilityEngineProvider = Provider<FertilityEngine>(
  (ref) => const FertilityEngine(),
);

final fertilityDashboardProvider = Provider<FertilityAssessment>((ref) {
  final conception = ref.watch(conceptionControllerProvider);
  final engine = ref.watch(fertilityEngineProvider);

  return engine.assess(
    profile: conception.profile,
    observations: conception.observations,
  );
});
