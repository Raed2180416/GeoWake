# Testing Notification Persistence on Android 15

This guide explains how to test that tracking notifications persist correctly even when the app is swiped away or the device is locked.

## Prerequisites

- Android 15 device or emulator (API level 35)
- ADB installed and device connected
- GeoWake app installed on the device

## Important Settings

Before testing, ensure these settings are configured:

### 1. Battery Optimization
The app will prompt you to disable battery optimization when you start tracking. This is **critical** for background operation on Android 15.

**To manually check/set:**
1. Go to Settings → Apps → GeoWake
2. Tap on Battery
3. Select "Unrestricted" or "Optimize battery usage" → Disable for GeoWake

### 2. Background Location Permission
Make sure you've granted "Allow all the time" location permission:
1. Go to Settings → Apps → GeoWake → Permissions
2. Tap Location
3. Select "Allow all the time"

### 3. Notification Permission
Ensure notifications are enabled (required for Android 13+):
1. Go to Settings → Apps → GeoWake → Notifications
2. Ensure "All GeoWake notifications" is enabled

### 4. Exact Alarms Permission (Android 12+)
For Android 12+, the app needs permission to schedule exact alarms:
1. Go to Settings → Apps → Special app access → Alarms & reminders
2. Enable for GeoWake

## Test Scenarios

### Test 1: App Backgrounded (Home Button)

**Steps:**
1. Start tracking to a destination
2. Verify notification appears with "End Tracking" and "Ignore" buttons
3. Press the Home button to background the app
4. Wait 30 seconds
5. Pull down notification shade

**Expected Result:**
✅ Notification should still be visible with progress updates
✅ Notification should show current ETA and remaining distance
✅ Both action buttons should be present

**Check logs:**
```bash
adb logcat | grep -E "ProgressWakeScheduler|ProgressWakeReceiver|TrackingService"
```

Look for:
- `Scheduled exact alarm with Doze bypass` - AlarmManager scheduled
- `Progress wake alarm triggered!` - AlarmManager fired (after 30s)
- `Showing notification` - Notification restored
- `Progress heartbeat` - Background service heartbeat running (every 5s)

### Test 2: App Swiped Away from Recent Apps

**Steps:**
1. Start tracking to a destination
2. Verify notification appears
3. Open Recent Apps (square/overview button)
4. Swipe GeoWake app away to close it
5. Wait 30 seconds
6. Pull down notification shade

**Expected Result:**
✅ Notification should still be visible
✅ Progress should continue updating
✅ AlarmManager should restore notification within 30 seconds if it disappears

**Check logs:**
```bash
adb logcat | grep -E "ProgressWakeReceiver|AlarmMethodChannel"
```

Look for:
- `Progress wake alarm triggered!` every ~30 seconds
- `Found cached payload` when notification is restored
- `Showing notification: title=...` when notification is posted

### Test 3: Device Locked

**Steps:**
1. Start tracking to a destination
2. Lock the device (power button)
3. Wait 60 seconds
4. Unlock the device
5. Pull down notification shade immediately

**Expected Result:**
✅ Notification should be visible
✅ Progress should have updated during lock
✅ No gaps in tracking

**Check logs:**
```bash
adb logcat | grep -E "TrackingService.*heartbeat|location"
```

Look for continuous location updates and heartbeat logs even while locked.

### Test 4: Device in Doze Mode (Simulated)

**Steps:**
1. Start tracking to a destination
2. Disconnect device from charging
3. Lock the device
4. Force Doze mode:
```bash
adb shell dumpsys battery unplug
adb shell dumpsys deviceidle force-idle
```
5. Wait 60 seconds
6. Exit Doze mode:
```bash
adb shell dumpsys deviceidle unforce
adb shell dumpsys battery reset
```
7. Unlock and check notification

**Expected Result:**
✅ Notification should still be present
✅ AlarmManager alarms should have fired during Doze
✅ Tracking should have continued

**Check logs:**
```bash
adb logcat | grep -E "setExactAndAllowWhileIdle|ProgressWakeReceiver"
```

Look for `setExactAndAllowWhileIdle` which bypasses Doze mode.

### Test 5: Device Restart

**Steps:**
1. Start tracking to a destination
2. Wait for notification to appear
3. Restart the device:
```bash
adb reboot
```
4. Wait for device to boot
5. Unlock device and check notification

**Expected Result:**
✅ App should auto-resume tracking (if tracking was active before reboot)
✅ Notification should be restored
✅ AlarmManager schedules should be re-created

**Check logs:**
```bash
adb logcat | grep -E "BootReceiver|GW_BOOT|GW_ARES"
```

Look for:
- `Boot/restart event received` from BootReceiver
- `Tracking was active, attempting to restore` if tracking was active
- `GW_ARES_DECISION_ATTACH` if auto-resume happens

### Test 6: Notification Action Buttons

**Steps:**
1. Start tracking to a destination
2. Pull down notification shade
3. Tap "Ignore" button
4. Background/swipe away the app
5. Wait 60 seconds
6. Check notification shade

**Expected Result:**
✅ Notification should NOT reappear (suppressed)
✅ Tracking should continue in background
✅ No more notification updates

**To verify tracking is still running:**
```bash
adb logcat | grep "TrackingService.*location"
```

Should see location updates continuing.

**Test "End Tracking" button:**
1. Start tracking again
2. Pull down notification shade
3. Tap "End Tracking" button
4. Wait 5-10 seconds

**Expected Result:**
✅ Notification should disappear
✅ Tracking should stop completely
✅ Background service should stop
✅ App should navigate to home screen if open

**Check logs:**
```bash
adb logcat | grep -E "NotificationActionRx|TrackingService.*stopped"
```

Look for:
- `Matched ACTION_END_TRACKING` from NotificationActionReceiver
- `Native END_TRACKING signal detected` from background heartbeat
- `Tracking has been fully stopped` from service

## Common Issues and Solutions

### Issue: Notification disappears after app is swiped away

**Possible Causes:**
1. Battery optimization is enabled for GeoWake
2. Background restrictions are too aggressive
3. AlarmManager permissions not granted

**Solution:**
1. Disable battery optimization (see Prerequisites above)
2. Go to Settings → Apps → GeoWake → Battery → Unrestricted
3. Check that "Alarms & reminders" permission is granted

### Issue: Tracking stops when app is killed

**Possible Causes:**
1. App was force-stopped (different from swiping away)
2. Background service was killed by the system
3. Location permission revoked

**Solution:**
- Don't use "Force Stop" from app settings - only test with swiping away
- Ensure "Allow all the time" location permission is granted
- Check battery optimization is disabled

### Issue: Notification shows but doesn't update

**Possible Causes:**
1. GPS location updates not working in background
2. Heartbeat timer stopped
3. Background service demoted from foreground

**Check logs:**
```bash
adb logcat | grep -E "Progress heartbeat|updateLocation"
```

Should see heartbeat logs every 5 seconds and location updates.

### Issue: AlarmManager not firing

**Possible Causes:**
1. Exact alarm permission not granted
2. Device in aggressive battery saving mode
3. Scheduled times being throttled

**Solution:**
1. Check Settings → Apps → Special app access → Alarms & reminders
2. Disable battery saver mode during testing
3. Check logs for `setExactAndAllowWhileIdle` confirmations

## Debugging Commands

### Check if service is running:
```bash
adb shell dumpsys activity services | grep -A 10 geowake
```

### Check active notifications:
```bash
adb shell dumpsys notification | grep -A 20 geowake
```

### Check AlarmManager scheduled alarms:
```bash
adb shell dumpsys alarm | grep geowake
```

### Check battery optimization status:
```bash
adb shell dumpsys deviceidle whitelist | grep geowake
```

### Monitor all relevant logs:
```bash
adb logcat | grep -E "AlarmMethodChannel|NotificationActionRx|TrackingService|ProgressWake|BootReceiver"
```

## Success Criteria

For a successful test, all of the following should be true:

1. ✅ Notification persists when app is backgrounded
2. ✅ Notification persists when app is swiped away
3. ✅ Notification persists when device is locked
4. ✅ Notification persists during Doze mode (fires within 30-60 seconds)
5. ✅ AlarmManager restores notification if it disappears
6. ✅ Tracking continues in all scenarios
7. ✅ "End Tracking" button stops everything
8. ✅ "Ignore" button suppresses notification but continues tracking
9. ✅ Battery optimization prompt appears when tracking starts
10. ✅ Service auto-resumes after device restart (if tracking was active)

## Performance Expectations

With the current configuration:
- **Heartbeat interval**: 5 seconds (in-process notification refresh)
- **AlarmManager interval**: 30 seconds (system-level fallback)
- **Battery impact**: Moderate (aggressive for reliability)

If battery life is a concern after testing, the intervals can be tuned:
- Increase heartbeat to 10-15 seconds
- Increase AlarmManager to 60-90 seconds

However, this will make notification persistence slightly less aggressive.
