import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'conception_controller.dart';
import '../domain/entities/conception_profile.dart';

final conceptionModeActiveProvider = Provider<bool>((ref) {
  final state = ref.watch(conceptionControllerProvider);
  return state.profile.status == ConceptionGoalStatus.tryingToConceive;
});

final intimacyPrivacyEnabledProvider = Provider<bool>((ref) {
  return ref
      .watch(conceptionControllerProvider)
      .profile
      .intimacyExtraPrivacyEnabled;
});
