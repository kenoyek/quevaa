# PredictionConfidence Runtime Fix

## Exact Class Definition

```dart
// lib/core/models/prediction_confidence.dart
enum PredictionConfidence { low, moderate, high }
```

`PredictionConfidence` is a standard Dart enum with three values.

## Why `.name` Failed

The original code called `output.confidence.name` where `output` was declared as `final dynamic output`. On a `dynamic` receiver, Dart performs runtime method dispatch. The enum `.name` getter (introduced in Dart 2.15) works on enums, but the first fix changed all calls from `.name` to `.label` — an extension getter — which made the problem worse.

## Why `.label` Also Failed

Extensions in Dart are **statically resolved at compile time**. When the receiver type is `dynamic`, the compiler cannot resolve extension getters. At runtime, Dart tries to find an instance getter named `label` on the `PredictionConfidence` class itself — which doesn't exist. Result:

```
NoSuchMethodError: Class 'PredictionConfidence' has no instance getter 'label'
Receiver: Instance of 'PredictionConfidence'
Tried calling: label
```

## Where Dynamic Entered the Pipeline

In `cycle_workspace_page.dart`, multiple widget classes declared their `output` field as `dynamic`:

| Widget / Function     | Line | Declaration            |
| --------------------- | ---- | ---------------------- |
| `_OverviewCards`       | 231  | `final dynamic output` |
| `_MonthGrid`          | 388  | `final dynamic output` |
| `_calendarState()`    | 1208 | `dynamic output`       |

Even though `currentCycleOutputProvider` returns `CycleEngineOutput` (strongly typed), passing it into these `dynamic` fields erased the type. Every subsequent property access — including `output.confidence` — returned `dynamic`, making the `.label` extension getter unreachable.

## Exact Crashing File and Lines

- **Primary crash**: `cycle_workspace_page.dart` line 263: `output.confidence.label` inside `_OverviewCards`
- **Secondary crash**: `cycle_workspace_page.dart` line 631: `selectedSnapshot.confidence.label` inside `_showDayDetails`
- **Tertiary crash**: `cycle_workspace_page.dart` line 54: `output.confidence.label` in `_CycleHeader` construction

The header at line 54 rendered "Prediction confidence: Low" only because it received the confidence as a pre-formatted `String` parameter. The calendar body called `.label` directly on `dynamic`, causing the crash.

## Fix Applied

### 1. Created top-level formatter (no extension, no dynamic)

```dart
// lib/core/models/prediction_confidence.dart
String formatPredictionConfidence(PredictionConfidence confidence) {
  switch (confidence) {
    case PredictionConfidence.low:    return 'Low';
    case PredictionConfidence.moderate: return 'Moderate';
    case PredictionConfidence.high:   return 'High';
  }
}

PredictionConfidence mapStoredConfidence(String? value) { ... }
```

### 2. Strongly typed all `dynamic output` declarations

```diff
- final dynamic output;
+ final CycleEngineOutput output;
```

Changed in `_OverviewCards`, `_MonthGrid`, and `_calendarState()`.

### 3. Replaced all `.label` calls with `formatPredictionConfidence()`

Every call site now uses the explicit top-level function:

```dart
formatPredictionConfidence(output.confidence)
```

### 4. Removed duplicate extension

Removed `PredictionConfidenceLabel` extension from `fertility_assessment.dart` (was a duplicate of `PredictionConfidencePresentation` in `prediction_confidence.dart`).

## Files Changed

| File | Change |
| ---- | ------ |
| `lib/core/models/prediction_confidence.dart` | Added `formatPredictionConfidence()` and `mapStoredConfidence()` top-level functions; simplified extension to delegate to them |
| `lib/features/cycle/presentation/pages/cycle_workspace_page.dart` | Changed 3× `dynamic output` → `CycleEngineOutput output`; replaced 3× `.label` → `formatPredictionConfidence()`; removed `(output as dynamic).hasEnoughData` cast |
| `lib/features/dashboard/presentation/pages/dashboard_page.dart` | Replaced `.label.toUpperCase()` → `formatPredictionConfidence().toUpperCase()` |
| `lib/features/cycle/presentation/widgets/cycle_diagnostics_sheet.dart` | Replaced `.label` → `formatPredictionConfidence()` |
| `lib/features/conception/presentation/pages/conception_dashboard_page.dart` | Added import; replaced `.label` → `formatPredictionConfidence()` |
| `lib/features/conception/domain/entities/fertility_assessment.dart` | Removed duplicate `PredictionConfidenceLabel` extension |
| `test/cycle_sync_integration_test.dart` | Replaced `.label` in assertion; added 4 regression tests |

## Tests Added

```
formatPredictionConfidence regression
  ✓ formats low confidence
  ✓ formats moderate confidence
  ✓ formats high confidence
  ✓ mapStoredConfidence handles all stored values (low, moderate, medium, high, null, unknown, empty string)
```

## Validation Commands and Results

```
flutter analyze       → No issues found!
flutter test          → 62/62 tests passed
flutter build apk --debug → ✓ Built build/app/outputs/flutter-apk/app-debug.apk
```
