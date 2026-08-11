import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_provider.dart';
import 'conception_controller.dart';
import '../domain/entities/conception_profile.dart';

final conceptionModeActiveProvider = Provider<bool>((ref) {
  final state = ref.watch(conceptionControllerProvider);
  return state.profile?.status == ConceptionGoalStatus.tryingToConceive;
});

final persistedConceptionModeActiveProvider = StreamProvider<bool>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.conceptionProfiles)..limit(1)).watchSingleOrNull().map(
    (profile) => profile?.status == ConceptionGoalStatus.tryingToConceive.name,
  );
});

final intimacyPrivacyEnabledProvider = Provider<bool>((ref) {
  return ref
          .watch(conceptionControllerProvider)
          .profile
          ?.intimacyExtraPrivacyEnabled ??
      true;
});
