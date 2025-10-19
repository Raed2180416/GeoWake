# Quick Reference: Notification Persistence Fixes

## What Was the Problem?

Notifications were disappearing when you swiped the app away or locked your phone. The app couldn't track your location in the background on Android 15 like it should.

## What Did We Fix?

We implemented a **4-layer defense system** to keep notifications alive:

### Layer 1: When App is Open ⚡
- Updates notification in real-time as you travel
- Fastest and most responsive

### Layer 2: When App is Backgrounded 🔄
- Background service runs a timer every 5 seconds
- Keeps updating your notification with progress
- Makes sure Android knows the service is important

### Layer 3: When App is Swiped Away 🔔
- System alarm wakes up every 30 seconds
- Brings back the notification if it disappeared
- Works even if the background service was killed

### Layer 4: When Device Restarts 🔌
- Special receiver detects when phone boots up
- Automatically restores your tracking session
- Recreates all the alarms

## What Changed in the App?

### 1. New Permissions (Don't worry - they're all necessary!)
- **Boot receiver**: So we can restore tracking after restart
- **Data sync**: Required for Android 15 background services
- **Battery optimization**: So we can ask you to exempt the app

### 2. Boot Receiver
New component that wakes up when your phone restarts and restores everything automatically.

### 3. Faster Updates
- Notification refreshes every 5 seconds (was 8 seconds)
- Backup alarm every 30 seconds (was 45 seconds)
- More aggressive = more reliable

### 4. Better Battery Optimization Prompts
- Will remind you every 7 days to keep battery optimization disabled
- Critical for Android 15 to allow background tracking

### 5. Android 15 Support
- Updated app to fully support Android 15 (API level 35)
- Uses latest foreground service features

## What Do You Need to Do?

### Before Testing:

1. **Disable Battery Optimization** (CRITICAL!)
   - Settings → Apps → GeoWake → Battery → Unrestricted
   - The app will prompt you, but double-check

2. **Allow Background Location**
   - Settings → Apps → GeoWake → Permissions → Location → "Allow all the time"

3. **Enable Notifications**
   - Settings → Apps → GeoWake → Notifications → Enable all

4. **Allow Exact Alarms**
   - Settings → Apps → Special app access → Alarms & reminders → Enable for GeoWake

### Testing:

Follow the guide in `TESTING_NOTIFICATION_PERSISTENCE.md` to test:
1. ✅ Backgrounding the app
2. ✅ Swiping the app away
3. ✅ Locking your phone
4. ✅ Restarting your phone

## How to Tell if It's Working

### When tracking is active, you should see:

1. **Notification is always visible** with:
   - Your destination name
   - Remaining distance
   - ETA (estimated time of arrival)
   - Two buttons: "End Tracking" and "Ignore"

2. **Notification keeps updating** even when:
   - App is closed
   - Phone is locked
   - You're doing other things

3. **After swiping app away**:
   - Notification comes back within 30 seconds
   - Progress keeps updating
   - Tracking continues

4. **After restarting phone**:
   - Notification reappears when you unlock
   - Tracking resumes automatically
   - Everything works like before

## Common Questions

### Q: Will this drain my battery?
A: Slightly more than before (we wake up more frequently), but it's necessary for Android 15. The intervals can be tuned if battery life is a concern.

### Q: Why does it keep asking about battery optimization?
A: Android 15 is very aggressive about killing background apps. We remind you every 7 days to make sure it stays disabled for GeoWake.

### Q: What if I tap "Ignore" on the notification?
A: The notification disappears, but tracking continues silently in the background. You'll still get the alarm when you're near your destination.

### Q: What if I tap "End Tracking"?
A: Everything stops immediately - tracking, notifications, alarms, background service. The app returns to the home screen.

### Q: Will it work if I force stop the app?
A: No. Force stopping is different from swiping away. Force stop kills everything completely. Only use it if you want to stop all tracking.

### Q: What if my phone runs out of battery?
A: When you charge and restart your phone, tracking will automatically resume if it was active before.

## Troubleshooting

### Notification disappears and doesn't come back:
- Check battery optimization is disabled
- Check "Allow all the time" location permission
- Make sure you didn't force stop the app
- Check logs (see testing guide)

### Tracking stops when app is closed:
- Probably battery optimization is enabled
- Go disable it in Settings → Apps → GeoWake → Battery

### App doesn't resume after restart:
- Check if tracking was active before restart
- Look for "Tracking was active" in logs
- Make sure boot receiver is registered

## Debug Mode

Want to see what's happening? Use these commands:

```bash
# See all notification activity
adb logcat | grep -E "ProgressWake|AlarmMethodChannel"

# See background service activity
adb logcat | grep TrackingService

# See boot receiver activity
adb logcat | grep BootReceiver
```

## Summary

**Before**: Notifications disappeared when app was swiped away. Tracking stopped. No way to recover.

**After**: Notifications persist no matter what. Tracking continues reliably. Everything restores after restart.

**The secret**: 4 layers of defense working together. If one fails, the next one takes over.

## Need More Details?

- **Testing**: See `TESTING_NOTIFICATION_PERSISTENCE.md`
- **Implementation**: See `NOTIFICATION_PERSISTENCE_FIX_SUMMARY.md`
- **Debugging**: See `NOTIFICATION_DEBUG_GUIDE.md`

---

**Bottom line**: Your tracking will now work reliably on Android 15, even if you accidentally swipe the app away. The notification will keep coming back until you either reach your destination or explicitly tap "End Tracking".
