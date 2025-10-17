# Device Harness 2.0 – Design Outline

## Goals
- Offer an on-device control room that exercises every critical alarm pathway (distance, stops, time, multi-event metro transfers).
- Surface deterministic logs and verdicts directly on the device—no need to attach a debugger.
- Allow testers to dial custom thresholds, event windows, and simulation speeds to mimic real commutes.
- Validate notification behavior (persistent tray item, ignore suppression, end-tracking action) and background resilience while the app UI is closed.

## Screen Entry
- **Menu item:** add "Device Harness" beneath Diagnostics in the settings drawer.
- **Route:** `/deviceHarness`, backed by a dedicated `DeviceHarnessScreen` widget. The existing Diagnostics screen links to it for continuity, but the harness is now a first-class destination.

## Layout Overview
1. **Tracking Status Header**
   - Shows live background service state (Running / Idle), tracking active flag, suppress-progress flag, latest ETA/distance sample.
   - Includes quick actions: `Start Simulation`, `Stop Tracking`, `Reset Logs`.

2. **Scenario Config Card**
   - Inputs for distance threshold (meters), stops threshold (remaining stops), time threshold (minutes).
   - Dropdown to choose primary evaluation mode (distance / stops / time) plus toggles to additionally emit transfer alarms.
   - Slider for event trigger window (meters) and simulation speed multiplier (1×–24×).
   - Action buttons:
     - `Run Metro Multi-Stage` (Nagasandra → Majestic → Whitefield → Sumadhura).
     - `Run Custom Point-to-Point` (future: uses map pickers or asset selection).

3. **Milestone Board**
   - Four cards representing: `Board at Nagasandra`, `Switch at Majestic`, `Exit at Whitefield`, `Destination Arrival`.
   - Each card displays state: Pending → Triggered → Acknowledged, with timestamps and trigger distance/time deltas.
   - Optional warning chip if a milestone hasn’t fired before the user-specified timeout.

4. **Notification & Background Monitor**
   - Shows whether the persistent notification is visible (using periodic `NotificationQuery` channel) and whether `suppressProgressNotifications` is set.
   - Buttons to simulate gestures: `Simulate Swipe Dismiss`, `Simulate Ignore`, `Tap Notification` (foreground action) using background channel hooks.
   - Shows End Tracking action state and verifies the background service stopped.

5. **Log Console**
   - Scrollable tablet-style console with filter chips (Alarm, Notification, Service, Test).
   - Each entry: timestamp, tag, message; failures highlighted in red.
   - Export button to copy logs to clipboard for bug reports.

6. **Test Suite Accordion**
   - Tests run sequentially and push results above the fold.
   - Planned automated checks:
     1. **Metro Multi-Stage Alarm** – ensures all choreographed events fire and final alarm arrives.
     2. **Notification Lifecycle** – asserts reappearance after swipe unless ignored, verifies End Tracking stops service.
     3. **Background Resilience** – closes app (via `SystemNavigator.pop`), waits for progress updates, ensures tracking stays alive.
     4. **Stops & Time Threshold Parity** – reconfigures orchestrator with provided thresholds and validates single-fire semantics.
   - For each test: summary verdict, duration, detailed bullet log, and remediation hints if failed.

## Service/Event Plumbing
- Extend `TrackingService` background isolate to emit:
  - `progressUpdate` (remaining meters/stops/time) every adaptive interval.
  - `notificationState` when progress notification is shown/hidden (via plugin callback).
  - `trackingStatus` when `_trackingActive` flips or service stops.
- Build `HarnessEventStream` (foreground) subscribing to:
  - `fireAlarm`, `orchestratorEvent`, `progressUpdate`, `trackingStatus`, `notificationState`.
  - Locally generated `uiLog` events from the harness controller.

## Metro Scenario Enhancements
- Keep `MetroRouteScenarioRunner`, add:
  - `mode` parameter (distance/stops/time) and conversions for user-provided thresholds.
  - Option to emit synthetic stops/time metadata to orchestrator for stops/time tests.
  - Event metadata (station name, cumulative meters, estimated minutes) returned to harness UI to render the milestone board.

## Notification Behavior Fixes (Planned Changes)
- When progress notification is dismissed (Android 13 allows dismissing ongoing notifications), background isolate receives `notificationCancelled` callback and immediately re-posts unless `suppressProgressNotifications` is true.
- Ensure `End Tracking` action triggers `stopTracking` and suppresses re-posting.
- After re-show, log to harness so testers can confirm reappearance.

## Background Resilience Verification
- Expose `HarnessBackgroundProbe` that:
  - Sends a ping to the background service every 10s during tests.
  - Confirms isolate responds with last GPS timestamp; failure flips test to failed.
  - Optionally triggers `SystemNavigator.pop` (prompt user first) to simulate UI swipe-away.

## Error Surfacing Strategy
- All harness tests funnel errors through `HarnessTestFailure`, which automatically raises a red toast, logs to console, and pins the failure message under the relevant test card.
- Provide "Open Alarm Screen" button when an alarm is expected but not yet visible to assist manual verification.

## Deliverables
1. `lib/screens/device_harness_screen.dart` – orchestrates layout components.
2. `lib/harness/harness_controller.dart` – manages state, event streams, and logging.
3. `lib/harness/harness_models.dart` – DTOs for scenario config, milestone status, and logs.
4. Updated `metro_route_scenario.dart` with configuration hooks.
5. Notification persistence fixes in `notification_service.dart` + background isolate bridging.
6. New background events and test automation utilities in `trackingservice`.
7. README section describing how to launch and interpret harness results.
