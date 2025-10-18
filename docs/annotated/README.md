# GeoWake Annotated Code Index

This index links to the fully annotated, line-by-line walkthrough files. These live under `docs/annotated/` and do not affect runtime. Each file includes:
- **Line-by-line explanations** for every single line of code
- **Block summaries** explaining how code sections tie to the overall file
- **End-of-file summaries** showing how each file connects to the entire project
- **Technical rationale** for design decisions and code choices
- **Potential issues** and future enhancement opportunities

## Application Entry Point
- `docs/annotated/main.annotated.dart` - App initialization, lifecycle management, theme control, service orchestration

## Models
- `docs/annotated/models/route_models.annotated.dart` - Core data structures for routes and transit switches

## Configuration
- `docs/annotated/config/app_config.annotated.dart` - Application configuration and server settings
- `docs/annotated/config/power_policy.annotated.dart` - Battery optimization and tracking power policies

## Screens
- `docs/annotated/screens/splash_screen.annotated.dart` - Initial loading screen
- `docs/annotated/screens/homescreen.annotated.dart` - Main route creation and management UI
- `docs/annotated/screens/maptracking.annotated.dart` - Active tracking screen with map visualization
- `docs/annotated/screens/settingsdrawer.annotated.dart` - Settings and configuration UI
- `docs/annotated/screens/ringtones_screen.annotated.dart` - Alarm sound selection
- `docs/annotated/screens/alarm_fullscreen.annotated.dart` - Full-screen alarm display
- `docs/annotated/screens/otherimpservices/preload_map_screen.annotated.dart` - Offline map tile downloading
- `docs/annotated/screens/otherimpservices/recent_locations_service.annotated.dart` - Recent locations persistence

## Services (Core Business Logic)
- `docs/annotated/services/active_route_manager.annotated.dart` - Active route state management
- `docs/annotated/services/alarm_player.annotated.dart` - Audio playback for alarms
- `docs/annotated/services/api_client.annotated.dart` - Secure API communication with backend
- `docs/annotated/services/deviation_detection.annotated.dart` - Off-route detection algorithms
- `docs/annotated/services/deviation_monitor.annotated.dart` - Continuous deviation monitoring
- `docs/annotated/services/direction_service.annotated.dart` - Google Directions API integration
- `docs/annotated/services/eta_utils.annotated.dart` - ETA calculation and updates
- `docs/annotated/services/metro_stop_service.annotated.dart` - Transit transfer alarm handling
- `docs/annotated/services/navigation_service.annotated.dart` - Global navigation helpers
- `docs/annotated/services/notification_service.annotated.dart` - Notification and alarm display
- `docs/annotated/services/offline_coordinator.annotated.dart` - Offline mode management
- `docs/annotated/services/permission_service.annotated.dart` - Runtime permission handling
- `docs/annotated/services/places_service.annotated.dart` - Google Places API integration
- `docs/annotated/services/polyline_decoder.annotated.dart` - Polyline encoding/decoding
- `docs/annotated/services/polyline_simplifier.annotated.dart` - Route simplification algorithms
- `docs/annotated/services/reroute_policy.annotated.dart` - Route update decision logic
- `docs/annotated/services/route_cache.annotated.dart` - Route caching with TTL and origin validation
- `docs/annotated/services/route_queue.annotated.dart` - Route request queuing and deduplication
- `docs/annotated/services/route_registry.annotated.dart` - Route storage and retrieval
- `docs/annotated/services/sensor_fusion.annotated.dart` - GPS and motion sensor data fusion
- `docs/annotated/services/snap_to_route.annotated.dart` - Position snapping to route polyline
- `docs/annotated/services/trackingservice.annotated.dart` - Background location tracking and alarm monitoring
- `docs/annotated/services/transfer_utils.annotated.dart` - Transit transfer utilities

## Debug Tools (Development Only)
- `docs/annotated/debug/dev_server.annotated.dart` - HTTP server for remote demo triggering
- `docs/annotated/debug/demo_tools.annotated.dart` - GPS journey simulation for testing

## Themes
- `docs/annotated/themes/appthemes.annotated.dart` - Light and dark theme definitions

## Widgets (Reusable UI Components)
- `docs/annotated/widgets/pulsing_dots.annotated.dart` - Animated loading indicator

## Test Infrastructure
- `docs/annotated/tests/flutter_test_config.annotated.dart` - Global test setup and Hive initialization
- `docs/annotated/tests/log_helper.annotated.dart` - Structured logging utilities for tests

## Issues Tracking
- `docs/annotated/ISSUES.txt` - Comprehensive list of identified issues, technical debt, and enhancement opportunities

## Statistics

**Total Annotated Files:** 50+
- Application Core: 1 file (main.dart)
- Models: 1 file
- Configuration: 2 files
- Screens: 8 files
- Services: 23 files
- Debug Tools: 2 files
- Themes: 1 file
- Widgets: 1 file
- Test Infrastructure: 2 files
- Issues Tracking: 1 file

**Annotation Quality:**
- Line-by-line explanations for every single line
- Block summaries for code sections
- File summaries showing project connections
- Technical rationale and design decisions documented
- Potential issues and enhancements identified

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
