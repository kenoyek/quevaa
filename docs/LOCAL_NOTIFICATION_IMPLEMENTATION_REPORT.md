# Quevaa Local Notification Implementation Report

## Architecture Implemented

- Added an offline local-notification stack using `flutter_local_notifications`, `timezone`, and `flutter_timezone`.
- Kept native plugin calls inside `core/notifications`.
- Added a pure `SmartNotificationEngine` and `NotificationPolicyEngine` for testable schedule generation.
- Added a diff-based `NotificationScheduler` that compares desired schedules with persisted fingerprints and native pending IDs.
- Added Drift persistence for notification preferences, schedule state, and completion records.

## Packages Added

- `flutter_timezone 5.1.0`

Existing compatible packages retained:

- `flutter_local_notifications 17.2.4`
- `timezone 0.9.4`

No Firebase, APNs remote push, Supabase notification, server, SaaS or network notification dependency was added.

## Files Created

- `lib/core/notifications/local_notification_service.dart`
- `lib/core/notifications/notification_initializer.dart`
- `lib/core/notifications/notification_channels.dart`
- `lib/core/notifications/notification_payload.dart`
- `lib/core/notifications/notification_id.dart`
- `lib/core/notifications/notification_permission_service.dart`
- `lib/core/notifications/notification_timezone_service.dart`
- `lib/core/notifications/notification_router.dart`
- `lib/core/notifications/notification_constants.dart`
- `lib/features/notifications/domain/**`
- `lib/features/notifications/application/**`
- `lib/features/notifications/data/**`
- `lib/features/notifications/presentation/**`
- `test/local_notification_system_test.dart`
- `docs/LOCAL_NOTIFICATION_TEST_PLAN.md`

## Files Modified

- `pubspec.yaml`
- `pubspec.lock`
- `lib/main.dart`
- `lib/app/router/app_router.dart`
- `lib/core/database/app_database.dart`
- `lib/core/database/app_database.g.dart`
- `lib/core/notifications/notification_service.dart`
- `android/app/src/main/AndroidManifest.xml`
- `ios/Runner/AppDelegate.swift`

## Android Configuration

- Added:
  - `POST_NOTIFICATIONS`
  - `RECEIVE_BOOT_COMPLETED`
  - `VIBRATE`
- Added plugin receivers:
  - `com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver`
  - `com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver`
- Did not add exact alarm, full-screen intent, DND bypass or notification policy access permissions.
- Uses `AndroidScheduleMode.inexactAllowWhileIdle`.

## iOS Configuration

- Added `flutter_local_notifications` import in `AppDelegate.swift`.
- Registered plugin callback for background notification action support.
- Initialization does not request alert, badge or sound permission automatically.
- Permission request is user-triggered from Notification Settings.
- No critical-alert entitlement or time-sensitive interruption level was added.

## Notification Categories

Implemented stable Android channels:

- `quevaa_cycle`
- `quevaa_conception`
- `quevaa_medication`
- `quevaa_tasks`
- `quevaa_wellness`
- `quevaa_reflection`

Typed notification enum covers cycle, TTC, medication, hydration, meals, workout, productivity, journal and weekly review reminders.

## Privacy Protections

- Default privacy mode is `discreet`.
- Supports `explicit`, `discreet`, and `hidden`.
- Payload contains only version, type, route, and optional local record ID.
- Payload parser rejects malformed payloads and unsupported routes.
- No cycle dates, intimacy details, journal text, pregnancy-test results or medical notes are placed in payloads.

## Smart Scheduling Rules

- Deterministic stable IDs based on type, entity ID and occurrence.
- Quiet hours default to 9:00 PM-8:00 AM.
- Ordinary reminders inside quiet hours move to the next allowed time.
- User-created medication reminders preserve selected time.
- Daily ordinary reminder cap defaults to 4.
- Rolling horizon is 30 days.
- Maximum pending Quevaa notifications is 48.
- Deduplicates by logical event and notification ID.
- TTC reminders schedule only in active Conception Mode.
- BBT and ovulation-test reminders suppress when entries already exist for that day.

## Permission Flow

- Initialization and permission requests are separate.
- Notification Settings includes the invitation:
  - "Stay gently prepared"
  - "Not now"
  - "Enable reminders"
- Denial does not break the app or trigger repeated prompts.

## Reconciliation Strategy

- `reconcileNotifications(reason)` loads preferences, checks permission, initializes timezone, generates desired schedules, applies policy, compares with persisted/native pending schedules, cancels obsolete reminders and schedules missing/changed reminders.
- Reconciliation reasons include app start, resume, timezone change, preference changes, cycle changes, conception data changes and manual refresh.
- A single active reconciliation future prevents concurrent reconciliation.

## Tests Added

- Stable ID generation
- Collision resistance
- Quiet-hour adjustment across midnight
- User-created reminder quiet-hour preservation
- Daily cap
- Rolling max pending cap
- Hidden privacy content
- TTC reminder generation
- BBT/LH suppression
- Payload rejection and parsing

## Limitations

- Notification action buttons are not fully wired to local completion mutations yet; taps and test notifications are implemented first.
- Physical-device validation is still required for Android reboot, Doze/OEM behavior, iOS Focus mode and terminated delivery.
- The app-lock queueing helper exists, but the current app lock service is not yet wired globally into notification routing.
- Release Android build may still be limited by unrelated Android plugin SDK constraints if present in the project.

## Commands Run

- `flutter pub add flutter_timezone`
- `dart run build_runner build --delete-conflicting-outputs`
- `dart format lib test`
- `dart format .`
- `flutter pub get`
- `flutter analyze`
- `flutter test`
- `flutter build appbundle --release`
- `flutter build ios --release --no-codesign`

## Build Results

- `flutter analyze`: passed, no issues found.
- `flutter test`: passed, 39 tests.
- `flutter build appbundle --release`: passed, built `build/app/outputs/bundle/release/app-release.aab` at 62.3 MB.
- `flutter build ios --release --no-codesign`: passed, built `build/ios/iphoneos/Runner.app` at 36.7 MB.
- Android build required a local Gradle override to compile Android library subprojects against SDK 36 while preserving target/min SDK behaviour.
- Release builds emitted plugin migration warnings for future Flutter/Kotlin and iOS Swift Package Manager support; these are upstream plugin compatibility warnings, not current build failures.
