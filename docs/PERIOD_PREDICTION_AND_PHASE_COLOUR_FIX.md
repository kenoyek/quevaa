# Period Prediction & Cycle-Phase Visualisation Fix Report

## 1. Overview & Root Cause Analysis

### Previous Defect
The Quevaa cycle calendar was shading an excessively wide range of days (e.g. 7 or more days for a 4-day expected period) as predicted period days. 

### Pipeline & Root Cause Trace
1. **Uncertainty & Bleeding Range Merging**: In `CycleEngine`, future cycle projections created `ProjectedPeriod(min: center - margin, max: center + margin)`. 
2. **Calendar State Derivation**: `_calendarState` checked `output.nextCycles.any((p) => date is within [min .. max])` to flag `predictedPeriod = true`.
3. **Defect Impact**: For low-confidence predictions (where `margin = 3`), a 4-day period starting on August 8 (8–11 August) had a possible start range of August 5 to August 11. The calendar shaded the full union (August 5 to August 11) with predicted period bleeding styles.

---

## 2. Technical Architecture & Calculation Fixes

### Separation of Four Distinct Prediction Concepts
The domain model now strictly isolates:
1. **Central Estimated Start Date (`estimatedStartDate`)**: The most likely period start date (e.g. August 8, 2026).
2. **Possible Start-Date Range (`possibleStartRange`)**: The uncertainty window around start date based on confidence/variability (e.g. August 5–11 for margin = 3 or August 7–9 for margin = 1).
3. **Expected Period Duration (`expectedDurationDays`)**: Number of expected bleeding days (e.g. 4 days), calculated using explicit priority hierarchy.
4. **Central Predicted Bleeding Range (`predictedBleedingRange`)**: Calculated strictly as `[estimatedStartDate .. estimatedStartDate + expectedDurationDays - 1]` (e.g. August 8–11).

```dart
class PeriodPrediction {
  final DateTime estimatedStartDate;
  final DateRange possibleStartRange;
  final int expectedDurationDays;
  final DateRange predictedBleedingRange;
  final PredictionConfidence confidence;

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
}
```

### Duration Hierarchy Priority
1. User's recent completed period durations from history.
2. Weighted median of valid recent completed period durations.
3. User-configured typical period duration (`userConfiguredPeriodLength`).
4. Safe onboarding default (5 days) when no history exists.

---

## 3. UI Rendering & Theme-Aware Phase Styling

### Complete Cycle-Phase States (`CycleCalendarPhase`)
The canonical cycle engine (`CycleEngineOutput.getCalendarPhase`) evaluates every date in a cycle to determine its estimated phase:
- `menstrual`: Confirmed or central predicted bleeding days.
- `follicular`: Soft sage background tint.
- `fertileWindow`: Pale teal background tint.
- `estimatedOvulation`: Warm gold accent with plum border and ovulation indicator.
- `luteal`: Soft lavender background tint.

### Rounded Edge Shading for Predicted Periods
Central predicted bleeding days render with rounded edges:
- **Start Date (8 Aug)**: `BorderRadius.only(topLeft: 12, bottomLeft: 12)`
- **Middle Days (9–10 Aug)**: Connected `BorderRadius.zero`
- **End Date (11 Aug)**: `BorderRadius.only(topRight: 12, bottomRight: 12)`

### Semantic Theme Tokens (`AppColors`)
Light and Dark theme tokens ensure readable contrast:
- **Confirmed Period**: Deep Terracotta fill (`AppColors.cycleMenstrualConfirmedLight` / `Dark`) with white date text.
- **Predicted Period**: Soft Rose fill (`AppColors.cycleMenstrualPredictedLight` / `Dark`) with rose border.
- **Follicular Phase**: Soft Sage (`AppColors.cycleFollicularLight` / `Dark`).
- **Fertile Window**: Pale Teal (`AppColors.cycleFertileWindowLight` / `Dark`).
- **Estimated Ovulation**: Warm Gold fill & border (`AppColors.cycleOvulationLight` / `Dark`).
- **Luteal Phase**: Soft Lavender (`AppColors.cycleLutealLight` / `Dark`).

### Responsive Legend
The calendar key wraps cleanly at 320dp width across Light and Dark modes.

---

## 4. Today Dashboard & Notification Synchronization

### Today / Cycle Synchronization
Both `DashboardPage` (`_RhythmCard`) and `CycleWorkspacePage` consume the exact same `PeriodPrediction` from `currentCycleOutputProvider`:
- Expected start date (e.g. August 8)
- Expected duration & central bleeding range (e.g. 4 days: 8–11 August)
- Possible start range (e.g. 5–11 August / 7–9 August) displayed separately as context, not bleeding days.

### Notifications Copy
Local period notifications use central estimated start date:
- *"Your period may begin around 8 August."*

---

## 5. Automated Verification Results

### Unit, Calendar-State & Widget Tests (`flutter test`)
- All **72 unit, integration, and widget tests passed**.
- `test/cycle_engine_test.dart`: 4-day duration, 5-day duration, start uncertainty separation, month boundary, leap year (Feb 29), insufficient history handling, and history duration updates.
- `test/cycle_calendar_phase_rendering_test.dart`: Asserts that for August 2026:
  - 7 August is **not** styled as central predicted bleeding.
  - 8 August is central start.
  - 9 & 10 August are central middle days.
  - 11 August is central end.
  - 12 August is **not** central predicted bleeding.
  - 12–15 Aug are Follicular, 16–22 Aug Fertile, 21 Aug Ovulation, 27 Aug Luteal.
  - Renders at 320dp width without overflow and supports Light/Dark themes.

### Static Analysis (`flutter analyze`)
- Executed `flutter analyze`: **0 issues found**.

### Build Results
1. **Android Release App Bundle (`flutter build appbundle --release`)**:
   - `✓ Built build/app/outputs/bundle/release/app-release.aab (65.0MB)`
2. **Android Debug APK (`flutter build apk --debug`)**:
   - `✓ Built build/app/outputs/flutter-apk/app-debug.apk`
