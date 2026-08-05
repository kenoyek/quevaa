import 'package:flutter_test/flutter_test.dart';
import 'package:quevaa/features/workouts/domain/entities/workout_entity.dart';
import 'package:quevaa/features/workouts/domain/workout_recommendation_engine.dart';

void main() {
  group('Phase 9: Workout Recommendation Engine Unit Tests', () {
    final sampleWorkouts = [
      const WorkoutEntity(
        id: '1',
        title: 'Deep Pelvic Floor & Breathing',
        category: 'Breathing Exercises',
        durationMinutes: 15,
        intensity: 'Gentle',
        warmup: [],
        mainExercises: [
          ExerciseItem(
            name: 'Diaphragmatic Breathing',
            durationOrReps: '5 mins',
            modification: 'Seated',
          ),
        ],
        cooldown: [],
        bodyPartsEngaged: ['Core'],
      ),
      const WorkoutEntity(
        id: '2',
        title: 'Full Body Jump Squats HIIT',
        category: 'Bodyweight Strength',
        durationMinutes: 30,
        intensity: 'High',
        warmup: [],
        mainExercises: [
          ExerciseItem(
            name: 'Jump Squats',
            durationOrReps: '15 reps',
            modification: 'Air squats',
          ),
        ],
        cooldown: [],
        bodyPartsEngaged: ['Knee', 'Legs', 'Full Body'],
      ),
    ];

    test('Recommends Gentle Recovery workouts when pain level is high', () {
      final recommended = WorkoutRecommendationEngine.recommendWorkouts(
        availableWorkouts: sampleWorkouts,
        userEnergyLevel: 2,
        userPainLevel: 4,
        sleepHours: 5.5,
      );

      expect(recommended.length, 1);
      expect(recommended.first.intensity, 'Gentle');
    });

    test(
      'Excludes high-impact workouts engaging injured body parts (e.g. Knee)',
      () {
        final recommended = WorkoutRecommendationEngine.recommendWorkouts(
          availableWorkouts: sampleWorkouts,
          userEnergyLevel: 4,
          userPainLevel: 0,
          sleepHours: 8.0,
          activeInjuries: ['Knee'],
        );

        expect(recommended.any((w) => w.title.contains('HIIT')), false);
      },
    );

    test('Exercise Substitution creates low-impact modification', () {
      const original = ExerciseItem(
        name: 'Jump Squats',
        durationOrReps: '15 reps',
        modification: 'Air squats',
      );
      final substituted = WorkoutRecommendationEngine.substituteExercise(
        original,
      );

      expect(substituted.name.contains('Low-Impact Modification'), true);
    });
  });
}
