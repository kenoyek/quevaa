import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/conception_profile.dart';
import '../domain/entities/fertility_observation.dart';
import '../data/repositories/conception_repository.dart';
import '../../../../core/analytics/app_logger.dart';

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
  Future<void>? _initialization;

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
      _initialization = _init();
    }
  }

  Future<void> _init() async {
    final repository = _repository;
    if (repository == null) return;
    try {
      final profile = await repository.getActiveProfile();
      final observations = await repository.getObservations();

      final checklist = await repository.getChecklistItems();
      final permissions = await repository.getPermissions();

      if (!mounted) return;
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
    } catch (_) {
      AppLogger.error('Could not load conception history');
    }
  }

  Future<void> enterConceptionMode() async {
    await _initialization;
    if (!mounted) return;
    final profile = state.profile;
    if (profile != null) {
      await updateProfile(
        profile.copyWith(status: ConceptionGoalStatus.tryingToConceive),
      );
    }
  }

  Future<void> pausePredictionsForCycle() async {
    await _initialization;
    if (!mounted) return;
    final profile = state.profile;
    if (profile != null) {
      await updateProfile(profile.copyWith(gentleModeEnabled: true));
    }
  }

  Future<void> leaveConceptionMode() async {
    await _initialization;
    if (!mounted) return;
    final profile = state.profile;
    if (profile != null) {
      await updateProfile(
        profile.copyWith(status: ConceptionGoalStatus.paused),
      );
    }
  }

  Future<void> updateProfile(ConceptionProfile profile) async {
    await _initialization;
    if (!mounted) return;
    await _repository?.saveProfile(profile);
    if (mounted) state = state.copyWith(profile: profile);
  }

  Future<void> logObservation(FertilityObservation observation) async {
    await _initialization;
    if (!mounted) return;
    final repository = _repository;
    if (repository != null) {
      await repository.saveObservation(observation);
      final observations = await repository.getObservations();
      if (mounted) state = state.copyWith(observations: observations);
      return;
    }
    final date = observation.date;
    final remaining = state.observations.where(
      (entry) =>
          entry.date.year != date.year ||
          entry.date.month != date.month ||
          entry.date.day != date.day,
    );
    state = state.copyWith(observations: [observation, ...remaining]);
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
