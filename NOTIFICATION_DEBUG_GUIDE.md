# Notification Service Debug Guide

## Current Implementation Status

The notification service has been updated with the following fixes:

### ✅ Completed Changes

1. **Native Notification with Action Buttons**
   - Progress notification is created via `decorateProgressNotification()` method
   - Uses Android's NotificationManagerCompat directly
   - Action buttons configured with PendingIntents to BroadcastReceiver
   - Buttons: "End Tracking" and "Ignore"

2. **BroadcastReceiver Implementation**
   - `NotificationActionReceiver` handles both actions
   - `ACTION_END_TRACKING`: Sets flag, clears state, stops service
   - `ACTION_IGNORE_TRACKING`: Sets suppression flag, cancels notification
   - Comprehensive logging added

3. **Dart-side Signal Detection**
   - Heartbeat timer checks for `native_end_tracking_signal_v1` flag
   - When detected, calls `_onStop()` and stops service
   - Runs every 8 seconds

4. **Notification Cancellation**
   - Both flutter plugin and native methods called
   - Ensures notification is fully cleared

## Debugging Steps

### 1. Check if Notification is Being Created

**Run the app and start tracking, then check logcat:**

```bash
adb logcat | grep -E "AlarmMethodChannel|NotificationActionRx"
```

**Expected output:**
```
AlarmMethodChannel: decorateProgressNotification called: title=..., progress=...
AlarmMethodChannel: Adding action buttons with PendingIntents
AlarmMethodChannel: Showing notification with ID 888
```

**If you don't see this:**
- The `showJourneyProgress()` method isn't being called
- The method channel call is failing
- Check for errors in Dart logs

### 2. Check if Buttons Are Being Pressed

**Tap the "End Tracking" or "Ignore" button, then check logcat:**

```bash
adb logcat | grep NotificationActionRx
```

**Expected output:**
```
NotificationActionRx: ===============================================
NotificationActionRx: onReceive CALLED!
NotificationActionRx: intent: Intent { act=com.example.geowake2.ACTION_END_TRACKING ... }
NotificationActionRx: action: com.example.geowake2.ACTION_END_TRACKING
NotificationActionRx: ===============================================
NotificationActionRx: Matched ACTION_END_TRACKING - calling performEndTracking
NotificationActionRx: performEndTracking: Starting complete tracking shutdown
NotificationActionRx: setNativeEndTrackingFlag: true
NotificationActionRx: markProgressSuppressed: true
NotificationActionRx: clearTrackingState: Clearing all tracking preferences and files
NotificationActionRx: cancelNotifications: Cancelling progress and alarm notifications
NotificationActionRx: stopAlarmFeedback: Stopping vibration
NotificationActionRx: stopBackgroundService: Attempting to stop flutter_background_service
NotificationActionRx: stopBackgroundService: stopService result=true/false
NotificationActionRx: performEndTracking: Complete
```

**If you don't see this:**
- The BroadcastReceiver is not being triggered
- Possible causes:
  1. PendingIntent flags are incorrect for your Android version
  2. Receiver not properly registered (check AndroidManifest.xml)
  3. Security restrictions preventing broadcast delivery

### 3. Check if Dart Heartbeat Detects Signal

**After pressing "End Tracking", wait up to 8 seconds and check logs:**

```bash
adb logcat | grep TrackingService
```

**Expected output:**
```
TrackingService: Native END_TRACKING signal detected - stopping service
TrackingService: Tracking has been fully stopped.
```

**If you don't see this:**
- SharedPreferences flag not being set or read correctly
- Heartbeat timer not running
- Background isolate might be dead

### 4. Check Notification Persistence

**Background the app and wait 20 seconds:**

```bash
adb logcat | grep -E "AlarmMethodChannel|ProgressWakeReceiver"
```

**Expected:**
- Every 8 seconds: `decorateProgressNotification` called (from heartbeat)
- Every 10 minutes: `ProgressWakeReceiver` restores notification

**If notification disappears:**
- Heartbeat timer stopped (background isolate killed)
- AlarmManager wake-ups not scheduled
- Suppression flag incorrectly set

## Common Issues & Solutions

### Issue: Buttons Don't Do Anything

**Possible Causes:**

1. **PendingIntent not triggering BroadcastReceiver**
   - On Android 12+ (API 31+), explicit BroadcastReceivers require FLAG_MUTABLE for PendingIntents that will be modified
   - Our code uses FLAG_IMMUTABLE which is correct for static broadcasts
   - If buttons don't work, try changing to FLAG_MUTABLE in `decorateProgressNotification()`

2. **Receiver not exported properly**
   - AndroidManifest.xml has `android:exported="false"`
   - This should be fine for implicit intents from same app
   - If it doesn't work, try `android:exported="true"`

3. **Intent action not matching**
   - Receiver expects: `com.example.geowake2.ACTION_END_TRACKING`
   - Check if intent actually has this action string

**Fix attempts:**

```kotlin
// Try 1: Use MUTABLE flag (less secure but might work)
val pendingFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
} else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
} else {
    PendingIntent.FLAG_UPDATE_CURRENT
}

// Try 2: Use explicit intent
val endIntent = Intent().apply {
    component = ComponentName(context, NotificationActionReceiver::class.java)
    action = NotificationActionReceiver.ACTION_END_TRACKING
}
```

### Issue: Tracking Doesn't Stop

**Possible Causes:**

1. **Signal flag not being set**
   - Check if `setNativeEndTrackingFlag()` is called
   - Verify SharedPreferences key matches

2. **Heartbeat not running**
   - Background isolate might be killed
   - Timer canceled for some reason

3. **Service not stopping**
   - `stopService()` returns false (Android didn't stop it)
   - Foreground service protection preventing stop

**Fix: Use more aggressive stop**

```kotlin
// Try killing the service process (nuclear option)
private fun stopBackgroundService(context: Context) {
    try {
        // Normal stop
        val serviceClass = Class.forName("id.flutter.flutter_background_service.BackgroundService")
        val serviceIntent = Intent(context, serviceClass)
        context.stopService(serviceIntent)
        
        // Also try stopping foreground
        val stopIntent = Intent("android.intent.action.STOP_FOREGROUND")
        stopIntent.setPackage(context.packageName)
        context.sendBroadcast(stopIntent)
    } catch (e: Exception) {
        Log.e(TAG, "Failed to stop service", e)
    }
}
```

### Issue: Notification Doesn't Persist

**Possible Causes:**

1. **Foreground service notification overwriting our notification**
   - Both use ID 888
   - Service might recreate basic notification

2. **System killing app/service**
   - Battery optimization
   - Background restrictions

3. **AlarmManager wake-ups not working**
   - Not scheduled properly
   - System ignoring setExactAndAllowWhileIdle

**Fix: Use different notification ID**

If the conflict is severe, consider using a different ID:

```kotlin
// In decorateProgressNotification():
manager.notify(889, builder.build())  // Use 889 instead of 888

// In cancelProgressNotification():
manager.cancel(889)
```

Then update Dart to use 889:
```dart
static const int _progressNotificationId = 889;
```

## Testing Checklist

- [ ] Notification appears when tracking starts
- [ ] Notification has "End Tracking" and "Ignore" buttons
- [ ] Tapping "End Tracking" dismisses notification within 8 seconds
- [ ] Tapping "End Tracking" stops background tracking
- [ ] Tapping "Ignore" dismisses notification permanently
- [ ] Tapping "Ignore" keeps tracking running silently
- [ ] Notification persists when app is backgrounded
- [ ] Notification persists when app is closed
- [ ] After 20 seconds backgrounded, notification still shows (heartbeat)
- [ ] After 10 minutes backgrounded, notification restored (AlarmManager)
- [ ] Logcat shows BroadcastReceiver being triggered on button press
- [ ] Logcat shows native flag being detected by Dart heartbeat

## Manual Testing Commands

```bash
# Watch all relevant logs
adb logcat | grep -E "AlarmMethodChannel|NotificationActionRx|TrackingService|ProgressWake"

# Check SharedPreferences (requires root or debuggable app)
adb shell run-as com.example.geowake2 cat /data/data/com.example.geowake2/shared_prefs/FlutterSharedPreferences.xml

# Force stop app to test notification persistence
adb shell am force-stop com.example.geowake2

# Check if service is running
adb shell dumpsys activity services | grep geowake

# Check active notifications
adb shell dumpsys notification | grep -A 20 "geowake"
```

## Next Steps if Still Not Working

1. **Add toast messages in native code** to confirm receiver is triggered:
```kotlin
Toast.makeText(context, "END_TRACKING received!", Toast.LENGTH_SHORT).show()
```

2. **Try using Activity instead of BroadcastReceiver**:
   - Create a transparent activity that performs the action
   - Less likely to be blocked by system

3. **Use WorkManager instead of BroadcastReceiver**:
   - More reliable for background work
   - Survives app death better

4. **Check Android version restrictions**:
   - Android 12+ has stricter background restrictions
   - May need to request special permissions
