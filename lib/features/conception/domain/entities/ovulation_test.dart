enum OvulationTestResult {
  notTaken,
  negative,
  high,
  positiveOrPeak,
  unclearOrInvalid,
}

extension OvulationTestResultLabel on OvulationTestResult {
  String get label {
    switch (this) {
      case OvulationTestResult.notTaken:
        return 'Not taken';
      case OvulationTestResult.negative:
        return 'Negative';
      case OvulationTestResult.high:
        return 'High';
      case OvulationTestResult.positiveOrPeak:
        return 'Positive or peak';
      case OvulationTestResult.unclearOrInvalid:
        return 'Unclear or invalid';
    }
  }

  bool get suggestsApproachingOvulation {
    return this == OvulationTestResult.high ||
        this == OvulationTestResult.positiveOrPeak;
  }
}

class OvulationTestEntry {
  final DateTime testedAt;
  final OvulationTestResult result;
  final String? brand;
  final String? localPhotoPath;

  const OvulationTestEntry({
    required this.testedAt,
    required this.result,
    this.brand,
    this.localPhotoPath,
  });
}
