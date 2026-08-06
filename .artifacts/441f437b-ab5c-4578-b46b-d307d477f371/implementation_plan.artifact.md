# Implementation Plan - Calendar Fixes and Robust Cycle Predictions

This plan addresses the "Calendar not working" report by improving the cycle engine's prediction logic, making it date-aware for historical browsing, and enhancing the "Year" and "Three-month" views with multiple future projections.

## User Review Required

> [!IMPORTANT]
> - The calendar will now show projected periods for the next 6 months, ensuring that the "Year" view doesn't look empty.
> - The "Cycle Day" calculation will now be relative to the selected date, meaning it will show correct data when browsing past cycles.
> - "Start/End Period" buttons in the day details will now be context-sensitive (e.g., you won't see "End period" if there isn't one ongoing).

## Proposed Changes

### 1. Cycle Engine Enhancements

#### [MODIFY] [cycle_engine_output.dart](file:///Users/okaguakenneth/Downloads/quevaa/lib/features/cycle/domain/models/cycle_engine_output.dart)
- Add `ProjectedPeriod` class to hold range-based predictions.
- Add `List<ProjectedPeriod> nextCycles` to `CycleEngineOutput`.

#### [MODIFY] [cycle_engine.dart](file:///Users/okaguakenneth/Downloads/quevaa/lib/features/cycle/domain/cycle_engine.dart)
- Update `calculate` to find the most recent period *before or on* the `targetDate`.
- Implement logic to project multiple future cycles based on the weighted median cycle length.
- Ensure special modes (Pregnancy/Postpartum) also return logical (though static) projections if appropriate.

### 2. Calendar UI Improvements

#### [MODIFY] [cycle_workspace_page.dart](file:///Users/okaguakenneth/Downloads/quevaa/lib/features/cycle/presentation/pages/cycle_workspace_page.dart)
- **Multi-cycle Markers**: Update `_calendarState` to check if a date falls within *any* of the `nextCycles` projections.
- **Context-Aware Actions**:
    - Update `_showDayDetails` to hide "Start period" if a confirmed period already exists on that date.
    - Hide "End period" if there is no ongoing period to end.
    - Improve labels for clarity.

### 3. State Management

#### [MODIFY] [cycle_workspace_provider.dart](file:///Users/okaguakenneth/Downloads/quevaa/lib/features/cycle/application/cycle_workspace_provider.dart)
- Ensure providers correctly invalidate and refresh when the underlying database tables change (this should already work via Drift StreamProviders).

## Verification Plan

### Automated Tests
- Update `test/cycle_engine_test.dart` to verify:
    - Cycle Day calculation for historical dates.
    - Existence of multiple projected periods in the output.

### Manual Verification
- **Year View**: Verify that multiple terracotta-colored ranges appear in future months.
- **Historical Browsing**: Select a date from last month's period and verify the "Cycle Day" in the header is correct (e.g., Day 5 of that past cycle).
- **Logging**: Verify that starting a period removes the projected markers for that range.
