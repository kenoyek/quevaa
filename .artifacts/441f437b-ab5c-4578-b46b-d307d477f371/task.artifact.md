# Task - Calendar and Prediction Fixes

## Engine & Models
- [x] Add `ProjectedPeriod` and `nextCycles` to `CycleEngineOutput`
- [x] Make `CycleEngine.calculate` date-aware (use most recent period relative to `targetDate`)
- [x] Implement multi-month period projection logic (6 months ahead)

## Calendar UI
- [x] Update `_calendarState` to highlight all projected ranges in the list
- [x] Update `_showDayDetails` to hide/show "Start/End Period" based on date context
- [x] Improve "Cycle Day" display logic for past/future dates

## Verification
- [x] Update `test/cycle_engine_test.dart`
- [x] Run `flutter analyze`
- [x] Manual verification in app (Historical vs. Future views)
