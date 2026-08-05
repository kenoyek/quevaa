import 'entities/task_entity.dart';

class ProductivityEngine {
  /// Filters and ranks tasks according to self-reported energy, pain level, and due dates.
  static List<TaskEntity> rankTasks({
    required List<TaskEntity> tasks,
    required int userEnergyLevel, // 1 to 5
    required int userPainLevel, // 0 to 5
  }) {
    final pendingTasks = tasks.where((t) => !t.isCompleted).toList();

    pendingTasks.sort((a, b) {
      // 1. High priority tasks always rank first regardless of energy
      if (a.priority == 'High' && b.priority != 'High') return -1;
      if (b.priority == 'High' && a.priority != 'High') return 1;

      // 2. Match energy level
      final aSuitability = _calculateEnergySuitability(
        a.energyTag,
        userEnergyLevel,
        userPainLevel,
      );
      final bSuitability = _calculateEnergySuitability(
        b.energyTag,
        userEnergyLevel,
        userPainLevel,
      );

      return bSuitability.compareTo(aSuitability);
    });

    return pendingTasks;
  }

  static int _calculateEnergySuitability(
    EnergyTag tag,
    int energyLevel,
    int painLevel,
  ) {
    if (painLevel >= 3 || energyLevel <= 2) {
      // Recovery mode: Low energy tasks rank highest
      if (tag == EnergyTag.low) return 10;
      if (tag == EnergyTag.flexible) return 5;
      if (tag == EnergyTag.moderate) return 2;
      return 0; // High energy tasks rank lowest
    } else if (energyLevel >= 4) {
      // High energy mode: High energy tasks rank highest
      if (tag == EnergyTag.high) return 10;
      if (tag == EnergyTag.moderate) return 7;
      if (tag == EnergyTag.flexible) return 5;
      return 3;
    } else {
      // Moderate energy mode
      if (tag == EnergyTag.moderate) return 10;
      if (tag == EnergyTag.flexible) return 8;
      if (tag == EnergyTag.low) return 6;
      return 2;
    }
  }
}
