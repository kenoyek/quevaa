import 'entities/workout_entity.dart';

class WorkoutRecommendationEngine {
  /// Adapts workouts based on self-reported pain, energy, sleep quality, and active injuries.
  static List<WorkoutEntity> recommendWorkouts({
    required List<WorkoutEntity> availableWorkouts,
    required int userEnergyLevel, // 1 to 5
    required int userPainLevel, // 0 to 5
    required double sleepHours,
    List<String> activeInjuries = const [], // e.g. 'Knee', 'Lower Back'
  }) {
    return availableWorkouts.where((workout) {
      // 1. Injury exclusions
      for (final injury in activeInjuries) {
        final lowerInjury = injury.toLowerCase();
        if (workout.bodyPartsEngaged.any(
          (part) => part.toLowerCase().contains(lowerInjury),
        )) {
          // If knee injury and workout requires heavy lower body loading or jumping, exclude
          if (workout.category == 'Bodyweight Strength' ||
              workout.intensity == 'High') {
            return false;
          }
        }
      }

      // 2. High pain or low energy -> recommend Gentle/Recovery workouts only
      if (userPainLevel >= 3 || userEnergyLevel <= 2 || sleepHours < 6.0) {
        return workout.intensity == 'Gentle' ||
            workout.category == 'Breathing Exercises' ||
            workout.category == 'Stretching' ||
            workout.category == 'Gentle Mobility';
      }

      return true;
    }).toList();
  }

  /// Replaces an exercise item with a low-impact or modified substitute.
  static ExerciseItem substituteExercise(ExerciseItem original) {
    return ExerciseItem(
      name: '${original.name} (Low-Impact Modification)',
      durationOrReps: original.durationOrReps,
      modification:
          'Perform at slow tempo holding a steady breath without jumping.',
    );
  }
}
