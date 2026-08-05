enum PregnancyTestResult {
  notTaken,
  negative,
  positive,
  unclear,
  retestPlanned,
}

extension PregnancyTestResultLabel on PregnancyTestResult {
  String get label {
    switch (this) {
      case PregnancyTestResult.notTaken:
        return 'Not taken';
      case PregnancyTestResult.negative:
        return 'Negative';
      case PregnancyTestResult.positive:
        return 'Positive';
      case PregnancyTestResult.unclear:
        return 'Unclear';
      case PregnancyTestResult.retestPlanned:
        return 'Retest planned';
    }
  }
}

class PregnancyTestEntry {
  final DateTime testedAt;
  final PregnancyTestResult result;
  final String? localPhotoPath;

  const PregnancyTestEntry({
    required this.testedAt,
    required this.result,
    this.localPhotoPath,
  });
}
