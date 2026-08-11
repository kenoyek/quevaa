# Quevaa

Quevaa is a premium offline-first Flutter mobile app for private cycle care, period tracking, trying-to-conceive support, daily wellness, Nigerian meal planning, workouts, productivity, private journaling, and doctor-ready reporting.

The app is designed to keep sensitive wellness data on the device. Core experiences avoid remote notification services, remote AI services, and cloud push dependencies.

## Repository Status

Quevaa is source-available software and open to thoughtful community
contributions.

This repository is public to support transparency, learning, security review,
testing, and collaboration. Public availability of the source code does not
place Quevaa in the public domain, does not transfer ownership of Quevaa, and
does not permit use of Quevaa to provide a competing product.

Quevaa is not released under a permissive open-source license such as MIT,
Apache, BSD, GPL, or LGPL. See [License and Ownership](#license-and-ownership)
before copying, redistributing, forking, or building on this code.

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

## Contributing

Quevaa welcomes thoughtful contributions from developers, designers,
researchers, testers, and others interested in improving private, offline-first
women's health technology.

You are welcome to:

- Report bugs and security issues
- Suggest new features
- Improve documentation
- Fork the repository for permitted development and evaluation purposes
- Submit pull requests
- Improve accessibility, performance, tests, and user experience

Before submitting a significant contribution, please open an issue or
discussion so that the proposed work can be coordinated with the project
direction.

Contributions are subject to the Quevaa Contributor License Agreement, the
repository's license terms, and the project code of conduct.

See [CONTRIBUTING.md](CONTRIBUTING.md), [CLA.md](CLA.md), and
[CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) for details.

## License and Ownership

Quevaa is source-available software.

The source code is publicly accessible to encourage transparency, learning,
security review, testing, and community contribution. Public availability of the
source code does not place Quevaa in the public domain and does not transfer
ownership of the Quevaa product, brand, source code, designs, or other
intellectual property.

Except for third-party components distributed under their respective licenses:

Copyright © 2026 Okagua Kenoye. All rights reserved except as expressly
granted under the Quevaa software license.

Quevaa is distributed under the PolyForm Shield License 1.0.0.

The license permits certain uses, modifications, and redistribution, but does
not permit use of Quevaa to provide a product that competes with Quevaa or
other protected products of the licensor.

In particular, publication of this repository should not be interpreted as
permission to:

- Rebrand Quevaa and publish it as another period, fertility, wellness,
  productivity, or women's health application
- Use Quevaa or substantial portions of it to operate a competing product or
  service
- Represent an unofficial fork as being endorsed by or affiliated with Quevaa
- Use the Quevaa name, logo, visual identity, screenshots, or other brand
  assets without permission
- Remove copyright, licensing, attribution, or legal notices

Forking this repository on GitHub does not transfer ownership of the Quevaa
project or its intellectual property.

Third-party packages, libraries, fonts, icons, and other dependencies remain
subject to their own licenses.

## Commercial Licensing

If you would like to use Quevaa technology in a way that is not permitted by
the public license, including certain commercial uses, please contact the
project owner to discuss a separate commercial license.

For commercial licensing enquiries or permissions beyond the public license,
contact **[kenoyek@gmail.com](mailto:kenoyek@gmail.com)**.

## Brand

The Quevaa name, logo, application identity, visual assets, and related
branding are not licensed for use in derivative or competing products unless
expressly authorised in writing.

Permission to use the source code under the software license does not
automatically grant permission to use Quevaa branding.

## Health and Medical Disclaimer

Quevaa is a wellness and personal tracking application.

Cycle predictions, fertile-window estimates, ovulation estimates,
recommendations, insights, and other information generated by Quevaa are
informational estimates and are not medical diagnoses or medical advice.

Quevaa should not be used as a substitute for professional medical care,
diagnosis, contraception, or emergency medical assistance.
