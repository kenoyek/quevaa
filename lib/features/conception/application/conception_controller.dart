import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/conception_profile.dart';
import '../domain/entities/fertility_observation.dart';

class ConceptionState {
  final ConceptionProfile profile;
  final List<FertilityObservation> observations;
  final Set<String> completedChecklistItems;
  final Set<String> partnerSharePermissions;

  const ConceptionState({
    required this.profile,
    required this.observations,
    this.completedChecklistItems = const {},
    this.partnerSharePermissions = const {},
  });

  ConceptionState copyWith({
    ConceptionProfile? profile,
    List<FertilityObservation>? observations,
    Set<String>? completedChecklistItems,
    Set<String>? partnerSharePermissions,
  }) {
    return ConceptionState(
      profile: profile ?? this.profile,
      observations: observations ?? this.observations,
      completedChecklistItems:
          completedChecklistItems ?? this.completedChecklistItems,
      partnerSharePermissions:
          partnerSharePermissions ?? this.partnerSharePermissions,
    );
  }
}

class ConceptionController extends StateNotifier<ConceptionState> {
  ConceptionController()
    : super(
        ConceptionState(
          profile: ConceptionProfile.defaultSample(),
          observations: const [],
        ),
      );

  void enterConceptionMode() {
    state = state.copyWith(
      profile: state.profile.copyWith(
        status: ConceptionGoalStatus.tryingToConceive,
      ),
    );
  }

  void pausePredictionsForCycle() {
    state = state.copyWith(
      profile: state.profile.copyWith(gentleModeEnabled: true),
    );
  }

  void leaveConceptionMode() {
    state = state.copyWith(
      profile: state.profile.copyWith(status: ConceptionGoalStatus.paused),
    );
  }

  void updateProfile(ConceptionProfile profile) {
    state = state.copyWith(profile: profile);
  }

  void logObservation(FertilityObservation observation) {
    final targetDay = DateTime(
      observation.date.year,
      observation.date.month,
      observation.date.day,
    );
    final filtered = state.observations.where((entry) {
      final day = DateTime(entry.date.year, entry.date.month, entry.date.day);
      return day != targetDay;
    });

    state = state.copyWith(observations: [observation, ...filtered]);
  }

  void toggleChecklistItem(String item) {
    final updated = {...state.completedChecklistItems};
    if (updated.contains(item)) {
      updated.remove(item);
    } else {
      updated.add(item);
    }
    state = state.copyWith(completedChecklistItems: updated);
  }

  void togglePartnerSharePermission(String permission) {
    final updated = {...state.partnerSharePermissions};
    if (updated.contains(permission)) {
      updated.remove(permission);
    } else {
      updated.add(permission);
    }
    state = state.copyWith(partnerSharePermissions: updated);
  }
}

final conceptionControllerProvider =
    StateNotifierProvider<ConceptionController, ConceptionState>(
      (ref) => ConceptionController(),
    );
