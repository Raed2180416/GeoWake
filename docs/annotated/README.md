# GeoWake Annotated Code Index

This index links to the fully annotated, line-by-line walkthrough files. These live under `docs/annotated/` and do not affect runtime. Each file includes:
- **Line-by-line explanations** for every single line of code
- **Block summaries** explaining how code sections tie to the overall file
- **End-of-file summaries** showing how each file connects to the entire project
- **Technical rationale** for design decisions and code choices
- **Potential issues** and future enhancement opportunities

## Application Entry Point
- `docs/annotated/main.annotated.dart` - App initialization, lifecycle management, theme control, service orchestration

## Metrics
- `docs/annotated/metrics/metrics_registry.annotated.dart` - In-memory metrics collection (counters, gauges, histograms)

## Models
- `docs/annotated/models/pending_alarm.annotated.dart` - Pending alarm data model
- `docs/annotated/models/route_models.annotated.dart` - Core data structures for routes and transit switches

## Configuration
- `docs/annotated/config/alarm_thresholds.annotated.dart` - Alarm and routing threshold constants
- `docs/annotated/config/app_config.annotated.dart` - Application configuration and server settings
- `docs/annotated/config/feature_flags.annotated.dart` - Feature toggle flags
- `docs/annotated/config/power_policy.annotated.dart` - Battery optimization and tracking power policies

## Logging
- `docs/annotated/logging/app_logger.annotated.dart` - Structured logging infrastructure

## Screens
- `docs/annotated/screens/alarm_fullscreen.annotated.dart` - Full-screen alarm display
- `docs/annotated/screens/dev_route_sim_screen.annotated.dart` - Route simulation screen
- `docs/annotated/screens/diagnostics_screen.annotated.dart` - Diagnostics and testing UI
- `docs/annotated/screens/homescreen.annotated.dart` - Main route creation and management UI
- `docs/annotated/screens/maptracking.annotated.dart` - Active tracking screen with map visualization
- `docs/annotated/screens/otherimpservices/preload_map_screen.annotated.dart` - Offline map tile downloading
- `docs/annotated/screens/otherimpservices/recent_locations_service.annotated.dart` - Recent locations persistence
- `docs/annotated/screens/ringtones_screen.annotated.dart` - Alarm sound selection
- `docs/annotated/screens/settingsdrawer.annotated.dart` - Settings and configuration UI
- `docs/annotated/screens/splash_screen.annotated.dart` - Initial loading screen

## Services (Core Business Logic)
- `docs/annotated/services/active_route_manager.annotated.dart` - Active route state management
- `docs/annotated/services/alarm_deduplicator.annotated.dart` - Alarm duplicate prevention
- `docs/annotated/services/alarm_orchestrator.annotated.dart` - High-level alarm coordination
- `docs/annotated/services/alarm_player.annotated.dart` - Audio playback for alarms
- `docs/annotated/services/alarm_restore_service.annotated.dart` - Alarm restoration after restart
- `docs/annotated/services/alarm_rollout.annotated.dart` - Gradual rollout configuration
- `docs/annotated/services/alarm_scheduler.annotated.dart` - OS-level alarm scheduling
- `docs/annotated/services/api_client.annotated.dart` - Secure API communication with backend
- `docs/annotated/services/bootstrap_service.annotated.dart` - Fast app initialization
- `docs/annotated/services/deviation_detection.annotated.dart` - Off-route detection algorithms
- `docs/annotated/services/deviation_monitor.annotated.dart` - Continuous deviation monitoring
- `docs/annotated/services/direction_service.annotated.dart` - Google Directions API integration
- `docs/annotated/services/eta_utils.annotated.dart` - ETA calculation and updates
- `docs/annotated/services/event_bus.annotated.dart` - Event publish-subscribe system
- `docs/annotated/services/heading_smoother.annotated.dart` - GPS heading smoothing
- `docs/annotated/services/idle_power_scaler.annotated.dart` - Idle power optimization
- `docs/annotated/services/log.annotated.dart` - Simple logging utility
- `docs/annotated/services/metro_stop_service.annotated.dart` - Transit transfer alarm handling
- `docs/annotated/services/movement_classifier.annotated.dart` - Walking/driving classification
- `docs/annotated/services/navigation_service.annotated.dart` - Global navigation helpers
- `docs/annotated/services/notification_ids.annotated.dart` - Notification ID constants
- `docs/annotated/services/notification_service.annotated.dart` - Notification and alarm display
- `docs/annotated/services/offline_coordinator.annotated.dart` - Offline mode management
- `docs/annotated/services/pending_alarm_store.annotated.dart` - Pending alarm persistence
- `docs/annotated/services/permission_service.annotated.dart` - Runtime permission handling
- `docs/annotated/services/places_service.annotated.dart` - Google Places API integration
- `docs/annotated/services/polyline_decoder.annotated.dart` - Polyline encoding/decoding
- `docs/annotated/services/polyline_simplifier.annotated.dart` - Route simplification algorithms
- `docs/annotated/services/reroute_policy.annotated.dart` - Route update decision logic
- `docs/annotated/services/route_cache.annotated.dart` - Route caching with TTL and origin validation
- `docs/annotated/services/route_queue.annotated.dart` - Route request queuing and deduplication
- `docs/annotated/services/route_registry.annotated.dart` - Route storage and retrieval
- `docs/annotated/services/sample_validator.annotated.dart` - GPS quality validation
- `docs/annotated/services/secure_storage.annotated.dart` - Secure credential storage
- `docs/annotated/services/sensor_fusion.annotated.dart` - GPS and motion sensor data fusion
- `docs/annotated/services/snap_to_route.annotated.dart` - Position snapping to route polyline
- `docs/annotated/services/ssl_pinning.annotated.dart` - SSL certificate pinning
- `docs/annotated/services/test_tuning.annotated.dart` - Test mode acceleration
- `docs/annotated/services/trackingservice.annotated.dart` - Background location tracking and alarm monitoring
- `docs/annotated/services/transfer_utils.annotated.dart` - Transit transfer utilities

### Services - ETA
- `docs/annotated/services/eta/eta_engine.annotated.dart` - Adaptive ETA calculation engine
- `docs/annotated/services/eta/eta_models.annotated.dart` - ETA data models

### Services - Geometry
- `docs/annotated/services/geometry/segment_projection.annotated.dart` - Point-to-segment projection

### Services - Metrics
- `docs/annotated/services/metrics/app_metrics.annotated.dart` - Application-level metrics
- `docs/annotated/services/metrics/metrics.annotated.dart` - Metrics infrastructure

### Services - Persistence
- `docs/annotated/services/persistence/persistence_manager.annotated.dart` - Persistence coordination
- `docs/annotated/services/persistence/snapshot.annotated.dart` - State snapshots
- `docs/annotated/services/persistence/tracking_session_state.annotated.dart` - Session state file

### Services - Refactor
- `docs/annotated/services/refactor/alarm_orchestrator_impl.annotated.dart` - New alarm implementation
- `docs/annotated/services/refactor/interfaces.annotated.dart` - Service interfaces
- `docs/annotated/services/refactor/location_types.annotated.dart` - Location type definitions
- `docs/annotated/services/refactor/tracking_session_facade_stub.annotated.dart` - Facade stub

### Services - Simulation
- `docs/annotated/services/simulation/metro_route_scenario.annotated.dart` - Transit test scenarios
- `docs/annotated/services/simulation/route_asset_loader.annotated.dart` - Test route loading
- `docs/annotated/services/simulation/route_simulator.annotated.dart` - Route playback simulation

### Services - TrackingService Modules
- `docs/annotated/services/trackingservice/alarm.annotated.dart` - Legacy alarm logic
- `docs/annotated/services/trackingservice/background_lifecycle.annotated.dart` - Background lifecycle
- `docs/annotated/services/trackingservice/background_state.annotated.dart` - Background state
- `docs/annotated/services/trackingservice/globals.annotated.dart` - Global tracking state
- `docs/annotated/services/trackingservice/logging.annotated.dart` - Tracking-specific logging

## Debug Tools (Development Only)
- `docs/annotated/debug/dev_server.annotated.dart` - HTTP server for remote demo triggering
- `docs/annotated/debug/demo_tools.annotated.dart` - GPS journey simulation for testing

## Themes
- `docs/annotated/themes/appthemes.annotated.dart` - Light and dark theme definitions

## Widgets (Reusable UI Components)
- `docs/annotated/widgets/device_harness_panel.annotated.dart` - Test harness UI widget
- `docs/annotated/widgets/pulsing_dots.annotated.dart` - Animated loading indicator
- `docs/annotated/widgets/route_progress_bar.annotated.dart` - Route progress visualization

## Test Infrastructure
- `docs/annotated/tests/flutter_test_config.annotated.dart` - Global test setup and Hive initialization
- `docs/annotated/tests/log_helper.annotated.dart` - Structured logging utilities for tests
- `docs/annotated/tests/route_cache_integration_test.annotated.dart` - Route cache integration tests

## Issues Tracking
- `docs/annotated/ISSUES.txt` - Comprehensive list of identified issues, technical debt, and enhancement opportunities

## Statistics

**Total Annotated Files:** 88 (100% Coverage ✅)
- Application Core: 1 file (main.dart)
- Models: 2 files
- Configuration: 4 files
- Screens: 10 files
- Services: 62 files (including subdirectories)
  - Core Services: 40 files
  - ETA: 2 files
  - Geometry: 1 file
  - Metrics: 3 files (including metrics_registry)
  - Persistence: 3 files
  - Refactor: 4 files
  - Simulation: 3 files
  - TrackingService modules: 5 files
- Debug Tools: 2 files
- Logging: 1 file
- Themes: 1 file
- Widgets: 3 files
- Test Infrastructure: 3 files

**Documentation Coverage:** 85/85 lib files + 3 test files = 100% complete

**Annotation Quality:**
- Comprehensive file-level documentation
- Class and interface documentation with purpose and usage
- Method documentation with parameters and return values
- Field documentation explaining purpose
- Implementation notes and design decisions
- Cross-references to related components

**Additional Documentation:**
- [SYSTEM_INTEGRATION_GUIDE.md](../SYSTEM_INTEGRATION_GUIDE.md) - Comprehensive system architecture and integration guide (930+ lines)

## How to Use This Documentation

1. **Understanding a Feature:** Start with the relevant screen file (e.g., `maptracking.annotated.dart` for active tracking)
2. **Debugging Issues:** Check `ISSUES.txt` for known issues, then examine relevant service files
3. **Learning the Architecture:** Read `main.annotated.dart` first to understand app structure, then explore referenced files
4. **Contributing:** Review annotations to understand code patterns and design decisions before making changes
5. **Onboarding:** New developers should read files in this order:
   - main.annotated.dart (app structure)
   - route_models.annotated.dart (core data)
   - trackingservice.annotated.dart (core functionality)
   - Relevant screen files for UI
   - Service files for specific features

## File Relationships

```
main.dart (Entry Point)
├── Initializes Services
│   ├── api_client.dart (Secure API access)
│   ├── notification_service.dart (Alarms)
│   └── trackingservice.dart (Background monitoring)
├── Provides Theme
│   └── appthemes.dart (Light/Dark themes)
└── Routes to Screens
    ├── splash_screen.dart (Loading)
    ├── homescreen.dart (Route creation)
    │   ├── Uses direction_service.dart
    │   ├── Uses route_cache.dart
    │   └── Uses route_registry.dart
    └── maptracking.dart (Active tracking)
        ├── Uses trackingservice.dart
        ├── Uses eta_utils.dart
        ├── Uses snap_to_route.dart
        └── Uses deviation_monitor.dart
```

If you spot a missing module or want a deeper dive in a particular area, open the corresponding file in this folder. Each file includes per-line notes, block summaries, and an end-of-file overview explaining how it fits into the larger system.
