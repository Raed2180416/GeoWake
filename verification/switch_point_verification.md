# Switch Point Alarm Verification

## Overview
This document describes the verification system implemented to ensure alarms fire at all switch points along routes.

## What are Switch Points?

Switch points include:
1. **Metro-to-Metro Transfers**: When switching from one metro line to another
2. **Mode Changes**: When switching from driving to metro, walking to metro, etc.
3. **Pre-boarding Points**: When approaching the first metro boarding station

## Verification Features Implemented

### 1. Enhanced Route Event Detection Logging

**File**: `lib/services/transfer_utils.dart`

**Function**: `buildRouteEvents()`

**What it does**:
- Logs each mode change detected: `"Detected mode change at Xm: MODE1 -> MODE2"`
- Logs each transit transfer detected: `"Detected transit transfer at Xm: LINE1 -> LINE2 at STATION"`
- Provides summary: `"Built N route events: type1@Xm, type2@Ym, ..."`

**Example Log Output**:
```
[TransferUtils] Detected mode change at 0.0m: WALKING -> TRANSIT
[TransferUtils] Detected transit transfer at 3500.0m: Red Line -> Blue Line at Central Station
[TransferUtils] Built 3 route events: mode_change@0m, transfer@3500m, mode_change@5200m
```

### 2. Switch Point Coverage Verification

**File**: `lib/services/transfer_utils.dart`

**Function**: `verifySwitchPointCoverage()`

**What it does**:
- Counts all switch points in the route
- Compares against captured events
- Warns if any switch points might be missing

**Returns**:
```dart
{
  'totalSwitchPoints': 3,
  'capturedInEvents': 3,
  'allEventsCaptured': true,
}
```

### 3. Route Initialization Verification

**File**: `lib/services/trackingservice/background_lifecycle.dart`

**When**: After building route events from directions API response

**What it does**:
- Verifies all switch points are captured
- Logs verification results
- Warns if potential missing switch points detected

**Example Log Output**:
```
[alarm] Switch point verification:
  totalSwitchPoints: 3
  capturedInEvents: 3
  allCaptured: true
  routeEventsCount: 3
```

### 4. Real-time Alarm Checking Verification

**File**: `lib/services/trackingservice/alarm.dart`

**When**: During each alarm evaluation cycle

**What it does**:

#### a. Start of Check Logging
```
[alarm] Checking route events for switch point alarms:
  totalEvents: 3
  firedEvents: 1
  remainingEvents: 2
```

#### b. Event Status Logging
For each event, logs why it's being processed or skipped:

**Already Fired**:
```
[alarm] Skipping already-fired event:
  eventIdx: 0
  eventType: transfer
  eventMeters: 3500.0
  eventLabel: Central Station
```

**Already Passed**:
```
[alarm] Skipping already-passed event:
  eventIdx: 1
  eventType: mode_change
  eventMeters: 2100.0
  progressMeters: 2500.0
```

**Distance/Time/Stops Check**:
```
[alarm] Event distance check:
  eventIdx: 2
  eventType: transfer
  toEventM: 450.0
  thresholdM: 2000.0
  willFire: true
```

#### c. Near Switch Point Warning
If within 200m of a switch point but alarm hasn't fired:
```
[alarm] Near switch point but alarm not triggered yet:
  eventIdx: 2
  eventType: transfer
  toEventM: 150.0
  eventLabel: Downtown Station
  thresholdMeters: 2000.0
```

#### d. Alarm Firing Confirmation
```
[alarm] Firing event alarm:
  eventIdx: 2
  eventType: transfer
  title: Upcoming transfer
  body: Downtown Station
  toEventM: 450.0
```

### 5. Periodic Verification Check

**File**: `lib/services/trackingservice/alarm.dart`

**Function**: `_verifySwitchPointAlarmCoverage()`

**When**: Every 10th alarm evaluation cycle

**What it does**:
- Checks if any events were passed without firing alarms
- Warns if switch points were missed

**Example Warning Output**:
```
[alarm.verification] VERIFICATION ALERT: Switch points passed without alarms:
  passedWithoutFiring: 1
  totalEvents: 3
  firedEvents: 2

[alarm.verification] Switch point passed without alarm firing:
  eventIdx: 1
  eventType: mode_change
  eventMeters: 2100.0
  progressMeters: 2500.0
  eventLabel: Start walking
```

## How to Test

### Test Scenario 1: Metro-to-Metro Transfer

1. Create a route with metro transfer (e.g., Line A to Line B)
2. Set alarm mode to "distance" with 2km threshold
3. Start tracking
4. Monitor logs for:
   - Initial detection: `"Detected transit transfer at Xm"`
   - Verification: `"allCaptured: true"`
   - Alarm checking: `"Checking route events for switch point alarms"`
   - Alarm firing: `"Firing event alarm"` when within 2km of transfer

### Test Scenario 2: Driving to Metro Pre-boarding

1. Create a route starting with driving, then boarding metro
2. Set alarm mode to "stops" with 2 stops threshold
3. Start tracking
4. Monitor logs for:
   - Mode change detection: `"Detected mode change at Xm: DRIVING -> TRANSIT"`
   - Pre-boarding alert: `"Pre-boarding alert firing"`
   - Transfer alarm when approaching boarding point

### Test Scenario 3: Multiple Transfers

1. Create a route with multiple metro transfers
2. Set alarm mode to "time" with 5 minutes threshold
3. Start tracking
4. Monitor logs to verify:
   - All transfers detected in initial scan
   - All transfers checked during tracking
   - Alarms fire at each transfer point
   - No "passed without alarm" warnings

## Expected Behavior

### ✅ Correct Behavior
- All switch points detected in `buildRouteEvents()`
- `verifySwitchPointCoverage()` reports `allCaptured: true`
- Alarms fire at each switch point based on threshold
- No "passed without alarm" warnings
- Events marked as fired in `_firedEventIndexes`

### ⚠️ Warning Indicators
- `"Potential missing switch points detected"`
- `"Near switch point but alarm not triggered yet"`
- `"Switch point passed without alarm firing"`

### ❌ Critical Issues
- `"VERIFICATION ALERT: Switch points passed without alarms"`
- Events in logs but not in `_routeEvents`
- Events passed without appearing in either skipped or fired logs

## Log Domains for Filtering

Filter logs by domain to focus on specific aspects:

- `alarm` - General alarm checking
- `alarm.verification` - Verification warnings
- `boarding` - Pre-boarding specific
- `TransferUtils` - Route event detection
- `TransferUtils.Verification` - Switch point coverage verification

## Summary

The verification system provides comprehensive logging at multiple levels:

1. **Detection Level**: Logs when switch points are discovered in route data
2. **Verification Level**: Confirms all switch points are captured
3. **Runtime Level**: Logs alarm evaluation for each event
4. **Monitoring Level**: Periodic checks for missed alarms

This multi-layered approach ensures that:
- All switch points are detected from route data
- All switch points trigger alarm evaluations
- Alarms fire at the configured thresholds
- Any missed switch points are detected and logged

The system covers all three main scenarios:
1. ✅ Metro-to-metro transfers
2. ✅ Driving/walking to metro (pre-boarding)
3. ✅ Any mode changes along the route
