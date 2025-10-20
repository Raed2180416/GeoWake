# Alarm Trigger Improvements

## Overview
This document describes the improvements made to the alarm triggering system to ensure reliable and accurate alarm behavior under various conditions.

## Changes Made

### 1. Threshold Validation Against Route Metrics
**Location**: `lib/screens/homescreen.dart`

**Problem**: Users could set a threshold (distance or time) that was greater than the actual distance/ETA to their destination, which would result in the alarm never triggering.

**Solution**: 
- Extract the initial distance and ETA from the route calculation
- Validate that the user's threshold is smaller than the total distance/ETA
- Show an error dialog if the threshold is invalid, prompting the user to choose a smaller value

**Example**: If the destination is 3 km away and the user sets a 5 km threshold, the app now shows: "Your alarm distance (5.0 km) is greater than the distance to your destination (3.0 km). Please choose a smaller threshold."

### 2. Already at Destination Handling
**Location**: `lib/screens/homescreen.dart`

**Problem**: If the user was already within their alarm threshold when starting tracking, they might not be aware that the alarm would trigger immediately.

**Solution**:
- Check if the user is already within the threshold (using straight-line distance for distance mode, or ETA for time mode)
- Show a confirmation dialog: "You are already within X km of your destination. The alarm will trigger immediately. Do you want to continue?"
- Allow the user to cancel or proceed

### 3. Reduced Proximity Gating for Immediate Triggers
**Location**: `lib/services/trackingservice/alarm.dart`, `lib/services/trackingservice/background_state.dart`, `lib/services/trackingservice/background_lifecycle.dart`

**Problem**: The proximity gating system requires 3 consecutive GPS confirmations and 4 seconds of dwell time before triggering an alarm. While this prevents false positives from GPS jitter, it can be frustrating if you're already at your destination.

**Solution**:
- Added a `_startedWithinThreshold` flag to track if the first position check was already within the alarm threshold
- When this flag is true, reduce the requirements to:
  - 2 consecutive confirmations (instead of 3)
  - 2 seconds dwell time (instead of 4)
- This allows the alarm to trigger in ~4-6 seconds instead of ~8-12 seconds when already at destination
- Still provides protection against GPS noise while being more responsive

### 4. Speed-Based Dynamic Threshold Adjustment
**Location**: `lib/services/trackingservice/alarm.dart`

**Problem**: When moving at high speeds, the static threshold might not provide enough buffer time for the user to wake up and react. For example, at 54 km/h (15 m/s), a 1 km threshold only gives ~1 minute of warning.

**Solution**:
- Implemented a "dynamic radius" concept where the effective threshold expands based on speed
- When moving faster than 5 m/s (~18 km/h, above walking/cycling speed):
  - Calculate a speed buffer: `speed * 15 seconds` (accounts for reaction time + GPS lag)
  - Add this buffer to the user's threshold, capped at 30% increase
  - Example: At 15 m/s with 1 km threshold → adds 225m buffer → effective threshold becomes 1.225 km
- Only applies to distance mode (time mode already accounts for speed through ETA calculation)
- The user's configured threshold is never decreased, only expanded for safety

## Technical Details

### Proximity Gating Logic
The proximity gating system prevents false alarms by requiring:
1. **Multiple confirmations**: GPS positions must consistently show the device within the threshold
2. **Dwell time**: The device must remain within the threshold for a minimum duration

Standard values:
- 3 consecutive confirmations
- 4 seconds minimum dwell

Reduced values (when started within threshold):
- 2 consecutive confirmations  
- 2 seconds minimum dwell

### Speed Buffer Calculation
```dart
effectiveThresholdMeters = configuredThreshold + min(speed * 15, configuredThreshold * 0.3)
```

This formula:
- Adds 15 seconds worth of travel distance as a buffer
- Caps the expansion at 30% to avoid overly early triggers
- Only applies when speed > 5 m/s

## Testing Recommendations

1. **Threshold Validation**:
   - Set up a route with 2 km distance
   - Try to set 3 km alarm threshold → should show error
   - Try to set 1 km alarm threshold → should work

2. **Already at Destination**:
   - Set destination to current location or very close
   - Set alarm threshold that encompasses current position
   - Should show confirmation dialog

3. **Reduced Gating**:
   - Start at destination with alarm threshold that encompasses it
   - Observe that alarm triggers within ~4-6 seconds
   - Compare with starting away from destination (should take ~8-12 seconds to trigger)

4. **Speed-Based Adjustment**:
   - Set 1 km distance threshold
   - Start driving at 50+ km/h
   - Observe logs showing effectiveThreshold > configuredThreshold
   - Alarm should trigger earlier than if walking

## Migration Notes

All changes are backward compatible. Existing behavior is preserved except:
- Invalid thresholds that previously would never trigger now show an error
- Users starting within threshold now get faster alarm triggers (improvement)
- High-speed users get earlier warnings (safety improvement)

## Future Enhancements

Potential improvements for future consideration:
1. **User education**: Add tooltips explaining the speed-based adjustment
2. **Smart threshold suggestions**: Recommend thresholds based on travel mode
3. **Adaptive gating**: Further tune gating parameters based on GPS accuracy
4. **Route-aware thresholds**: Account for traffic, turns, and complex routes
