# GeoWake device testing guide

This quick guide helps you validate alarm reliability, simulation, and diagnostics on a physical device.

Prereqs
- Enable location permissions and notifications.
- After adding/renaming assets in pubspec.yaml, do a full restart (hot-restart isn’t enough to refresh AssetManifest on device).

Where to find tools in-app
- Open the Settings drawer (top-left) on Home.
  - Diagnostics: run quick self-tests, happy-path, “Alarm should fire”, view live log tail, and inspect the last alarm-eval snapshot.
  - Dev Route Simulator: load a demo route (auto-loads), start tracking with simulation, play/pause, speed++.

Happy-path checks (Diagnostics)
1) Run self-tests
   - Confirms route asset loads, sessionInfo channel is alive, and stopTracking clears flags.
2) Run happy path
   - Injects positions on a demo route and starts/stops tracking cleanly.
3) Alarm should fire
   - Sets a 40 m distance and fast-forwards the sim; expects a full-screen alarm and a notification within ~25s.

Live log tail
- At the bottom of Diagnostics, watch alarm/session logs in real time.
- Use the filter chips and Clear to manage the view.

Route errors: what to check
- We added a transit→driving fallback in DirectionService. If transit returns empty/non-OK, the app automatically retries driving.
- If you still see “Route Error” on Wake Me:
  - Try toggling off Metro Mode and retry.
  - Check device connectivity.
  - Open Diagnostics and re-run, then look at the tail and the last directions body snapshot (logged to console). Share that snapshot so we can adapt response normalization if your backend shape differs.

Simulator tips
- The simulator auto-loads the first demo route. Use Play/Speed++/Seek to move quickly.
- “Stop All” stops the sim and tracking (clears flags so the app won’t auto-resume).

Optional: run tests locally (Windows PowerShell)
- From the workspace root:

```
flutter test --disable-dds
```

Troubleshooting
- Assets not loading in Dev Simulator: ensure `assets/routes/` exists in `pubspec.yaml` and perform a full app restart after `flutter pub get`.
- Logs missing in tail: keep the Diagnostics screen open; the background forwards alarm/session logs over the service bridge while you’re on this screen.
- Stuck auto-navigation: use “Stop All” in Dev Simulator or Stop Tracking in Diagnostics to clear flags.
