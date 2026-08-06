enum PredictionConfidence { low, moderate, high }

/// Formats a strongly-typed [PredictionConfidence] into a user-facing label.
/// Does not rely on extension getters or dynamic property resolution.
String formatPredictionConfidence(PredictionConfidence confidence) {
  switch (confidence) {
    case PredictionConfidence.low:
      return 'Low';
    case PredictionConfidence.moderate:
      return 'Moderate';
    case PredictionConfidence.high:
      return 'High';
  }
}

/// Maps stored string values (from database, settings, or JSON) into a domain [PredictionConfidence].
PredictionConfidence mapStoredConfidence(String? value) {
  switch (value?.toLowerCase()) {
    case 'high':
      return PredictionConfidence.high;
    case 'moderate':
    case 'medium':
      return PredictionConfidence.moderate;
    case 'low':
    default:
      return PredictionConfidence.low;
  }
}

extension PredictionConfidencePresentation on PredictionConfidence {
  String get label => formatPredictionConfidence(this);

  static PredictionConfidence fromString(String? value) =>
      mapStoredConfidence(value);
}
