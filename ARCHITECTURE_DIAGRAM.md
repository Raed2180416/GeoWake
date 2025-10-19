# Notification Persistence Architecture Diagram

## System Overview

```
┌──────────────────────────────────────────────────────────────────────┐
│                         GeoWake Application                           │
│                                                                       │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │                    Foreground App (UI)                      │    │
│  │  • Immediate notification updates                            │    │
│  │  • Real-time progress tracking                               │    │
│  │  • User interaction handling                                 │    │
│  └───────────────────────┬─────────────────────────────────────┘    │
│                          │                                            │
│                          │ (app backgrounded)                         │
│                          ▼                                            │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │          Background Service (Foreground Mode)               │    │
│  │  • Location tracking continues                               │    │
│  │  • Heartbeat timer: every 5 seconds                          │    │
│  │  • Re-elevates to foreground on each beat                    │    │
│  │  • Updates notification with progress                        │    │
│  │  • Persists state to SharedPreferences                       │    │
│  └───────────────────────┬─────────────────────────────────────┘    │
│                          │                                            │
│                          │ (app swiped away / service killed)         │
│                          ▼                                            │
└──────────────────────────────────────────────────────────────────────┘
                           │
                           │ AlarmManager schedules wake-up
                           ▼
┌──────────────────────────────────────────────────────────────────────┐
│                    Android System Layer                               │
│                                                                       │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │               AlarmManager (Native)                          │    │
│  │  • Wakes device every 30 seconds                             │    │
│  │  • Uses setExactAndAllowWhileIdle                            │    │
│  │  • Bypasses Doze mode restrictions                           │    │
│  │  • Triggers ProgressWakeReceiver                             │    │
│  │  • Survives app termination                                  │    │
│  └───────────────────────┬─────────────────────────────────────┘    │
│                          │                                            │
│                          │ BroadcastReceiver triggered                │
│                          ▼                                            │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │            ProgressWakeReceiver                              │    │
│  │  • Reads cached notification payload                         │    │
│  │  • Posts notification to system                              │    │
│  │  • Reschedules next AlarmManager wake-up                     │    │
│  │  • Works even if app is dead                                 │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                                                       │
│                          (device restarts)                            │
│                          ▼                                            │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │                  Boot Receiver                               │    │
│  │  • Triggered on BOOT_COMPLETED                               │    │
│  │  • Checks if tracking was active                             │    │
│  │  • Reschedules AlarmManager wake-ups                         │    │
│  │  • Prepares for app auto-resume                              │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                                                       │
└──────────────────────────────────────────────────────────────────────┘
```

## Timeline: What Happens When App is Swiped Away

```
Time    Event                           Component               Action
────    ─────                           ─────────               ──────
T+0s    User swipes app away            Android System          Kills app process
T+0s    Background service detects      Background Service      Continues running
T+5s    Heartbeat timer fires           Background Service      Updates notification
T+5s    Check foreground status         Background Service      Re-elevates if needed
T+10s   Heartbeat timer fires           Background Service      Updates notification
T+15s   Heartbeat timer fires           Background Service      Updates notification
T+20s   Heartbeat timer fires           Background Service      Updates notification
T+25s   Heartbeat timer fires           Background Service      Updates notification
T+30s   AlarmManager alarm fires        AlarmManager            Wakes device
T+30s   Receiver triggered              ProgressWakeReceiver    Restores notification
T+30s   Next alarm scheduled            ProgressWakeReceiver    Reschedules for T+60s
T+35s   Heartbeat timer fires           Background Service      Updates notification
...     (continues)
```

## Scenario: Service Killed After App Swipe

```
Time    Event                           Component               Action
────    ─────                           ─────────               ──────
T+0s    User swipes app away            Android System          Kills app process
T+0s    System kills background service Android System          Service terminated
T+30s   AlarmManager alarm fires        AlarmManager            Wakes device
T+30s   Receiver triggered              ProgressWakeReceiver    Reads cached data
T+30s   Notification posted             ProgressWakeReceiver    Shows notification
T+30s   Next alarm scheduled            ProgressWakeReceiver    Reschedules for T+60s
T+60s   AlarmManager alarm fires        AlarmManager            Wakes device
T+60s   Receiver triggered              ProgressWakeReceiver    Restores notification
...     (continues until tracking ends)
```

## Scenario: Device Restart

```
Time    Event                           Component               Action
────    ─────                           ─────────               ──────
T+0s    User restarts device            Android System          System shutdown
T+30s   Device boots up                 Android System          BOOT_COMPLETED broadcast
T+30s   Boot receiver triggered         BootReceiver            Reads tracking state
T+30s   Check if tracking active        BootReceiver            Finds active flag
T+30s   Reschedule AlarmManager         BootReceiver            Creates new alarms
T+45s   User unlocks device             User                    Home screen shown
T+45s   App auto-launches               Bootstrap Service       Detects active tracking
T+45s   Background service starts       TrackingService         Resumes tracking
T+45s   Notification restored           NotificationService     Shows current progress
T+50s   Heartbeat starts                Background Service      Regular updates resume
```

## Data Flow: Notification Persistence

```
┌─────────────────────────────────────────────────────────────────┐
│                    Notification State                            │
└───────────┬─────────────────────────────────────────────────────┘
            │
            │ (persisted to)
            ▼
┌─────────────────────────────────────────────────────────────────┐
│               SharedPreferences (Android)                        │
│                                                                  │
│  Key: flutter.gw_progress_payload_v1                            │
│  Value: {                                                        │
│    "title": "Journey to Downtown",                              │
│    "subtitle": "Remaining: 2.3 km · ETA 8m",                    │
│    "progress": 0.45,                                             │
│    "ts": "2024-01-15T10:30:00Z"                                  │
│  }                                                               │
└───────────┬─────────────────────────────────────────────────────┘
            │
            │ (read by)
            ▼
┌─────────────────────────────────────────────────────────────────┐
│            ProgressWakeReceiver (on alarm)                       │
│  • Reads cached payload                                          │
│  • Creates notification with cached data                         │
│  • Shows notification to user                                    │
└─────────────────────────────────────────────────────────────────┘
```

## State Machine: Tracking Lifecycle

```
┌──────────┐
│  IDLE    │
└────┬─────┘
     │ start_tracking()
     ▼
┌──────────────────┐
│  TRACKING_ACTIVE │◄──────┐
│  (notification   │       │
│   visible)       │       │ (heartbeat every 5s)
└────┬─────────────┘       │
     │                     │
     │ (multiple paths)    │
     │                     │
     ├─────────────────────┘
     │
     │ app_swiped_away()
     ▼
┌──────────────────┐
│ TRACKING_DETACHED│◄──────┐
│ (AlarmManager    │       │
│  fallback active)│       │ (alarm every 30s)
└────┬─────────────┘       │
     │                     │
     │                     │
     ├─────────────────────┘
     │
     │ end_tracking_button() OR ignore_button()
     ▼
┌──────────┐
│ STOPPED  │
│ OR       │
│SUPPRESSED│
└──────────┘
```

## Component Interaction

```
┌───────────────┐      invoke      ┌─────────────────┐
│   Foreground  │◄─────────────────│   Background    │
│   Isolate     │                  │   Isolate       │
│               │─────────────────►│                 │
│  • UI updates │   sendToPort     │  • GPS tracking │
│  • User input │                  │  • Alarms       │
└───────┬───────┘                  └────────┬────────┘
        │                                   │
        │ MethodChannel                    │ SharedPreferences
        ▼                                   ▼
┌───────────────────────────────────────────────────┐
│            Android Native Layer                    │
│                                                    │
│  ┌──────────────┐  ┌────────────┐  ┌──────────┐ │
│  │ AlarmMethod  │  │ Progress   │  │  Boot    │ │
│  │ Channel      │  │ Wake       │  │ Receiver │ │
│  │ Handler      │  │ Scheduler  │  │          │ │
│  └──────────────┘  └────────────┘  └──────────┘ │
│                                                    │
└────────────────────┬───────────────────────────────┘
                     │
                     │ NotificationManager
                     ▼
┌─────────────────────────────────────────────────┐
│         Android System Notification Tray         │
│                                                  │
│  ┌────────────────────────────────────────┐    │
│  │  🔔 Journey to Downtown                │    │
│  │  Remaining: 2.3 km · ETA 8m            │    │
│  │  ═════════════════════                  │    │
│  │  [End Tracking]  [Ignore]              │    │
│  └────────────────────────────────────────┘    │
└─────────────────────────────────────────────────┘
```

## Failure Recovery Paths

```
┌─────────────────────────────────┐
│  Failure Scenario               │
└─────────────────┬───────────────┘
                  │
    ┌─────────────┼─────────────┬──────────────┐
    │             │             │              │
    ▼             ▼             ▼              ▼
┌──────┐    ┌──────────┐  ┌────────┐   ┌─────────┐
│ App  │    │Background│  │Service │   │ Device  │
│Swipe │    │  Timer   │  │Killed  │   │Restart  │
│      │    │  Fails   │  │        │   │         │
└──┬───┘    └────┬─────┘  └───┬────┘   └────┬────┘
   │             │            │             │
   │             │            │             │
   │         ┌───▼────────────▼──┐          │
   │         │  AlarmManager     │          │
   │         │  Fallback Active  │          │
   │         └───┬────────────────┘          │
   │             │                           │
   └─────────────┴───────────────────────────┘
                 │
                 ▼
        ┌─────────────────┐
        │  Notification   │
        │  Restored       │
        └─────────────────┘
```

## Legend

```
┌──────┐
│ Box  │  = Component or State
└──────┘

   │      = Flow or Connection
   ▼      

  ◄──    = Bidirectional or Loop

  ═══    = Progress Bar in Notification
```

---

**Key Insight**: The system works through **redundancy**. Multiple independent mechanisms ensure that if any single component fails, another will take over. This is essential for Android 15's aggressive background restrictions.
