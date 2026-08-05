# Quevaa Local Notification Test Plan

Quevaa notifications are offline, operating-system-scheduled local notifications. These checks must be completed on physical devices before release because simulators do not fully reproduce permission, reboot, battery, Focus/Doze, and OEM delivery behavior.

## Android Physical Device

- Android 13+ permission request: enable from Quevaa invitation, verify reminders schedule.
- Permission denied: deny prompt, verify app remains functional and settings show disabled state.
- Permission later revoked: revoke in system settings, reopen Quevaa, verify reconciliation does not keep scheduling.
- Foreground delivery: schedule test notification while app is visible.
- Background delivery: schedule test notification, background app, verify delivery.
- Terminated delivery: schedule test notification, kill app, verify delivery.
- Device reboot: schedule a future reminder, reboot, verify plugin boot receiver restores pending schedule.
- Battery saver and Doze: schedule ordinary reminders, verify delivery may be delayed but not duplicated.
- Timezone change: change device timezone, reopen Quevaa, verify schedules reconcile.
- Device time change: move clock forward/back, verify no duplicate outdated reminders.
- App update: install update over existing app, verify schedule version reconciliation.
- Notification tap: tap cycle, TTC, meal, task and journal notifications; verify route.
- App lock: lock Quevaa, tap notification, verify route waits behind authentication.
- Quiet hours: schedule low-priority reminder inside quiet hours, verify moved to allowed window.
- Multiple reminders: verify daily cap and max pending limits.
- Notification channels: confirm stable channel names and importance.

## iOS Physical Device

- Permission granted: enable from Quevaa invitation, verify reminders schedule.
- Permission denied: deny prompt, verify settings show disabled and no repeated prompts.
- Permission later changed in Settings: toggle permission, reopen Quevaa, verify status.
- Foreground delivery: verify banners/list/sound follow user preferences.
- Background delivery: schedule test notification, background app, verify delivery.
- Terminated delivery: kill app after scheduling, verify delivery.
- Device restart: schedule future reminder, restart, verify delivery remains pending where iOS permits.
- Focus mode: enable Focus, verify OS controls interruption without Quevaa bypass.
- Timezone change: change timezone, reopen app, verify reconciliation.
- App update: install update over existing app, verify schedule version reconciliation.
- Notification tap: verify route for Cycle, TTC log, Wellness, Plan, Me and settings.
- App lock: verify notification tap queues route until authentication.
- Quiet hours: verify ordinary wellness reminder moves out of quiet hours.
- Pending notification limit: verify Quevaa keeps below platform limits and app cap.
- Foreground presentation: verify no redundant notification appears for the screen currently open.

## Simulator-Limited Checks

The following require physical devices for release signoff:

- Android reboot receiver behavior
- Android Doze and OEM battery saver behavior
- Android 13+ real permission UX on all target OEMs
- iOS terminated delivery reliability
- iOS Focus mode and notification summary behavior
- Device timezone travel with automatic network time
- App lock plus notification tap under OS biometric prompts
