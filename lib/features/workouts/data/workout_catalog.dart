import '../domain/entities/workout_entity.dart';

const bundledWorkoutCatalog = [
  WorkoutEntity(
    id: 'gentle-mobility-15',
    title: 'Gentle Mobility Reset',
    category: 'Gentle Mobility',
    durationMinutes: 15,
    intensity: 'Gentle',
    warmup: [
      ExerciseItem(
        name: 'Breathing reset',
        durationOrReps: '2 min',
        modification: 'Sit or lie down with one hand on your belly.',
      ),
    ],
    mainExercises: [
      ExerciseItem(
        name: 'Cat-cow',
        durationOrReps: '8 reps',
        modification: 'Use a chair if floor work is uncomfortable.',
      ),
      ExerciseItem(
        name: 'Hip circles',
        durationOrReps: '45 sec each way',
        modification: 'Reduce range if the lower back feels tender.',
      ),
    ],
    cooldown: [
      ExerciseItem(
        name: 'Child pose breathing',
        durationOrReps: '2 min',
        modification: 'Place a pillow under your torso.',
      ),
    ],
  ),
  WorkoutEntity(
    id: 'walk-strength-25',
    title: 'Walk and Strength Blend',
    category: 'Walking',
    durationMinutes: 25,
    intensity: 'Moderate',
    warmup: [
      ExerciseItem(
        name: 'Easy walk',
        durationOrReps: '5 min',
        modification: 'Keep conversation pace.',
      ),
    ],
    mainExercises: [
      ExerciseItem(
        name: 'Brisk walk intervals',
        durationOrReps: '10 min',
        modification: 'Shorten intervals if energy dips.',
      ),
      ExerciseItem(
        name: 'Wall push-up',
        durationOrReps: '2 x 8',
        modification: 'Step closer to the wall.',
      ),
    ],
    cooldown: [
      ExerciseItem(
        name: 'Slow walk and calf stretch',
        durationOrReps: '5 min',
        modification: 'Hold a support for balance.',
      ),
    ],
  ),
  WorkoutEntity(
    id: 'strength-30',
    title: 'Mat Strength Flow',
    category: 'Bodyweight Strength',
    durationMinutes: 30,
    intensity: 'High',
    warmup: [
      ExerciseItem(
        name: 'Dynamic warm-up',
        durationOrReps: '5 min',
        modification: 'Keep all moves low impact.',
      ),
    ],
    mainExercises: [
      ExerciseItem(
        name: 'Squat to chair',
        durationOrReps: '3 x 10',
        modification: 'Sit fully between reps.',
      ),
      ExerciseItem(
        name: 'Glute bridge',
        durationOrReps: '3 x 12',
        modification: 'Reduce range if cramping.',
      ),
    ],
    cooldown: [
      ExerciseItem(
        name: 'Full-body stretch',
        durationOrReps: '5 min',
        modification: 'Skip any position that feels sharp.',
      ),
    ],
  ),
];
