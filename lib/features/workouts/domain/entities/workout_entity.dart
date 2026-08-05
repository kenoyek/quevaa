class ExerciseItem {
  final String name;
  final String durationOrReps;
  final String modification;

  const ExerciseItem({
    required this.name,
    required this.durationOrReps,
    required this.modification,
  });
}

class WorkoutEntity {
  final String id;
  final String title;
  final String
  category; // Gentle Mobility, Stretching, Walking, Yoga-Inspired Mobility, Low-Impact Cardio, Bodyweight Strength, Resistance-Band Training, Dumbbell Strength, Core Stability, Dance Fitness, Recovery Sessions, Breathing Exercises
  final String targetPhase; // Menstrual, Follicular, Ovulation, Luteal, All
  final int durationMinutes;
  final String intensity; // Gentle, Moderate, High
  final List<String> equipmentRequired;
  final List<ExerciseItem> warmup;
  final List<ExerciseItem> mainExercises;
  final List<ExerciseItem> cooldown;
  final List<String> bodyPartsEngaged;

  const WorkoutEntity({
    required this.id,
    required this.title,
    required this.category,
    this.targetPhase = 'All',
    required this.durationMinutes,
    required this.intensity,
    this.equipmentRequired = const ['None / Mat'],
    required this.warmup,
    required this.mainExercises,
    required this.cooldown,
    this.bodyPartsEngaged = const ['Full Body'],
  });

  static const String preWorkoutSafetyPrompt =
      'Stop and seek professional advice if you experience severe pain, dizziness, fainting, chest pain, or unusual bleeding. The WHO recommends at least 150 minutes of moderate-intensity activity weekly, adapted to your abilities.';
}
