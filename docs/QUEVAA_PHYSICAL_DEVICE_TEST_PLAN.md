# Quevaa Physical Device Test Plan

## Purpose

Validate Quevaa on real Android and iOS devices for launch-critical behavior that cannot be fully proven by simulator, unit tests, or no-codesign builds.

## Android

| Area | Test | Requires Physical Device |
| --- | --- | --- |
| Device coverage | Small Android phone, large Android phone | Yes |
| Notifications | Android 13+ notification permission grant, deny, revoke | Yes |
| Notifications | Notification tap routes to Today, Cycle, Plan, Wellness, Me | Yes |
| Notifications | Device reboot restores eligible local reminders | Yes |
| Notifications | Battery saver and Doze delivery behavior | Yes |
| Privacy | App lock before protected notification destination | Yes |
| Biometrics | Biometric-supported device unlock | Yes |
| Biometrics | Device without biometric support falls back gracefully | Yes |
| Offline | Airplane mode startup and all core workflows | Recommended |
| Theme | Light mode, dark mode, system theme switching | Recommended |
| Accessibility | Large text and high-contrast review | Recommended |
| Time | Timezone change and local-day calendar boundaries | Yes |
| Android release | Adaptive icon, splash, status bar, navigation bar | Recommended |
| Permissions | Confirm no exact-alarm permission and no Firebase notification dependency | No |

## iOS

| Area | Test | Requires Physical Device |
| --- | --- | --- |
| Device coverage | Small iPhone, large iPhone | Yes |
| Notifications | Permission grant, deny, revoke | Yes |
| Notifications | Focus mode behavior | Yes |
| Notifications | Notification tap routes and app-lock routing | Yes |
| Privacy | App switcher preview and protected routes | Yes |
| Biometrics | Face ID device unlock | Yes |
| Biometrics | Device or simulator without biometric enrolment | Recommended |
| Offline | Airplane mode startup and all core workflows | Recommended |
| Theme | Light mode, dark mode, system theme switching | Recommended |
| Accessibility | Large text and VoiceOver pass | Recommended |
| Time | Timezone change and local-day calendar boundaries | Yes |
| Lifecycle | App termination and reopening after saved records | Recommended |
| iOS release | App icon, launch screen, status bar, display name | Recommended |

## Core Journeys

1. Complete onboarding, record a period, add symptoms, restart, confirm Cycle and Today persistence.
2. Enable TTC Mode, log mucus, LH test, BBT, pregnancy test, restart, confirm private TTC state.
3. Create a task, complete it, create a routine, log a focus session, restart, confirm Plan history.
4. Save a meal, add ingredients to shopping, add pantry item, complete workout, log water, restart, confirm Wellness persistence.
5. Switch theme to Light, restart, switch to Dark, restart, switch to System, change OS theme, confirm Quevaa follows it.
6. Enable reminders, schedule test notification, tap it, edit related data, confirm obsolete reminders reconcile.

## Exit Criteria

- No crash across listed journeys.
- No protected health, intimacy, pregnancy-test, or journal content appears in notification previews or logs.
- No critical or high-severity defect remains.
- Store screenshots are captured in light and dark mode after final branding review.
