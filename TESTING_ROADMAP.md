# Testing Roadmap - Detailed Implementation Plan

**Project**: GeoWake  
**Target**: 80%+ Test Coverage  
**Timeline**: 5 weeks (1 developer) or 3 weeks (2 developers)  
**Current Coverage**: 30%

---

## 🗺️ Roadmap Overview

```
Week 1: Critical Tests (Permission, Error Recovery)
Week 2: UI Tests (All Screens)
Week 3: Integration Tests (User Journeys)
Week 4: Platform & Performance Tests
Week 5: Polish & Documentation
```

---

## Week 1: Critical Tests (Must Do)

### Day 1-2: Permission Flow Tests

**File**: `test/permission_service_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:geowake2/services/permission_service.dart';

void main() {
  group('PermissionService', () {
    test('requests location permission successfully', () async {
      // TODO: Test location permission flow
    });

    test('handles location permission denial', () async {
      // TODO: Test denial scenario
    });

    test('requests background location after foreground', () async {
      // TODO: Test always allow flow
    });

    test('shows rationale dialog before permission request', () async {
      // TODO: Test rationale dialog
    });

    test('opens settings when permanently denied', () async {
      // TODO: Test settings navigation
    });

    test('requests notification permission on Android', () async {
      // TODO: Test notification permission
    });

    test('handles full permission flow successfully', () async {
      // TODO: Test complete flow
    });
  });
}
```

**Test Scenarios**:
- ✅ Location permission granted
- ✅ Location permission denied
- ✅ Location permission permanently denied
- ✅ Background location granted
- ✅ Background location denied
- ✅ Notification permission granted
- ✅ Notification permission denied
- ✅ Settings navigation works
- ✅ Retry after denial works
- ✅ Complete flow succeeds

**Expected Outcomes**:
- 10+ tests added
- Permission flow validated
- Error handling verified
- User experience tested

### Day 3-5: Error Recovery Tests

**Files to Create**:
1. `test/error_recovery/gps_loss_test.dart`
2. `test/error_recovery/network_failure_test.dart`
3. `test/error_recovery/storage_error_test.dart`
4. `test/error_recovery/service_crash_test.dart`

**Example**: `test/error_recovery/gps_loss_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:geowake2/services/trackingservice.dart';

void main() {
  group('GPS Loss Recovery', () {
    test('continues tracking when GPS signal lost', () async {
      // TODO: Simulate GPS signal loss
      // Verify: Service continues with last known position
      // Verify: Warning shown to user
      // Verify: Sensor fusion activated if available
    });

    test('resumes normal tracking when GPS returns', () async {
      // TODO: Simulate GPS return
      // Verify: Normal tracking resumes
      // Verify: Warning cleared
      // Verify: Sensor fusion deactivated
    });

    test('handles extended GPS loss (>5 minutes)', () async {
      // TODO: Simulate long GPS loss
      // Verify: Tracking continues with degraded accuracy
      // Verify: User notified of degraded tracking
      // Verify: ETA marked as uncertain
    });

    test('stops tracking if GPS lost at start', () async {
      // TODO: Simulate GPS loss immediately
      // Verify: Tracking doesn't start
      // Verify: User shown error message
      // Verify: Retry option provided
    });
  });
}
```

**Test Scenarios**:

**GPS Loss**:
- ✅ Signal loss during tracking
- ✅ Signal return after loss
- ✅ Extended loss (>5 min)
- ✅ Loss at tracking start
- ✅ Intermittent loss (tunnel)

**Network Failure**:
- ✅ Network loss during route fetch
- ✅ Network loss during tracking
- ✅ Network return after loss
- ✅ Offline mode activation
- ✅ Route cache fallback

**Storage Errors**:
- ✅ Disk full during save
- ✅ Permission denied for storage
- ✅ Corrupted data recovery
- ✅ Read failure handling
- ✅ Write failure handling

**Service Crash**:
- ✅ Background service killed
- ✅ App killed by OS
- ✅ State restoration on restart
- ✅ Alarm persistence
- ✅ Clean shutdown handling

**Expected Outcomes**:
- 20+ tests added
- Error recovery validated
- Graceful degradation tested
- User notifications verified

---

## Week 2: UI Tests (Should Do)

### Day 6-7: Remaining Screen Tests

**Files to Create**:
1. `test/screens/maptracking_test.dart` - Active tracking screen
2. `test/screens/alarm_fullscreen_test.dart` - Alarm dismissal
3. `test/screens/settingsdrawer_test.dart` - Settings
4. `test/screens/ringtones_screen_test.dart` - Ringtone selection
5. `test/screens/splash_screen_test.dart` - Splash screen

**Example**: `test/screens/alarm_fullscreen_test.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geowake2/screens/alarm_fullscreen.dart';

void main() {
  testWidgets('AlarmFullScreen displays alarm information', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AlarmFullScreen(
          destinationName: 'Test Destination',
          arrivalMessage: 'You are arriving soon',
        ),
      ),
    );

    expect(find.text('Test Destination'), findsOneWidget);
    expect(find.text('You are arriving soon'), findsOneWidget);
  });

  testWidgets('AlarmFullScreen has dismiss button', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AlarmFullScreen(
          destinationName: 'Test',
          arrivalMessage: 'Test',
        ),
      ),
    );

    expect(find.byType(ElevatedButton), findsAtLeastNWidgets(1));
  });

  testWidgets('AlarmFullScreen dismiss button stops alarm', (tester) async {
    bool dismissed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: AlarmFullScreen(
          destinationName: 'Test',
          arrivalMessage: 'Test',
          onDismiss: () => dismissed = true,
        ),
      ),
    );

    await tester.tap(find.byType(ElevatedButton).first);
    await tester.pumpAndSettle();

    expect(dismissed, isTrue);
  });

  testWidgets('AlarmFullScreen shows time and distance', (tester) async {
    // TODO: Test that time and distance are displayed
  });

  testWidgets('AlarmFullScreen vibrates on display', (tester) async {
    // TODO: Test vibration trigger
  });

  testWidgets('AlarmFullScreen plays sound on display', (tester) async {
    // TODO: Test sound trigger
  });
}
```

**Test Coverage for Each Screen**:
- ✅ Screen renders without crashing
- ✅ Required widgets present
- ✅ User interactions work
- ✅ State updates correctly
- ✅ Navigation works
- ✅ Error states displayed
- ✅ Loading states shown
- ✅ Edge cases handled

**Expected Outcomes**:
- 40+ tests added (5-8 per screen)
- All screens smoke tested
- Critical user paths verified
- UI crashes caught

### Day 8-9: Widget Tests

**Files to Create**:
1. `test/widgets/offline_indicator_test.dart`
2. `test/widgets/pulsing_dots_test.dart`

**Example**: `test/widgets/offline_indicator_test.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geowake2/widgets/offline_indicator.dart';

void main() {
  testWidgets('OfflineIndicator shows when offline', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: OfflineIndicator(isOffline: true),
        ),
      ),
    );

    expect(find.byType(OfflineIndicator), findsOneWidget);
    // Should display offline message/icon
  });

  testWidgets('OfflineIndicator hidden when online', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: OfflineIndicator(isOffline: false),
        ),
      ),
    );

    // Should not display or be invisible
  });

  testWidgets('OfflineIndicator animates transition', (tester) async {
    // TODO: Test animation between states
  });
}
```

### Day 10: Integration with Navigation

**File**: `test/navigation_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:geowake2/main.dart';

void main() {
  testWidgets('App navigates from home to tracking', (tester) async {
    await tester.pumpWidget(MyApp());
    
    // TODO: Simulate user journey:
    // 1. Start at home screen
    // 2. Set destination
    // 3. Configure alarm
    // 4. Start tracking
    // 5. Verify MapTracking screen shown
  });

  testWidgets('App navigates to settings drawer', (tester) async {
    // TODO: Test settings navigation
  });

  testWidgets('App navigates to ringtone selection', (tester) async {
    // TODO: Test ringtone selection navigation
  });
}
```

---

## Week 3: Integration Tests (Should Do)

### Day 11-13: Real-World Journey Tests

**Files to Create**:
1. `test/journeys/morning_commute_test.dart` - Bus journey
2. `test/journeys/evening_drive_test.dart` - Car with reroute
3. `test/journeys/offline_journey_test.dart` - No network
4. `test/journeys/low_battery_test.dart` - Battery optimization

**Example**: `test/journeys/morning_commute_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geowake2/services/trackingservice.dart';

void main() {
  group('Morning Commute - Bus Journey', () {
    test('completes full bus journey with stop-based alarm', () async {
      // GIVEN: User wants to take bus to work
      final home = const LatLng(12.9716, 77.5946);
      final work = const LatLng(12.9950, 77.6200);
      
      // Route has 12 stops total
      final busRoute = _generateBusRoute(home, work, stops: 12);
      
      // User sets alarm for 2 stops before destination (stop 10)
      // WHEN: Tracking starts
      final tracking = TrackingService();
      await tracking.startTracking(
        destination: work,
        destinationName: 'Work',
        alarmMode: 'stops',
        alarmValue: 2.0,
      );

      // Simulate journey
      for (int i = 0; i < busRoute.length; i++) {
        // Feed position updates
        await _injectPosition(busRoute[i]);
        
        // At stops, simulate stationary period
        if (_isAtStop(i)) {
          await _simulateStop(duration: Duration(seconds: 30));
        }
        
        await Future.delayed(Duration(milliseconds: 500));
      }

      // THEN: Alarm should have triggered at stop 10
      expect(tracking.alarmTriggered, isTrue);
      expect(tracking.stopCountAtAlarm, 10);
      
      // Verify: Alarm triggered before final stop
      expect(tracking.stopCountAtAlarm, lessThan(12));
      
      // Verify: Single-fire (alarm not repeated)
      expect(tracking.alarmTriggerCount, 1);
      
      await tracking.stopTracking();
    });

    test('handles bus stopped at red light (not counted as stop)', () async {
      // TODO: Test that traffic stops are not counted as metro stops
    });

    test('handles GPS drift at bus stops', () async {
      // TODO: Test that GPS inaccuracy doesn't miscount stops
    });

    test('handles missed stop (bus doesn't stop)', () async {
      // TODO: Test alarm still triggers based on distance/time
    });
  });
}
```

**Test Scenarios**:

**Morning Commute (Bus)**:
- ✅ Full journey with stops
- ✅ Alarm triggers at correct stop
- ✅ Traffic stops not counted
- ✅ GPS drift handled
- ✅ Missed stop handled
- ✅ Early arrival handled
- ✅ Delayed arrival handled

**Evening Drive (Car)**:
- ✅ Full journey with traffic
- ✅ Alarm triggers at correct distance
- ✅ Deviation detected
- ✅ Reroute triggered
- ✅ New route cached
- ✅ Alarm recalculated
- ✅ Final approach handled

**Offline Journey**:
- ✅ Route pre-cached
- ✅ Offline mode activated
- ✅ GPS continues working
- ✅ ETA estimated from cache
- ✅ Alarm triggers correctly
- ✅ Online mode resumed

**Low Battery Journey**:
- ✅ GPS interval reduced
- ✅ Accuracy degraded gracefully
- ✅ Warning shown at 10%
- ✅ Alarm still functional
- ✅ Tracking completes

**Expected Outcomes**:
- 15+ journey tests added
- End-to-end flows validated
- Real-world scenarios tested
- Integration issues found

### Day 14-15: Multi-Component Integration

**File**: `test/integration/component_integration_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Component Integration', () {
    test('TrackingService + AlarmOrchestrator integration', () async {
      // TODO: Test that position updates flow correctly
      // TODO: Verify alarm triggers at right time
      // TODO: Check for race conditions
    });

    test('DirectionService + RouteCache integration', () async {
      // TODO: Test route fetching and caching
      // TODO: Verify cache hit rate
      // TODO: Test cache expiry
    });

    test('DeviationMonitor + ReroutePolicy integration', () async {
      // TODO: Test deviation detection triggers reroute
      // TODO: Verify reroute policy gates rapid reroutes
      // TODO: Test sustained deviation required
    });

    test('TrackingService + NotificationService integration', () async {
      // TODO: Test notifications sent at right time
      // TODO: Verify notification actions work
      // TODO: Test notification persistence
    });

    test('PersistenceManager + TrackingService integration', () async {
      // TODO: Test state saved correctly
      // TODO: Verify state restored on restart
      // TODO: Test partial state recovery
    });
  });
}
```

---

## Week 4: Platform & Performance (Should Do)

### Day 16-17: Platform-Specific Tests

**Files to Create**:
1. `test/platform/android_permissions_test.dart`
2. `test/platform/ios_permissions_test.dart`
3. `test/platform/android_background_test.dart`
4. `test/platform/ios_background_test.dart`

**Example**: `test/platform/android_background_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Android Background Restrictions', () {
    test('handles Doze mode correctly', () async {
      // TODO: Simulate Doze mode
      // Verify: Service continues with reduced frequency
      // Verify: Alarms still fire
    });

    test('handles App Standby correctly', () async {
      // TODO: Simulate App Standby
      // Verify: Critical operations continue
    });

    test('handles battery optimization', () async {
      // TODO: Test with battery saver enabled
      // Verify: Graceful degradation
    });

    test('handles manufacturer restrictions (Xiaomi)', () async {
      // TODO: Test Xiaomi-specific restrictions
      // Verify: Instructions shown to user
    });
  });
}
```

### Day 18-19: Performance Tests

**File**: `test/performance/memory_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Memory Performance', () {
    test('memory usage stays below 200MB during 1-hour tracking', () async {
      // TODO: Start tracking
      // TODO: Monitor memory usage
      // TODO: Verify no memory leaks
      // TODO: Verify memory stays below threshold
    });

    test('route cache respects memory limits', () async {
      // TODO: Cache many routes
      // TODO: Verify old routes evicted
      // TODO: Verify memory doesn't grow unbounded
    });

    test('polyline simplification reduces memory', () async {
      // TODO: Load complex route
      // TODO: Verify simplification applied
      // TODO: Measure memory savings
    });
  });
}
```

**File**: `test/performance/battery_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Battery Performance', () {
    test('battery drain is below 15% per hour', () async {
      // TODO: Monitor battery level
      // TODO: Track for 1 hour
      // TODO: Verify drain rate
      // NOTE: This requires device/emulator testing
    });

    test('GPS interval adapts to battery level', () async {
      // TODO: Simulate battery drop
      // TODO: Verify GPS interval increased
      // TODO: Measure power savings
    });

    test('idle mode reduces power consumption', () async {
      // TODO: Test idle power scaler
      // TODO: Verify reduced updates when stationary
    });
  });
}
```

### Day 20: Network Performance

**File**: `test/performance/network_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Network Performance', () {
    test('route cache reduces API calls by 80%', () async {
      // TODO: Make multiple requests for same route
      // TODO: Verify cache hit rate
      // TODO: Measure API call reduction
    });

    test('network usage stays below 5MB per hour', () async {
      // TODO: Monitor network traffic
      // TODO: Track for 1 hour journey
      // TODO: Verify bandwidth usage
    });

    test('offline mode uses zero network', () async {
      // TODO: Enable offline mode
      // TODO: Monitor network traffic
      // TODO: Verify no requests made
    });
  });
}
```

---

## Week 5: Polish & Documentation (Nice to Have)

### Day 21-22: Security Tests

**File**: `test/security/encryption_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:geowake2/services/secure_hive_init.dart';

void main() {
  group('Data Encryption', () {
    test('location data is encrypted at rest', () async {
      // TODO: Save location data
      // TODO: Read raw file
      // TODO: Verify data is encrypted (not plaintext)
    });

    test('encryption key stored securely', () async {
      // TODO: Verify key stored in flutter_secure_storage
      // TODO: Verify key not in SharedPreferences
      // TODO: Verify key not logged
    });

    test('encrypted data can be decrypted', () async {
      // TODO: Encrypt data
      // TODO: Decrypt data
      // TODO: Verify data integrity
    });
  });
}
```

**File**: `test/security/ssl_pinning_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SSL Certificate Pinning', () {
    test('rejects invalid certificates', () async {
      // TODO: Test with invalid cert
      // TODO: Verify request fails
    });

    test('accepts valid certificates', () async {
      // TODO: Test with valid cert
      // TODO: Verify request succeeds
    });
  });
}
```

### Day 23: Stress Tests

**File**: `test/stress/concurrent_operations_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Stress Tests', () {
    test('handles rapid start/stop cycles', () async {
      // TODO: Start and stop tracking 100 times rapidly
      // TODO: Verify no crashes
      // TODO: Verify no memory leaks
    });

    test('handles concurrent position updates', () async {
      // TODO: Send many position updates rapidly
      // TODO: Verify all processed correctly
      // TODO: Verify no race conditions
    });

    test('handles long-running session (12 hours)', () async {
      // TODO: Simulate 12-hour journey
      // TODO: Verify no crashes
      // TODO: Verify memory stable
    });
  });
}
```

### Day 24-25: Documentation & CI/CD

**Tasks**:
1. Create `test/README.md` with testing guide
2. Update main README.md with test status
3. Set up GitHub Actions for CI/CD
4. Configure code coverage reporting
5. Document test patterns and conventions

**File**: `test/README.md`

```markdown
# GeoWake Testing Guide

## Running Tests

```bash
# All tests
flutter test

# Specific test file
flutter test test/alarm_player_test.dart

# With coverage
flutter test --coverage

# Integration tests
flutter test integration_test/
```

## Test Structure

```
test/
├── models/              # Model validation tests
├── screens/             # UI widget tests
├── widgets/             # Custom widget tests
├── services/            # Service unit tests
├── integration/         # Component integration tests
├── journeys/            # Real-world scenario tests
├── error_recovery/      # Error handling tests
├── platform/            # Platform-specific tests
├── performance/         # Performance benchmarks
├── security/            # Security validation tests
└── stress/              # Stress and load tests
```

## Writing Tests

### Unit Tests
- Test single function/class in isolation
- Use mocks for dependencies
- Fast execution (<100ms per test)

### Widget Tests
- Test UI rendering and interaction
- Use `testWidgets` function
- Pump and settle for animations

### Integration Tests
- Test multiple components together
- Use real dependencies where possible
- Test end-to-end flows

## Test Conventions

1. **Naming**: `{component}_test.dart`
2. **Structure**: Use `group()` for organization
3. **AAA Pattern**: Arrange, Act, Assert
4. **Comments**: Given, When, Then
5. **Assertions**: Use descriptive `reason` parameter
```

**CI/CD**: `.github/workflows/test.yml`

```yaml
name: Tests

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main, develop ]

jobs:
  test:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v2
    
    - uses: subosito/flutter-action@v2
      with:
        flutter-version: '3.7.0'
        channel: 'stable'
    
    - name: Install dependencies
      run: flutter pub get
    
    - name: Run analyzer
      run: flutter analyze
    
    - name: Run unit tests
      run: flutter test --coverage
    
    - name: Upload coverage
      uses: codecov/codecov-action@v2
      with:
        files: coverage/lcov.info
```

---

## 📊 Progress Tracking

### Week 1 Progress
- [ ] Day 1-2: Permission flow tests (10 tests)
- [ ] Day 3-5: Error recovery tests (20 tests)

### Week 2 Progress
- [ ] Day 6-7: Screen tests (40 tests)
- [ ] Day 8-9: Widget tests (10 tests)
- [ ] Day 10: Navigation tests (5 tests)

### Week 3 Progress
- [ ] Day 11-13: Journey tests (15 tests)
- [ ] Day 14-15: Integration tests (10 tests)

### Week 4 Progress
- [ ] Day 16-17: Platform tests (15 tests)
- [ ] Day 18-19: Performance tests (10 tests)
- [ ] Day 20: Network tests (5 tests)

### Week 5 Progress
- [ ] Day 21-22: Security tests (10 tests)
- [ ] Day 23: Stress tests (5 tests)
- [ ] Day 24-25: Documentation & CI/CD

### Total Target
- **Starting**: 107 tests (30% coverage)
- **Ending**: 250+ tests (80% coverage)
- **New Tests**: 143+ tests
- **Time**: 5 weeks (1 developer) or 3 weeks (2 developers)

---

## 🎯 Success Metrics

### Code Coverage
- **Current**: 30%
- **Week 1**: 40%
- **Week 2**: 55%
- **Week 3**: 70%
- **Week 4**: 80%
- **Week 5**: 85%+

### Test Count
- **Current**: 107 tests
- **Week 1**: 137 tests (+30)
- **Week 2**: 192 tests (+55)
- **Week 3**: 217 tests (+25)
- **Week 4**: 247 tests (+30)
- **Week 5**: 260 tests (+13)

### Quality Metrics
- All screens tested ✅
- All models tested ✅
- Error recovery tested ✅
- Integration tested ✅
- Performance benchmarked ✅
- Security validated ✅
- CI/CD running ✅
- Documentation complete ✅

---

## 🚀 Ready for Production

After completing this roadmap:
- ✅ 80%+ code coverage
- ✅ All critical paths tested
- ✅ Error recovery validated
- ✅ Performance benchmarked
- ✅ Security hardened
- ✅ Platform-specific issues addressed
- ✅ CI/CD automated
- ✅ Documentation complete

**Result**: Production-ready with confidence! 🎉
