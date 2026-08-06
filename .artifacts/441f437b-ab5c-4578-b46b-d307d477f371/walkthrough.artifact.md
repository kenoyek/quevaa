# Walkthrough - Build APK

The Android APK for the Quevaa project has been successfully built.

## Changes and Actions

- **Dependency Synchronization**: Performed `flutter pub get` to ensure all packages are up to date.
- **Code Generation**: Executed `dart run build_runner build --delete-conflicting-outputs` to generate necessary code for Riverpod and Drift.
- **Troubleshooting**: Encountered a Gradle build failure related to conflicting environment variables (`ANDROID_PREFS_ROOT` and `ANDROID_USER_HOME`). This was resolved by unsetting `ANDROID_PREFS_ROOT` during the build process.
- **Compilation**: Successfully compiled the release APK using `flutter build apk`.

## Verification Results

### Build Output
The release APK is available at the following path:
- [app-release.apk](file:///Users/okaguakenneth/Downloads/quevaa/build/app/outputs/flutter-apk/app-release.apk) (66MB)

> [!TIP]
> This APK was built using the `debug` signing key. It is suitable for testing on devices but should be resigned with a production key before releasing to the Google Play Store.
