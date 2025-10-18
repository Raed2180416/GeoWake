# GeoWake Quick Reference Guide

A fast-reference guide to the GeoWake codebase structure, key components, and common tasks.

---

## 📁 Directory Structure

```
lib/
├── config/              # Configuration and policies
│   ├── app_config.dart       # API server settings
│   └── power_policy.dart     # Battery-adaptive tracking settings
├── debug/               # Development and testing tools
│   ├── demo_tools.dart       # Simulate GPS journeys
│   └── dev_server.dart       # HTTP server for remote testing
├── models/              # Data structures
│   └── route_models.dart     # Route and transit switch models
├── screens/             # UI screens
│   ├── splash_screen.dart    # Initial loading screen
│   ├── homescreen.dart       # Destination selection and setup
│   ├── maptracking.dart      # Active tracking view
│   ├── alarm_fullscreen.dart # Full-screen alarm UI
│   ├── ringtones_screen.dart # Alarm sound selection
│   ├── settingsdrawer.dart   # Settings menu
│   └── otherimpservices/
│       ├── preload_map_screen.dart    # Offline map caching
│       └── recent_locations_service.dart  # Recent destinations
├── services/            # Core business logic (24 services)
│   ├── trackingservice.dart       # Main tracking orchestrator
│   ├── api_client.dart            # Secure server communication
│   ├── notification_service.dart  # Alarms and notifications
│   ├── alarm_player.dart          # Audio playback
│   ├── active_route_manager.dart  # Route switching logic
│   ├── deviation_monitor.dart     # Off-route detection
│   ├── reroute_policy.dart        # Reroute gating
│   ├── snap_to_route.dart         # Position projection
│   ├── sensor_fusion.dart         # GPS dropout handling
│   ├── route_registry.dart        # Route bookkeeping
│   ├── route_cache.dart           # Persistent route storage
│   ├── route_queue.dart           # Reroute request queue
│   ├── offline_coordinator.dart   # Cache-first routing
│   ├── direction_service.dart     # Route fetching
│   ├── places_service.dart        # Location autocomplete
│   ├── metro_stop_service.dart    # Transit station search
│   ├── permission_service.dart    # Runtime permissions
│   ├── navigation_service.dart    # Global navigation key
│   ├── polyline_decoder.dart      # Google polyline decoding
│   ├── polyline_simplifier.dart   # Route simplification
│   ├── transfer_utils.dart        # Transit transfer detection
│   ├── eta_utils.dart             # ETA calculations
│   └── (3 more services)
├── themes/              # UI theming
│   └── appthemes.dart        # Light and dark themes
├── widgets/             # Reusable widgets
│   └── pulsing_dots.dart     # Loading indicator
└── main.dart            # App entry point

docs/
├── annotated/           # Detailed code annotations (39 files)
│   ├── README.md             # Index of annotated files
│   ├── main.annotated.dart
│   ├── config/
│   ├── debug/
│   ├── models/
│   ├── screens/
│   ├── services/
│   ├── themes/
│   └── widgets/
├── COMPREHENSIVE_ANALYSIS.md  # Complete issue analysis
├── COMPLETION_SUMMARY.md      # Task summary
└── QUICK_REFERENCE.md         # This file
```

---

## 🔑 Key Components

### Core Service Trio

**TrackingService** (`lib/services/trackingservice.dart`)
- Orchestrates background location tracking
- Manages alarm triggering logic
- Coordinates sensor fusion during GPS dropout
- Handles route registration and switching

**NotificationService** (`lib/services/notification_service.dart`)
- Progress notifications during journey
- Full-screen alarm presentation
- Native activity launch for lock-screen alarms
- Vibration control

**ApiClient** (`lib/services/api_client.dart`)
- Secure communication with backend server
- Authentication and token management
- All Google Maps API calls proxied through server
- Test mode support for offline development

### Tracking Pipeline

```
GPS Update → ActiveRouteManager → SnapToRoute → DeviationMonitor → ReroutePolicy → TrackingService
                ↓                      ↓              ↓                  ↓
          Route Switching        Progress Calc    Sustained Check   Reroute Decision
```

### Route Management Flow

```
User Input → PlacesService → DirectionService → OfflineCoordinator → RouteCache
                                                        ↓
                                                  RouteRegistry ← ActiveRouteManager
                                                        ↓
                                                  TrackingService
```

---

## 🚀 Common Tasks

### Adding a New Service

1. Create file in `lib/services/my_service.dart`
2. Create annotated copy in `docs/annotated/services/my_service.annotated.dart`
3. Add to `docs/annotated/README.md`
4. Follow singleton pattern if stateful
5. Add test mode support if needed
6. Document in COMPREHENSIVE_ANALYSIS.md if it introduces new patterns

### Testing a Feature

**Unit Test:**
```dart
// test/services/my_service_test.dart
void main() {
  group('MyService', () {
    setUp(() {
      MyService.isTestMode = true; // Enable test mode
    });
    
    test('should do something', () {
      // Test code
    });
  });
}
```

**Integration Test:**
```dart
// integration_test/my_feature_test.dart
void main() {
  testWidgets('feature works end-to-end', (tester) async {
    await tester.pumpWidget(MyApp());
    // Test code
  });
}
```

**Demo Mode Test:**
```bash
# Start dev server
flutter run

# From another terminal:
curl http://localhost:8765/demo/journey
curl http://localhost:8765/demo/destination
```

### Debugging Tracking Issues

1. **Check logs:**
   ```dart
   dev.log('Message', name: 'ComponentName');
   ```

2. **Enable verbose mode:**
   - Set breakpoints in `trackingservice.dart` `_onStart()`
   - Check `_positionSubscription` stream
   - Verify GPS permissions

3. **Common issues:**
   - GPS permission not granted
   - Route not registered before tracking starts
   - Alarm thresholds not met
   - Notification permission denied

### Adding a New Screen

1. Create `lib/screens/my_screen.dart`
2. Add route in `main.dart` `onGenerateRoute`
3. Create annotated copy
4. Add to navigation flow
5. Update COMPREHENSIVE_ANALYSIS.md if introduces new patterns

---

## 📊 Critical Thresholds

### Power Policy (Battery-based)
- **>50%**: High accuracy, 20m filter, 25s dropout, 1s notifications
- **20-50%**: Medium accuracy, 35m filter, 30s dropout, 2s notifications
- **<20%**: Low accuracy, 50m filter, 40s dropout, 3s notifications

### Deviation Detection
- **High threshold**: `15 + 1.5 * speed_m/s` meters
- **Low threshold**: `70% of high threshold` meters
- **Sustain duration**: 5 seconds

### Route Switching
- **Switch margin**: 50 meters (candidate must be this much better)
- **Sustain window**: 6 seconds (candidate must stay better)
- **Post-switch blackout**: 5 seconds (prevent oscillation)

### Cache and Registry
- **Route cache**: Memory + disk (SQLite)
- **Registry capacity**: 8 routes (LRU eviction)
- **Cache expiration**: Not enforced (known issue #2.3)

### Reroute Policy
- **Cooldown**: 20 seconds default (power policy adjusts)
- **Online requirement**: Must have connectivity
- **Sustain requirement**: Deviation must be sustained

---

## 🔍 Finding Information

### "Where is X implemented?"

| What | Where |
|------|-------|
| GPS tracking | `lib/services/trackingservice.dart` |
| Alarm triggering | `lib/services/trackingservice.dart` (lines 400+) |
| Position snapping | `lib/services/snap_to_route.dart` |
| Route switching | `lib/services/active_route_manager.dart` |
| Deviation detection | `lib/services/deviation_monitor.dart` |
| Reroute logic | `lib/services/reroute_policy.dart` |
| Sensor fusion | `lib/services/sensor_fusion.dart` |
| Route fetching | `lib/services/direction_service.dart` |
| Route caching | `lib/services/route_cache.dart` |
| Notifications | `lib/services/notification_service.dart` |
| Alarm audio | `lib/services/alarm_player.dart` |
| API calls | `lib/services/api_client.dart` |
| Home screen | `lib/screens/homescreen.dart` |
| Tracking screen | `lib/screens/maptracking.dart` |
| Settings | `lib/screens/settingsdrawer.dart` |
| App init | `lib/main.dart` |
| Themes | `lib/themes/appthemes.dart` |

### "How does Y work?"

**Detailed Explanation:** Check `docs/annotated/[component].annotated.dart`
**Issue Analysis:** Check `docs/COMPREHENSIVE_ANALYSIS.md` Section 2-7
**High-Level Overview:** Check `docs/COMPLETION_SUMMARY.md` Section 5

---

## 🐛 Known Issues Quick Reference

### Critical (Fix Immediately)
1. **GPS dropout timing** - Uses wall-clock, should use monotonic clock
2. **Route registration race** - May register after tracking starts
3. **Alarm duplicate firing** - Transit switches use indices instead of locations

### High Priority
4. **Power policy not dynamic** - Set once, doesn't adapt during journey
5. **Cache expiration not enforced** - Stale routes may be used
6. **Deviation ignores GPS accuracy** - False positives in low-accuracy scenarios

### Medium Priority
7. **Snap window may miss turns** - Fixed 20-segment window
8. **Route registry may evict active** - LRU doesn't protect active route
9. **Sensor fusion causes jumps** - Abrupt reset after 10s

### Security
10. **Token not encrypted** - Uses plain SharedPreferences
11. **No certificate pinning** - MITM vulnerability
12. **Dev server on all interfaces** - Network attack surface

See `docs/COMPREHENSIVE_ANALYSIS.md` for complete details.

---

## 📖 Reading Order for New Developers

### Day 1: Foundation
1. `docs/COMPLETION_SUMMARY.md` - Understand what's been done
2. `docs/annotated/README.md` - See documentation structure
3. `docs/annotated/main.annotated.dart` - App initialization flow
4. `docs/annotated/config/app_config.annotated.dart` - Configuration basics

### Day 2: Core Services
5. `docs/annotated/services/trackingservice.annotated.dart` - Main tracking logic
6. `docs/annotated/services/api_client.annotated.dart` - Server communication
7. `docs/annotated/services/notification_service.annotated.dart` - Alarms
8. `docs/annotated/models/route_models.annotated.dart` - Data structures

### Day 3: Tracking Pipeline
9. `docs/annotated/services/active_route_manager.annotated.dart` - Route switching
10. `docs/annotated/services/snap_to_route.annotated.dart` - Position projection
11. `docs/annotated/services/deviation_monitor.annotated.dart` - Off-route detection
12. `docs/annotated/services/reroute_policy.annotated.dart` - Reroute gating

### Day 4: UI Layer
13. `docs/annotated/screens/homescreen.annotated.dart` - Destination selection
14. `docs/annotated/screens/maptracking.annotated.dart` - Tracking UI
15. `docs/annotated/screens/alarm_fullscreen.annotated.dart` - Alarm screen

### Day 5: Analysis and Planning
16. `docs/COMPREHENSIVE_ANALYSIS.md` Sections 1-4 - Critical issues and bugs
17. `docs/COMPREHENSIVE_ANALYSIS.md` Sections 5-7 - Architecture and testing
18. `docs/COMPREHENSIVE_ANALYSIS.md` Section 8 - Roadmap

---

## 🛠️ Development Commands

### Running the App
```bash
flutter run                    # Normal mode
flutter run --debug           # With debugger
flutter run --profile         # Performance profiling
flutter run --release         # Release build
```

### Testing
```bash
flutter test                              # All unit tests
flutter test test/services/              # Specific directory
flutter test integration_test/           # Integration tests
flutter drive --target=test_driver/app.dart  # Driver tests
```

### Code Quality
```bash
flutter analyze                # Static analysis
dart format lib/ test/         # Format code
flutter pub outdated           # Check dependencies
```

### Building
```bash
flutter build apk              # Android APK
flutter build appbundle        # Android App Bundle
flutter build ios              # iOS build
flutter build web              # Web build
```

---

## 🔐 Security Checklist

Before deploying to production:

- [ ] API token stored in FlutterSecureStorage (not SharedPreferences)
- [ ] Certificate pinning enabled for API client
- [ ] Dev server disabled in release builds
- [ ] Location data transmission has user consent
- [ ] Notification payloads sanitized for lock screen
- [ ] Input validation on all user inputs
- [ ] Rate limiting on public endpoints
- [ ] Privacy policy acceptance implemented

See `docs/COMPREHENSIVE_ANALYSIS.md` Section 4 for details.

---

## 📈 Metrics and Monitoring

### Key Metrics to Track

**User Experience:**
- Time from app open to tracking start
- Alarm accuracy (distance from target when fired)
- False positive alarm rate
- GPS lock time

**Performance:**
- GPS update processing latency
- Route snapping time
- Battery consumption per hour
- Memory usage during tracking

**Reliability:**
- GPS dropout frequency and duration
- Sensor fusion activation rate
- Reroute success rate
- Crash rate

**System Health:**
- API response times
- Cache hit rate
- Token refresh frequency
- Background service uptime

---

## 🎯 Quick Wins (Easy Improvements)

1. **Add cache expiration** (6 hours) - Section 2.3
2. **Fix Hive box opening** (2 hours) - Section 3.3  
3. **Add input validation** (2 hours) - Section 4.6
4. **Extract magic numbers** (4 hours) - Section 7.3
5. **Add dartdoc comments** (8 hours) - Section 7.4

Total: ~22 hours for significant improvements

---

## 📞 Support and Resources

**Documentation:**
- Full annotations: `docs/annotated/`
- Issue analysis: `docs/COMPREHENSIVE_ANALYSIS.md`
- Task summary: `docs/COMPLETION_SUMMARY.md`
- This guide: `docs/QUICK_REFERENCE.md`

**External Resources:**
- Flutter docs: https://flutter.dev/docs
- Geolocator plugin: https://pub.dev/packages/geolocator
- Google Maps Flutter: https://pub.dev/packages/google_maps_flutter
- Background service: https://pub.dev/packages/flutter_background_service

**Code Patterns:**
- Singleton: Most services use this pattern
- Stream-based: Event propagation between services
- Test mode: Global flags for unit testing
- Annotation: Extreme detail in docs/annotated/

---

*Last Updated: 2025-10-18*
*Documentation Version: 1.0*
*Codebase: 39 files, ~7,000 annotated lines*
