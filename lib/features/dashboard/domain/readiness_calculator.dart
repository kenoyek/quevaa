enum ReadinessScore { restore, gentle, balanced, energised }

class DailyReadinessResult {
  final ReadinessScore score;
  final String label;
  final String description;
  final String recommendedPriority;
  final List<String> lighterTasks;
  final String recommendedWorkout;
  final String mealHighlight;

  const DailyReadinessResult({
    required this.score,
    required this.label,
    required this.description,
    required this.recommendedPriority,
    required this.lighterTasks,
    required this.recommendedWorkout,
    required this.mealHighlight,
  });
}

class ReadinessCalculator {
  /// Computes non-medical daily readiness based on self-reported energy, sleep, pain, and cycle estimate.
  static DailyReadinessResult calculate({
    required int selfReportedEnergy, // 1 to 5
    required double sleepHours,
    required int painLevel, // 0 to 5
    required String estimatedPhase,
  }) {
    // Score calculation
    double scoreValue =
        (selfReportedEnergy * 20.0) +
        (sleepHours >= 7.5 ? 20.0 : 10.0) -
        (painLevel * 10.0);

    if (scoreValue <= 45 || painLevel >= 3) {
      return const DailyReadinessResult(
        score: ReadinessScore.restore,
        label: 'Restore',
        description:
            'Your body is asking for extra care and low-pressure activities today.',
        recommendedPriority: 'Administrative work & gentle planning',
        lighterTasks: [
          'Clear inbox & organize files',
          'Review notes for upcoming week',
        ],
        recommendedWorkout: 'Gentle Yin Yoga & Deep Breathing (15 mins)',
        mealHighlight: 'Ugu & Unripe Plantain Porridge with Warm Herbal Zobo',
      );
    } else if (scoreValue <= 65) {
      return const DailyReadinessResult(
        score: ReadinessScore.gentle,
        label: 'Gentle',
        description:
            'Steady, moderate pace. Focus on essential tasks without overextending.',
        recommendedPriority: 'Focus on 1 core priority task',
        lighterTasks: ['Draft project outlines', 'Catch up on team updates'],
        recommendedWorkout: 'Mindful Outdoor Walk & Light Stretch (20 mins)',
        mealHighlight: 'Fresh Catfish Pepper Soup with Boiled Yam',
      );
    } else if (scoreValue <= 85) {
      return const DailyReadinessResult(
        score: ReadinessScore.balanced,
        label: 'Balanced',
        description:
            'Good energy and focus. Great window for collaborative work and creative tasks.',
        recommendedPriority: 'Important meetings & collaborative projects',
        lighterTasks: ['Follow up on client requests', 'Review design drafts'],
        recommendedWorkout: 'Pilates Core Flow & Mat Strength (30 mins)',
        mealHighlight: 'Seafood Okra Soup with Steamed Okpa',
      );
    } else {
      return const DailyReadinessResult(
        score: ReadinessScore.energised,
        label: 'Energised',
        description:
            'High energy and strong focus! Excellent for starting new initiatives or high-demand work.',
        recommendedPriority: 'High-impact project launch or presentations',
        lighterTasks: ['Brainstorm new concepts', 'Strategic planning session'],
        recommendedWorkout: 'Full Body HIIT or Strength Training (40 mins)',
        mealHighlight: 'Sweet Potato & Fish Stew with Egusi & Ugu',
      );
    }
  }
}
