# Quevaa

Quevaa is a premium offline-first Flutter mobile app for private cycle care, period tracking, trying-to-conceive support, daily wellness, Nigerian meal planning, workouts, productivity, private journaling, and doctor-ready reporting.

The app is designed to keep sensitive wellness data on the device. Core experiences avoid remote notification services, remote AI services, and cloud push dependencies.

## Highlights

- Period and cycle tracking with probabilistic range language
- Dedicated Trying to Conceive mode with fertility observations, LH tests, BBT, pregnancy-test journey, preconception wellness, and partner-support controls
- Mode switching between normal period tracking and Conception Mode without deleting records
- Premium onboarding, splash, app icon, and Quevaa branding assets
- Nigerian meal recommendations and preconception wellness meals
- Workout and daily readiness recommendations
- Private journal and local report/export foundations
- Offline local notification system using OS-scheduled notifications
- Notification privacy modes: explicit, discreet, hidden
- Quiet hours, daily caps, rolling schedule limits, stable deterministic notification IDs
- Android boot receiver configuration for scheduled local notifications
- iOS local-notification initialization without automatic permission prompts

## Offline Notifications

Quevaa uses local notifications only:

- No Firebase
- No Firebase Cloud Messaging
- No APNs remote push
- No notification server
- No Supabase notification service
- No background network requests
- No third-party notification SaaS

Notification scheduling is split into testable layers:

- `core/notifications`: plugin initialization, channels, timezone, permission flow, payloads, local scheduling
- `features/notifications/domain`: typed entities, enums, smart scheduling engine, policy engine
- `features/notifications/application`: Riverpod controller and providers
- `features/notifications/data`: Drift-backed local preferences and schedule state
- `features/notifications/presentation`: Notification Settings UI

See:

- [Local notification implementation report](docs/LOCAL_NOTIFICATION_IMPLEMENTATION_REPORT.md)
- [Local notification manual test plan](docs/LOCAL_NOTIFICATION_TEST_PLAN.md)

## Requirements

- Flutter 3+
- Dart SDK compatible with `pubspec.yaml`
- Xcode for iOS builds
- Android SDK with compile SDK 36 available for Android release builds

## Setup

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

## Run

```bash
flutter run
```

To run on a specific simulator or device:

```bash
flutter devices
flutter run -d <device-id>
```

## Validation

```bash
dart format .
flutter analyze
flutter test
flutter build appbundle --release
flutter build ios --release --no-codesign
```

Recent validation:

- `flutter analyze`: passed
- `flutter test`: passed, 39 tests
- `flutter build appbundle --release`: passed
- `flutter build ios --release --no-codesign`: passed

## Project Structure

```text
lib/
  app/
  core/
    database/
    notifications/
    security/
  features/
    conception/
    cycle/
    dashboard/
    journal/
    notifications/
    nutrition/
    onboarding/
    productivity/
    reports/
    subscription/
    workouts/
```

## Privacy Notes

Quevaa avoids exposing sensitive content in notification previews and payloads. Payloads contain only a typed version, notification type, safe route, and optional local record ID. They do not contain journal content, intimacy history, pregnancy-test results, cervical-mucus details, medical-condition names, or private notes.

Notification permission is not requested on first app render. It is requested only after a user action from the Quevaa reminders invitation/settings flow.

## Physical Device Testing

Before release, complete the manual device test plan for:

- Android 13+ permission behavior
- Android reboot and Doze behavior
- iOS Focus mode and terminated delivery
- Timezone changes
- Notification taps
- App lock routing
- Quiet hours
- Pending notification limits

Simulators are useful for UI and build validation, but they do not fully cover notification delivery behavior.
