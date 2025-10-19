# GeoWake System Integration Guide

## Table of Contents
1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Core Components](#core-components)
4. [Data Flow](#data-flow)
5. [Subsystems](#subsystems)
6. [Integration Points](#integration-points)
7. [State Management](#state-management)
8. [Testing & Diagnostics](#testing--diagnostics)
9. [Complete File Index](#complete-file-index)

---

## Overview

GeoWake is a location-based alarm application that wakes users when they approach their destination. The system uses GPS tracking, route following, ETA calculation, and intelligent alarm triggering to ensure users never miss their stop.

### Key Features
- **Multi-Modal Alarms**: Distance-based, time-based, and transit stop-based alarms
- **Intelligent Route Following**: Snap-to-route with deviation detection and automatic rerouting
- **Background Tracking**: Persistent tracking with battery-aware power policies
- **Offline Support**: Route caching and offline mode coordination
- **Smart ETA**: Adaptive ETA calculation with speed smoothing and movement classification
- **Robust Persistence**: State restoration after app restarts or crashes

### Technology Stack
- **Framework**: Flutter (Dart)
- **Maps**: Google Maps Platform
- **Storage**: Hive (local DB), SharedPreferences (flags), Secure Storage (credentials)
- **Background Service**: flutter_background_service
- **Geolocation**: geolocator package
- **Platform Integration**: iOS & Android native alarm scheduling

---

## Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      UI Layer (Screens)                      │
│  Home │ MapTracking │ Settings │ Diagnostics │ Splash       │
└────────────────────────┬────────────────────────────────────┘
                         │
┌────────────────────────┴────────────────────────────────────┐
│                    Service Layer                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │  Tracking    │  │  Alarm       │  │  Route       │     │
│  │  Service     │  │  Orchestrator│  │  Management  │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │  Navigation  │  │  Persistence │  │  Notification│     │
│  │  & ETA       │  │  Manager     │  │  Service     │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
└────────────────────────┬────────────────────────────────────┘
                         │
┌────────────────────────┴────────────────────────────────────┐
│                  Infrastructure Layer                        │
│  API Client │ Offline Coord │ Event Bus │ Metrics │ Logger │
└─────────────────────────────────────────────────────────────┘
```

### Component Organization

```
lib/
├── config/          # Configuration and thresholds
├── debug/           # Development and debugging tools
├── logging/         # Logging infrastructure
├── metrics/         # Metrics collection
├── models/          # Data models
├── screens/         # UI screens
├── services/        # Core business logic
│   ├── eta/         # ETA calculation engine
│   ├── geometry/    # Geometric calculations
│   ├── metrics/     # Metrics services
│   ├── persistence/ # State persistence
│   ├── refactor/    # New architecture components
│   ├── simulation/  # Route simulation for testing
│   └── trackingservice/ # Background tracking modules
├── themes/          # UI themes
└── widgets/         # Reusable UI components
```

---

## Core Components

### 1. Bootstrap & Initialization

**Files**: `main.dart`, `services/bootstrap_service.dart`

**Purpose**: Fast app startup with intelligent state restoration

**Flow**:
1. **Early Phase** (< 600ms target):
   - Check if tracking was active (`SharedPreferences` flag)
   - Check if background service is running
   - Attempt quick session state load
   - Emit "ready" signal with navigation route decision

2. **Late Phase** (background):
   - Initialize Hive database
   - Setup API client with authentication
   - Initialize notification channels
   - Restore tracking service state
   - Restore journey progress notification
   - Attempt late recovery if needed

**Integration Points**:
- `BootstrapService.start()` called from `main.dart`
- Emits `BootstrapState` stream consumed by `SplashScreen`
- Determines initial navigation route (`/` or `/mapTracking`)

### 2. Tracking Service

**Files**: `services/trackingservice.dart`, `services/trackingservice/*.dart`

**Purpose**: Core background location tracking and alarm coordination

**Key Responsibilities**:
- GPS position stream management with battery-aware power policies
- Route registration and management via `ActiveRouteManager`
- ETA calculation and smoothing
- Alarm eligibility evaluation and triggering
- Deviation detection via `DeviationMonitor`
- Persistent state via `TrackingSessionStateFile`

**Power Policy Tiers**:
```dart
High Battery (>50%): 
  - High accuracy, 20m filter, 1s update tick
  
Medium Battery (21-50%):
  - Medium accuracy, 35m filter, 2s update tick
  
Low Battery (≤20%):
  - Low accuracy, 50m filter, 3s update tick
```

**State Machine**:
```
Idle → Starting → Tracking → Stopping → Idle
                      ↓
                   Alarming → Ending
```

### 3. Alarm System

**Files**: 
- `services/alarm_orchestrator.dart` - High-level coordination
- `services/alarm_restore_service.dart` - Restore after restart
- `services/alarm_rollout.dart` - Gradual rollout controls
- `services/alarm_scheduler.dart` - OS-level alarm scheduling
- `services/alarm_player.dart` - Audio playback
- `services/alarm_deduplicator.dart` - Duplicate prevention
- `services/trackingservice/alarm.dart` - Legacy alarm logic

**Alarm Modes**:

1. **Distance Mode**: Triggers when straight-line distance to destination ≤ threshold
   ```dart
   distanceToDestination ≤ alarmValue (in km → m)
   ```

2. **Time Mode**: Triggers when ETA ≤ threshold (with eligibility checks)
   ```dart
   Requirements:
   - Distance traveled ≥ 100m
   - ETA samples ≥ 3
   - Speed ≥ 0.5 m/s
   - Time since start ≥ 30s
   
   Then: smoothedETA ≤ alarmValue (in min → s)
   ```

3. **Stops Mode**: Multi-phase transit alarms
   - Pre-boarding: Alert 1000m before first transit boarding
   - Event alarms: Transfer/mode-change alerts
   - Destination: When remaining stops ≤ threshold

**Rollout Stages**:
- **Shadow**: Orchestrator evaluates but doesn't fire (metrics only)
- **Dual**: Both legacy and orchestrator can fire (duplicate suppression)
- **Primary**: Orchestrator is authoritative (legacy suppressed)

**Fallback Mechanism**:
- Schedules OS-level alarm as backup
- Persists to `PendingAlarmStore`
- Restores on app restart via `AlarmRestoreService`
- 2-minute grace window for missed triggers

### 4. Route Management

**Files**:
- `services/active_route_manager.dart` - Active route state
- `services/route_registry.dart` - Multi-route management
- `services/route_cache.dart` - Offline route storage
- `services/route_queue.dart` - Route fetch queue
- `services/snap_to_route.dart` - Position snapping
- `services/reroute_policy.dart` - Rerouting logic
- `services/offline_coordinator.dart` - Online/offline coordination

**Route Following**:
1. User position → Snap to nearest segment
2. Calculate lateral offset from route
3. Update progress (distance/fraction along route)
4. Compute remaining distance/time
5. Detect deviation if offset > threshold

**Deviation Thresholds**:
```
< 100m:      Ignore (normal GPS jitter)
100-150m:    Local switch to better registered route
> 150m:      Trigger reroute policy
```

**Reroute Policy**:
- Battery-tiered cooldown (20-30s)
- Online connectivity check
- Exponential backoff on failures
- Preserves user context (destination, alarm settings)

### 5. Navigation & ETA

**Files**:
- `services/eta/eta_engine.dart` - Adaptive ETA calculation
- `services/eta/eta_models.dart` - ETA data models
- `services/eta_utils.dart` - ETA utilities
- `services/heading_smoother.dart` - Heading smoothing
- `services/movement_classifier.dart` - Walking/driving detection
- `services/sensor_fusion.dart` - Sensor data fusion
- `services/sample_validator.dart` - GPS quality validation
- `services/direction_service.dart` - Turn-by-turn directions

**ETA Engine Strategy**:
1. Collect recent position samples (window-based)
2. Classify movement mode (walking/driving/stationary)
3. Calculate speed with GPS noise floor filtering
4. Apply mode-specific smoothing factors
5. Compute ETA = remaining_distance / smoothed_speed
6. Handle edge cases (stopped, speed too low, insufficient samples)

**Movement Classification**:
```dart
Speed < 0.3 m/s:     Stationary (GPS noise)
0.3 - 2.6 m/s:       Walking
2.6 - 4.5 m/s:       Fast walking / Jogging
> 4.5 m/s:           Driving
```

### 6. Persistence & State

**Files**:
- `services/persistence/persistence_manager.dart` - Persistence coordination
- `services/persistence/snapshot.dart` - State snapshots
- `services/persistence/tracking_session_state.dart` - Session state file
- `services/pending_alarm_store.dart` - Pending alarm storage
- `services/secure_storage.dart` - Secure credential storage

**Persistence Strategy**:

1. **Fast Flags** (SharedPreferences):
   - `tracking_active_v1`: Quick startup check
   - `resume_pending`: Resume after background kill

2. **Session State** (JSON file):
   - Destination coordinates & name
   - Alarm mode & value
   - Route polyline & metadata
   - Current progress

3. **Alarm State** (PendingAlarmStore):
   - Scheduled fallback alarm details
   - Trigger timestamp
   - Alarm payload

4. **Cache** (Hive):
   - Route directions
   - Recent locations
   - User preferences

**Restoration Flow**:
```
App Start
   ↓
Check fast flag → Load session file → Restore tracking
   ↓                     ↓                  ↓
   No                  Success           Background attach
   ↓                     ↓                  or restart
Navigate home      Navigate to map    
                   with restored state
```

### 7. Notification System

**Files**:
- `services/notification_service.dart` - Notification management
- `services/notification_ids.dart` - ID constants

**Notification Types**:

1. **Journey Progress** (ID: 1):
   - Persistent notification during tracking
   - Updates: Distance/time remaining, ETA
   - Actions: Stop tracking
   - Battery-tiered update frequency

2. **Wake-Up Alarm** (ID: 2):
   - Critical high-priority notification
   - Full-screen intent (wakes device)
   - Actions: Continue tracking, End tracking
   - Accompanied by audio + vibration

3. **Pre-boarding Alert** (ID: 3, transit only):
   - Medium priority
   - Alerts before first transit boarding
   - Action: Continue tracking

4. **Event Alerts** (ID: 4+, transit only):
   - Transfer and mode-change notifications
   - Allows tracking continuation

**Restoration**:
- Progress notification restored on app resume
- Pending alarm UI restored if alarm fired while app backgrounded

### 8. Geometry & Calculations

**Files**:
- `services/geometry/segment_projection.dart` - Point-to-segment projection
- `services/polyline_decoder.dart` - Polyline encoding/decoding
- `services/polyline_simplifier.dart` - Route simplification

**Key Algorithms**:

1. **Snap to Route**:
   ```
   For each segment in polyline:
     Project point onto segment
     Calculate distance to segment
   Return nearest projection
   ```

2. **Progress Calculation**:
   ```
   Distance to snap point along route
   Fraction = distance_to_snap / total_route_length
   Remaining = total_route_length - distance_to_snap
   ```

3. **Deviation Detection**:
   ```
   Dynamic threshold = base + (segment_length × fraction)
   Capped at maximum
   Deviation = lateral_offset - threshold
   ```

---

## Data Flow

### Primary User Flow: Starting Tracking

```
1. User selects destination on map
   ↓
2. MapTrackingScreen.startTracking()
   ↓
3. TrackingService.startTracking(destination, alarmMode, alarmValue)
   ↓
4. Background service starts (_onStart)
   ↓
5. Fetch route from Google Directions API
   ↓
6. Register route with ActiveRouteManager
   ↓
7. Start GPS location stream
   ↓
8. Begin position updates loop
```

### Position Update Flow

```
GPS Position
   ↓
[Validate Quality] → Sample validator
   ↓
[Update Tracking State]
   - Last position/time
   - Distance traveled from start
   - ETA samples
   ↓
[Ingest into ActiveRouteManager]
   - Snap to route
   - Calculate offset
   - Update progress
   - Compute remaining distance
   ↓
[Feed DeviationMonitor]
   - Track offset history
   - Sustain window logic
   - Emit deviation events
   ↓
[Evaluate Alarms]
   - Check eligibility
   - Compare to thresholds
   - Trigger if conditions met
   ↓
[Update UI]
   - Progress notification
   - Map camera position
   - ETA display
```

### Alarm Firing Flow

```
Alarm Condition Met
   ↓
[Orchestrator.triggerDestinationAlarm()]
   ↓
[Phase 1: Notification]
   - Show wake-up notification
   - Full-screen intent
   - Emit AlarmFiredPhase1Event
   ↓
[Phase 2: Audio/Vibration]
   - Play selected ringtone
   - Start vibration pattern
   - Mark alarm as fired
   - Emit AlarmFiredPhase2Event
   ↓
[Cancel Fallback]
   - Cancel scheduled OS alarm
   - Clear pending alarm store
   ↓
[State Update]
   - Update tracking state
   - Persist alarm timestamp
   - Stop tracking (if destination alarm)
```

### Deviation & Reroute Flow

```
High Lateral Offset Detected
   ↓
[DeviationMonitor Sustain Window]
   ↓
   ├─ < 100m: Ignore
   ├─ 100-150m: Check for better registered route
   │   └─ If found within margin: Switch route
   └─ > 150m: Trigger reroute policy
       ↓
   [ReroutePolicy]
       - Check cooldown
       - Check online status
       - Emit reroute request
       ↓
   [OfflineCoordinator]
       - Try cache first
       - Fetch from API if online
       - Return new route
       ↓
   [Register New Route]
       - Update ActiveRouteManager
       - Reset deviation monitor
       - Continue tracking
```

---

## Subsystems

### Metrics & Observability

**Files**:
- `metrics/metrics_registry.dart` - In-memory metrics
- `services/metrics/app_metrics.dart` - Application-level metrics
- `services/metrics/metrics.dart` - Metrics infrastructure
- `logging/app_logger.dart` - Structured logging
- `services/log.dart` - Simple logging utility

**Metrics Types**:
- **Counters**: Event occurrences (API calls, alarms fired)
- **Gauges**: Current values (active sessions, battery level)
- **Histograms**: Distributions (latencies, distances)

**Logging Levels**:
- **Debug**: Verbose internal state
- **Info**: Normal operations
- **Warning**: Recoverable issues
- **Error**: Failures requiring attention

**Key Metrics**:
- `tracking.started`, `tracking.stopped`
- `alarm.fired`, `alarm.dismissed`
- `reroute.triggered`, `reroute.success`
- `deviation.detected`, `route.switched`
- `api.call.duration`, `eta.calculation.time`

### Testing & Simulation

**Files**:
- `screens/diagnostics_screen.dart` - On-device diagnostics
- `screens/dev_route_sim_screen.dart` - Route simulation UI
- `services/simulation/route_simulator.dart` - Route playback
- `services/simulation/route_asset_loader.dart` - Test route loading
- `services/simulation/metro_route_scenario.dart` - Transit scenarios
- `services/test_tuning.dart` - Test mode acceleration
- `widgets/device_harness_panel.dart` - Test harness UI

**Test Modes**:
1. **Unit Tests**: Service-level with mock dependencies
2. **Integration Tests**: Multi-service with real GPS simulation
3. **Device Tests**: On-device with simulated routes
4. **Manual Tests**: Diagnostics screen with self-tests

**Simulation Features**:
- Load route from JSON asset
- Playback at variable speed (1x, 2x, 4x, 8x, 16x)
- Seek to specific progress (50%, 95%)
- Live map visualization
- Integration with real tracking service

### Configuration & Tuning

**Files**:
- `config/alarm_thresholds.dart` - Alarm-related constants
- `config/app_config.dart` - General app configuration
- `config/feature_flags.dart` - Feature toggles
- `config/power_policy.dart` - Battery-aware settings

**Tunable Parameters**:
- Movement classification speeds
- Deviation thresholds and sustain windows
- ETA smoothing factors
- Power policy tiers
- Alarm eligibility gates
- Reroute cooldowns

**Feature Flags**:
- New alarm orchestrator rollout stage
- Experimental ETA algorithms
- Debug visualizations
- Test acceleration

### Security & Privacy

**Files**:
- `services/secure_storage.dart` - Encrypted credential storage
- `services/ssl_pinning.dart` - API certificate pinning
- `services/api_client.dart` - Authenticated API access

**Security Measures**:
- API keys stored in secure storage (flutter_secure_storage)
- SSL certificate pinning for API calls
- Location data kept local (no server upload)
- User authentication for cloud features
- Permission checks before location access

---

## Integration Points

### External Services

1. **Google Maps Platform**:
   - **Directions API**: Route calculation
   - **Maps SDK**: Map rendering and interaction
   - **Geocoding API**: Address search (via places_service)

2. **Platform APIs**:
   - **iOS**: UILocalNotification, Background execution
   - **Android**: Notification channels, Foreground service, AlarmManager

3. **Device Sensors**:
   - GPS/GNSS via geolocator
   - Battery state
   - Network connectivity

### Inter-Service Communication

**Event Bus** (`services/event_bus.dart`):
- Decoupled publish-subscribe messaging
- Events: Alarm fired, route switched, deviation detected, etc.
- Subscribers: UI screens, metrics, logging

**Streams**:
- Position updates: GPS → TrackingService → UI
- Session state: TrackingService → MapTrackingScreen
- Bootstrap state: BootstrapService → SplashScreen

**Direct Calls**:
- UI → TrackingService (start/stop tracking)
- TrackingService → AlarmOrchestrator (trigger alarm)
- ActiveRouteManager → DeviationMonitor (offset updates)

### UI Integration

**Screen Navigation**:
```
SplashScreen (BootstrapService)
   ↓
HomeScreen
   ↓
MapTrackingScreen ←→ SettingsDrawer
   ↓                     ↓
AlarmFullscreen    RingtonesScreen
                   DiagnosticsScreen
```

**State Updates**:
- Reactive via StreamBuilder on service streams
- Progress updates via periodic timer
- Event-driven via event bus subscriptions

---

## State Management

### Tracking State

```dart
{
  isTracking: bool,
  destination: LatLng,
  destinationName: String,
  alarmMode: 'distance' | 'time' | 'stops',
  alarmValue: double,
  currentPosition: LatLng?,
  distanceRemaining: double?,
  timeRemaining: Duration?,
  eta: DateTime?,
  progress: double,
  routePolyline: List<LatLng>,
  alarmFired: bool
}
```

### Route State (ActiveRouteManager)

```dart
{
  activeRoute: RegisteredRoute,
  snap: SnapResult,
  progress: RouteProgress,
  deviation: double,
  pendingSwitch: RouteSwitch?,
  alternatives: List<RegisteredRoute>
}
```

### Alarm State (AlarmOrchestrator)

```dart
{
  fired: bool,
  firedAt: DateTime?,
  scheduledPending: PendingAlarm?,
  rolloutStage: OrchestratorRolloutStage
}
```

### Bootstrap State

```dart
{
  phase: BootstrapPhase,
  autoResumed: bool,
  targetRoute: String,
  mapTrackingArgs: Map?,
  error: String?
}
```

---

## Testing & Diagnostics

### Test Infrastructure

**Unit Tests** (`test/`):
- Service logic in isolation
- Mock dependencies via interfaces
- Fast execution (<1s per test)

**Integration Tests** (`integration_test/`):
- Multi-service interactions
- Simulated GPS position streams
- End-to-end alarm scenarios

**Device Tests**:
- DiagnosticsScreen self-tests
- Route simulation with real tracking
- Happy path validation (route → tracking → alarm)

### Debugging Tools

**DiagnosticsScreen**:
- Self-tests: Route loading, service health, flag clearing
- Happy path runner: Full simulation from start to alarm
- Log tail: Recent 200 log lines
- Session info inspection
- Manual trigger tests

**DevRouteSimScreen**:
- Load test routes from assets
- Playback control (play/pause/speed/seek)
- Live map visualization
- Integration with real tracking service

**Metrics Dashboard** (via DevServer):
- Counter/gauge/histogram inspection
- Real-time metric updates
- HTTP endpoint at localhost:8081

### Common Issues & Solutions

1. **Alarm not firing**:
   - Check eligibility (time mode: distance traveled, ETA samples)
   - Verify threshold calculation (km→m, min→s)
   - Review rollout stage (shadow suppresses alarms)
   - Check alarm restore grace period

2. **Excessive rerouting**:
   - Verify deviation thresholds
   - Check cooldown configuration
   - Review route quality (sharp turns, GPS coverage)

3. **Poor ETA accuracy**:
   - Check movement classification (speed thresholds)
   - Review ETA sample count
   - Verify GPS noise floor filtering
   - Check for insufficient speed

4. **Battery drain**:
   - Verify power policy tier selection
   - Check update frequency
   - Review background execution (should use FG service)

5. **State not restored**:
   - Check fast flag in SharedPreferences
   - Verify session state file exists
   - Review bootstrap early decision logs
   - Check background service running status

---

## Complete File Index

### Configuration (4 files)
- `config/alarm_thresholds.dart` - Alarm/routing threshold constants
- `config/app_config.dart` - General app configuration
- `config/feature_flags.dart` - Feature toggle flags
- `config/power_policy.dart` - Battery-aware power policies

### Debug (2 files)
- `debug/demo_tools.dart` - Demo and testing utilities
- `debug/dev_server.dart` - Development HTTP server

### Logging (1 file)
- `logging/app_logger.dart` - Structured logging infrastructure

### Main Entry (1 file)
- `main.dart` - Application entry point

### Metrics (1 file)
- `metrics/metrics_registry.dart` - In-memory metrics collection

### Models (2 files)
- `models/pending_alarm.dart` - Pending alarm data model
- `models/route_models.dart` - Route and direction models

### Screens (10 files)
- `screens/alarm_fullscreen.dart` - Full-screen alarm UI
- `screens/dev_route_sim_screen.dart` - Route simulation screen
- `screens/diagnostics_screen.dart` - Diagnostics and testing UI
- `screens/homescreen.dart` - Main home screen
- `screens/maptracking.dart` - Active tracking map screen
- `screens/otherimpservices/preload_map_screen.dart` - Map preload utility
- `screens/otherimpservices/recent_locations_service.dart` - Recent locations
- `screens/ringtones_screen.dart` - Ringtone selection
- `screens/settingsdrawer.dart` - Settings drawer
- `screens/splash_screen.dart` - Splash/loading screen

### Services - Core (42 files)
- `services/active_route_manager.dart` - Active route state management
- `services/alarm_deduplicator.dart` - Alarm duplicate prevention
- `services/alarm_orchestrator.dart` - High-level alarm coordination
- `services/alarm_player.dart` - Audio playback for alarms
- `services/alarm_restore_service.dart` - Alarm restoration after restart
- `services/alarm_rollout.dart` - Gradual rollout configuration
- `services/alarm_scheduler.dart` - OS-level alarm scheduling
- `services/api_client.dart` - HTTP API client
- `services/bootstrap_service.dart` - Fast app initialization
- `services/deviation_detection.dart` - Off-route detection
- `services/deviation_monitor.dart` - Deviation monitoring
- `services/direction_service.dart` - Turn-by-turn directions
- `services/eta_utils.dart` - ETA utility functions
- `services/event_bus.dart` - Event publish-subscribe
- `services/heading_smoother.dart` - Heading smoothing
- `services/idle_power_scaler.dart` - Idle power optimization
- `services/log.dart` - Simple logging utility
- `services/metro_stop_service.dart` - Transit stop handling
- `services/movement_classifier.dart` - Walking/driving classification
- `services/navigation_service.dart` - Navigation coordination
- `services/notification_ids.dart` - Notification ID constants
- `services/notification_service.dart` - Push notifications
- `services/offline_coordinator.dart` - Online/offline coordination
- `services/pending_alarm_store.dart` - Pending alarm persistence
- `services/permission_service.dart` - Permission management
- `services/places_service.dart` - Location search
- `services/polyline_decoder.dart` - Polyline encoding/decoding
- `services/polyline_simplifier.dart` - Route simplification
- `services/reroute_policy.dart` - Rerouting logic
- `services/route_cache.dart` - Route caching
- `services/route_queue.dart` - Route fetch queue
- `services/route_registry.dart` - Multi-route management
- `services/sample_validator.dart` - GPS quality validation
- `services/secure_storage.dart` - Secure credential storage
- `services/sensor_fusion.dart` - Sensor data fusion
- `services/snap_to_route.dart` - Position snapping
- `services/ssl_pinning.dart` - SSL certificate pinning
- `services/test_tuning.dart` - Test mode acceleration
- `services/trackingservice.dart` - Core background tracking
- `services/transfer_utils.dart` - Route transfer utilities

### Services - ETA (2 files)
- `services/eta/eta_engine.dart` - Adaptive ETA calculation
- `services/eta/eta_models.dart` - ETA data models

### Services - Geometry (1 file)
- `services/geometry/segment_projection.dart` - Point-to-segment projection

### Services - Metrics (2 files)
- `services/metrics/app_metrics.dart` - Application metrics
- `services/metrics/metrics.dart` - Metrics infrastructure

### Services - Persistence (3 files)
- `services/persistence/persistence_manager.dart` - Persistence coordination
- `services/persistence/snapshot.dart` - State snapshots
- `services/persistence/tracking_session_state.dart` - Session state file

### Services - Refactor (4 files)
- `services/refactor/alarm_orchestrator_impl.dart` - New alarm implementation
- `services/refactor/interfaces.dart` - Service interfaces
- `services/refactor/location_types.dart` - Location type definitions
- `services/refactor/tracking_session_facade_stub.dart` - Facade stub

### Services - Simulation (3 files)
- `services/simulation/metro_route_scenario.dart` - Transit test scenarios
- `services/simulation/route_asset_loader.dart` - Test route loading
- `services/simulation/route_simulator.dart` - Route playback simulation

### Services - TrackingService Modules (5 files)
- `services/trackingservice/alarm.dart` - Legacy alarm logic
- `services/trackingservice/background_lifecycle.dart` - Background lifecycle
- `services/trackingservice/background_state.dart` - Background state
- `services/trackingservice/globals.dart` - Global tracking state
- `services/trackingservice/logging.dart` - Tracking-specific logging

### Themes (1 file)
- `themes/appthemes.dart` - Application themes

### Widgets (3 files)
- `widgets/device_harness_panel.dart` - Test harness UI widget
- `widgets/pulsing_dots.dart` - Animated loading indicator
- `widgets/route_progress_bar.dart` - Route progress visualization

---

## Annotated Documentation

All 85 source files have comprehensive annotated versions in `docs/annotated/` with:
- File-level purpose and overview
- Class documentation with usage examples
- Method documentation with parameters and return values
- Field documentation explaining purpose
- Implementation notes and design decisions

**Annotated File Structure**:
```
docs/annotated/
├── config/              # 4 files
├── debug/               # 2 files
├── logging/             # 1 file
├── main.annotated.dart  # 1 file
├── metrics/             # 1 file
├── models/              # 2 files
├── screens/             # 10 files
├── services/            # 42 files
│   ├── eta/             # 2 files
│   ├── geometry/        # 1 file
│   ├── metrics/         # 2 files
│   ├── persistence/     # 3 files
│   ├── refactor/        # 4 files
│   ├── simulation/      # 3 files
│   └── trackingservice/ # 5 files
├── themes/              # 1 file
└── widgets/             # 3 files
```

Each annotated file mirrors the structure of its source file with added comprehensive documentation.

---

## Summary

GeoWake is a sophisticated location-based alarm system with:

- **85 source files** organized into logical modules
- **Robust tracking** with battery-aware power policies
- **Intelligent alarms** supporting distance, time, and transit stop modes
- **Offline support** with route caching and recovery
- **State persistence** for seamless restoration after crashes
- **Comprehensive testing** with simulation and diagnostics tools
- **Complete documentation** with 85 annotated source files

The system is designed for reliability, efficiency, and maintainability, with clear separation of concerns and extensive test coverage.

For specific implementation details, refer to the annotated source files in `docs/annotated/`.

---

**Document Version**: 1.0  
**Last Updated**: 2025-10-19  
**Total Files Documented**: 85/85 (100%)
