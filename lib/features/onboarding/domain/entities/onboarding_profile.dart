class OnboardingProfile {
  // Cycle
  final DateTime? lastPeriodStartDate;
  final int averagePeriodDuration;
  final int averageCycleLength;
  final bool isIrregular;
  final String contraceptionStatus;
  final String primaryGoal;

  // Productivity
  final String wakeTime;
  final String sleepTime;
  final int focusSessionMinutes;
  final String workType;

  // Nutrition
  final String regionPreference;
  final String dietaryPattern;
  final String prepTimePreference;

  // Workout
  final String fitnessLevel;
  final String workoutLocation;
  final bool lowImpactOnly;

  // Privacy
  final bool enableBiometrics;
  final bool enableDiscreetNotifications;

  // Personalization
  final String userName;
  final int? age;

  const OnboardingProfile({
    this.lastPeriodStartDate,
    this.averagePeriodDuration = 5,
    this.averageCycleLength = 28,
    this.isIrregular = false,
    this.contraceptionStatus = 'None',
    this.primaryGoal = 'Understand my period',
    this.wakeTime = '07:00',
    this.sleepTime = '22:30',
    this.focusSessionMinutes = 25,
    this.workType = 'Balanced',
    this.regionPreference = 'Pan-Nigerian / All Regions',
    this.dietaryPattern = 'Flexible / Balanced',
    this.prepTimePreference = '30 minutes or less',
    this.fitnessLevel = 'Intermediate',
    this.workoutLocation = 'Home',
    this.lowImpactOnly = false,
    this.enableBiometrics = false,
    this.enableDiscreetNotifications = true,
    this.userName = '',
    this.age,
  });

  OnboardingProfile copyWith({
    DateTime? lastPeriodStartDate,
    int? averagePeriodDuration,
    int? averageCycleLength,
    bool? isIrregular,
    String? contraceptionStatus,
    String? primaryGoal,
    String? wakeTime,
    String? sleepTime,
    int? focusSessionMinutes,
    String? workType,
    String? regionPreference,
    String? dietaryPattern,
    String? prepTimePreference,
    String? fitnessLevel,
    String? workoutLocation,
    bool? lowImpactOnly,
    bool? enableBiometrics,
    bool? enableDiscreetNotifications,
    String? userName,
    int? age,
  }) {
    return OnboardingProfile(
      lastPeriodStartDate: lastPeriodStartDate ?? this.lastPeriodStartDate,
      averagePeriodDuration:
          averagePeriodDuration ?? this.averagePeriodDuration,
      averageCycleLength: averageCycleLength ?? this.averageCycleLength,
      isIrregular: isIrregular ?? this.isIrregular,
      contraceptionStatus: contraceptionStatus ?? this.contraceptionStatus,
      primaryGoal: primaryGoal ?? this.primaryGoal,
      wakeTime: wakeTime ?? this.wakeTime,
      sleepTime: sleepTime ?? this.sleepTime,
      focusSessionMinutes: focusSessionMinutes ?? this.focusSessionMinutes,
      workType: workType ?? this.workType,
      regionPreference: regionPreference ?? this.regionPreference,
      dietaryPattern: dietaryPattern ?? this.dietaryPattern,
      prepTimePreference: prepTimePreference ?? this.prepTimePreference,
      fitnessLevel: fitnessLevel ?? this.fitnessLevel,
      workoutLocation: workoutLocation ?? this.workoutLocation,
      lowImpactOnly: lowImpactOnly ?? this.lowImpactOnly,
      enableBiometrics: enableBiometrics ?? this.enableBiometrics,
      enableDiscreetNotifications:
          enableDiscreetNotifications ?? this.enableDiscreetNotifications,
      userName: userName ?? this.userName,
      age: age ?? this.age,
    );
  }
}
