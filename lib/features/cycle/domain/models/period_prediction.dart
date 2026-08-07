import '../../../../core/models/prediction_confidence.dart';
import 'date_range.dart';

/// Represents a single period prediction with clearly separated concepts:
/// - Central estimated start date
/// - Possible start-date range (uncertainty window)
/// - Expected duration in days
/// - Central predicted bleeding range (start + duration)
/// - Prediction confidence
class PeriodPrediction {
  /// The most likely start date (center of the uncertainty window).
  final DateTime estimatedStartDate;

  /// The range of possible start dates based on cycle variability.
  /// Width depends on confidence: ±1 (high), ±2 (moderate), ±3 (low).
  final DateRange possibleStartRange;

  /// Expected number of bleeding days, from history or user config.
  final int expectedDurationDays;

  /// The central predicted bleeding range:
  /// [estimatedStartDate .. estimatedStartDate + expectedDurationDays - 1].
  final DateRange predictedBleedingRange;

  /// How confident the engine is in this prediction.
  final PredictionConfidence confidence;

  const PeriodPrediction({
    required this.estimatedStartDate,
    required this.possibleStartRange,
    required this.expectedDurationDays,
    required this.predictedBleedingRange,
    required this.confidence,
  });

  /// Factory that computes bleeding range from start + duration.
  factory PeriodPrediction.fromEstimate({
    required DateTime estimatedStartDate,
    required DateRange possibleStartRange,
    required int expectedDurationDays,
    required PredictionConfidence confidence,
  }) {
    final bleedingEnd = estimatedStartDate.add(
      Duration(days: expectedDurationDays - 1),
    );
    return PeriodPrediction(
      estimatedStartDate: estimatedStartDate,
      possibleStartRange: possibleStartRange,
      expectedDurationDays: expectedDurationDays,
      predictedBleedingRange: DateRange(
        start: estimatedStartDate,
        end: bleedingEnd,
      ),
      confidence: confidence,
    );
  }

  /// Whether [date] falls within the central predicted bleeding range.
  bool isBleedingDay(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return !d.isBefore(predictedBleedingRange.start) &&
        !d.isAfter(predictedBleedingRange.end);
  }

  /// Whether [date] falls within the possible start range but NOT the
  /// central bleeding range. Used for subtle uncertainty indicators.
  bool isUncertaintyDay(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return !d.isBefore(possibleStartRange.start) &&
        !d.isAfter(possibleStartRange.end) &&
        !isBleedingDay(d);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PeriodPrediction &&
          runtimeType == other.runtimeType &&
          estimatedStartDate == other.estimatedStartDate &&
          possibleStartRange == other.possibleStartRange &&
          expectedDurationDays == other.expectedDurationDays &&
          predictedBleedingRange == other.predictedBleedingRange &&
          confidence == other.confidence;

  @override
  int get hashCode =>
      estimatedStartDate.hashCode ^
      possibleStartRange.hashCode ^
      expectedDurationDays.hashCode ^
      predictedBleedingRange.hashCode ^
      confidence.hashCode;
}
