import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';

import '../domain/entities/conception_profile.dart';
import '../domain/entities/fertility_observation.dart';
import '../data/repositories/conception_repository.dart';
import '../../../../core/database/app_database.dart' as db;

class ConceptionState {
  final ConceptionProfile? profile;
  final List<FertilityObservation> observations;
  final Set<String> completedChecklistItems;
  final Set<String> partnerSharePermissions;
  final bool isLoading;

  const ConceptionState({
    this.profile,
    this.observations = const [],
    this.completedChecklistItems = const {},
    this.partnerSharePermissions = const {},
    this.isLoading = false,
  });

  ConceptionState copyWith({
    ConceptionProfile? profile,
    List<FertilityObservation>? observations,
    Set<String>? completedChecklistItems,
    Set<String>? partnerSharePermissions,
    bool? isLoading,
  }) {
    return ConceptionState(
      profile: profile ?? this.profile,
      observations: observations ?? this.observations,
      completedChecklistItems:
          completedChecklistItems ?? this.completedChecklistItems,
      partnerSharePermissions:
          partnerSharePermissions ?? this.partnerSharePermissions,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class ConceptionController extends StateNotifier<ConceptionState> {
  final ConceptionRepository? _repository;

  ConceptionController([this._repository])
    : super(
        ConceptionState(
          profile: ConceptionProfile(
            status: ConceptionGoalStatus.paused,
            tryingStartDate: DateTime.now(),
            lastPeriodStartDate: DateTime.now(),
          ),
          isLoading: false,
        ),
      ) {
    if (_repository != null) {
      _init();
    }
  }

  Future<void> _init() async {
    final repository = _repository;
    if (repository == null) return;
    final profileData = await repository.getActiveProfile();
    final profile = profileData as ConceptionProfile?;

    final observations = (await repository.getObservations())
        .cast<FertilityObservation>();

    final checklist = await repository.getChecklistItems();
    final permissions = await repository.getPermissions();

    state = state.copyWith(
      profile: profile,
      observations: observations,
      completedChecklistItems: checklist
          .where((c) => c.isCompleted)
          .map((c) => c.title)
          .toSet(),
      partnerSharePermissions: permissions
          .where((p) => p.isEnabled)
          .map((p) => p.permission)
          .toSet(),
      isLoading: false,
    );
  }

  Future<void> enterConceptionMode() async {
    if (state.profile == null) return;
    final updatedProfile = state.profile!.copyWith(
      status: ConceptionGoalStatus.tryingToConceive,
    );

    state = state.copyWith(profile: updatedProfile);

    // Save to DB
    await _repository?.saveProfile(
      db.ConceptionProfilesCompanion(status: Value(updatedProfile.status.name)),
    );
  }

  Future<void> pausePredictionsForCycle() async {
    if (state.profile == null) return;
    final updatedProfile = state.profile!.copyWith(gentleModeEnabled: true);

    state = state.copyWith(profile: updatedProfile);

    await _repository?.saveProfile(
      const db.ConceptionProfilesCompanion(gentleModeEnabled: Value(true)),
    );
  }

  Future<void> leaveConceptionMode() async {
    if (state.profile == null) return;
    final updatedProfile = state.profile!.copyWith(
      status: ConceptionGoalStatus.paused,
    );

    state = state.copyWith(profile: updatedProfile);

    await _repository?.saveProfile(
      db.ConceptionProfilesCompanion(status: Value(updatedProfile.status.name)),
    );
  }

  void updateProfile(ConceptionProfile profile) {
    _repository?.saveProfile(
      db.ConceptionProfilesCompanion(status: Value(profile.status.name)),
    );
    state = state.copyWith(profile: profile);
  }

  Future<void> logObservation(FertilityObservation observation) async {
    await _repository?.saveObservation(
      db.FertilityObservationsCompanion(date: Value(observation.date)),
    );

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

  Future<void> toggleChecklistItem(String item) async {
    final updated = {...state.completedChecklistItems};
    final isCompleted = !updated.contains(item);

    if (isCompleted) {
      updated.add(item);
    } else {
      updated.remove(item);
    }

    if (_repository != null) {
      final items = await _repository.getChecklistItems();
      final dbItem = items.where((c) => c.title == item).firstOrNull;
      if (dbItem != null) {
        await _repository.toggleChecklistItem(dbItem.id, isCompleted);
      }
    }

    state = state.copyWith(completedChecklistItems: updated);
  }

  Future<void> togglePartnerSharePermission(String permission) async {
    final updated = {...state.partnerSharePermissions};
    final isEnabled = !updated.contains(permission);

    if (isEnabled) {
      updated.add(permission);
    } else {
      updated.remove(permission);
    }

    if (_repository != null) {
      final permissions = await _repository.getPermissions();
      final dbPerm = permissions
          .where((p) => p.permission == permission)
          .firstOrNull;
      if (dbPerm != null) {
        await _repository.togglePermission(dbPerm.id, isEnabled);
      }
    }

    state = state.copyWith(partnerSharePermissions: updated);
  }
}

final conceptionControllerProvider =
    StateNotifierProvider<ConceptionController, ConceptionState>((ref) {
      final repository = ref.watch(conceptionRepositoryProvider);
      return ConceptionController(repository);
    });
