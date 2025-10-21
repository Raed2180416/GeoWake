# GeoWake - Production Issues Tracker
## Comprehensive Issue List for Production Readiness

**Date**: October 21, 2025  
**Total Issues**: 26 (1 Critical FIXED + 12 High + 8 Medium + 5 Low)  
**Resolved**: 1  
**Remaining**: 25

---

## 🔴 CRITICAL ISSUES (Priority P0)

### ✅ CRIT-001: Compilation Error in background_lifecycle.dart [RESOLVED]
- **Status**: ✅ RESOLVED - Oct 21, 2025
- **Priority**: P0 - BLOCKING
- **File**: `lib/services/trackingservice/background_lifecycle.dart` lines 166-179
- **Description**: Copy-paste error created malformed code with invalid string literal containing executable code
- **Impact**: App could not compile, all functionality blocked
- **Root Cause**: Accidental paste of code inside error message string
- **Fix Applied**: Corrected error handling blocks, properly closed try-catch statements
- **Time to Fix**: 15 minutes
- **Verification**: Code now compiles successfully
- **Prevention**: Add pre-commit hooks to check syntax errors

---

## 🟠 HIGH PRIORITY ISSUES (Priority P1)

### HIGH-001: No Crash Reporting
- **Status**: ❌ OPEN - CRITICAL
- **Priority**: P0 - MANDATORY before production
- **Impact**: Cannot monitor crashes in production, flying blind
- **Risk**: HIGH - Will miss critical bugs affecting users
- **User Impact**: Undetected crashes lead to poor user experience and bad reviews

**Details**:
- No Sentry, Firebase Crashlytics, or similar integrated
- Cannot track crash rate, stack traces, or device information
- Cannot prioritize fixes based on crash frequency
- No alerting when crash rate exceeds threshold

**Solution**:
1. Choose crash reporting service (Recommended: Sentry or Firebase Crashlytics)
2. Add dependency to `pubspec.yaml`
3. Initialize in `main.dart`
4. Add error boundaries in critical code paths
5. Test crash reporting in debug/staging

**Effort**: 2-3 days
- Day 1: Integration and basic setup
- Day 2: Test and verify reporting
- Day 3: Add custom context and error boundaries

**Files to Modify**:
- `pubspec.yaml` - Add dependency
- `lib/main.dart` - Initialize crash reporting
- `lib/services/trackingservice.dart` - Add error boundaries
- `lib/screens/` - Add screen-level error handling

**Acceptance Criteria**:
- ✅ Crash reporting SDK integrated
- ✅ Crashes automatically reported
- ✅ Stack traces include symbolication
- ✅ Device info and custom context included
- ✅ Alert configured for crash rate >1%

---

### HIGH-002: No Analytics/Telemetry
- **Status**: ❌ OPEN - CRITICAL
- **Priority**: P1 - MANDATORY for monetization
- **Impact**: Cannot track user behavior, optimize features, or make data-driven decisions
- **Risk**: HIGH - Cannot measure success or identify problems

**Details**:
- No Firebase Analytics, Mixpanel, or similar
- Cannot track:
  - User acquisition sources
  - Feature usage
  - User retention
  - Journey completion rates
  - Time to alarm
  - Error rates
  - Performance metrics

**Solution**:
1. Choose analytics service (Recommended: Firebase Analytics)
2. Add dependency to `pubspec.yaml`
3. Initialize in `main.dart`
4. Add event tracking in key user flows
5. Create analytics dashboard

**Effort**: 3-4 days
- Day 1-2: Integration and event planning
- Day 3: Implement tracking in key flows
- Day 4: Test and verify data collection

**Events to Track**:
- Journey started (with mode: distance/time/stops)
- Journey completed
- Alarm triggered
- Alarm dismissed
- Route cached/fetched
- Permission granted/denied
- Error occurred
- App crash (via crash reporting)

**Files to Modify**:
- `pubspec.yaml`
- `lib/main.dart`
- `lib/services/trackingservice.dart`
- `lib/screens/homescreen.dart`
- `lib/screens/maptracking.dart`

**Acceptance Criteria**:
- ✅ Analytics SDK integrated
- ✅ Key events tracked
- ✅ User properties set (app version, device, OS)
- ✅ Dashboard configured
- ✅ Data flowing to analytics service

---

### HIGH-003: No Device Compatibility Testing
- **Status**: ❌ OPEN - CRITICAL
- **Priority**: P1 - CRITICAL
- **Impact**: May not work on all Android devices/OEMs
- **Risk**: VERY HIGH - Different manufacturers have different behaviors

**Details**:
- Not tested on different OEMs:
  - Xiaomi (MIUI) - Aggressive battery optimization
  - Samsung (One UI) - Adaptive battery
  - OnePlus (OxygenOS) - Background restrictions
  - Oppo (ColorOS) - Background restrictions
  - Vivo (Funtouch OS) - Aggressive task killer
  - Huawei (EMUI) - No Google Play Services
  - Nokia - Stock Android but strict doze
  - Motorola - Stock Android variations
  - Realme - ColorOS fork
  - LG - Different background service handling

**Specific Risks**:
1. Background service killed during tracking
2. Alarms not firing on locked screen
3. GPS updates stopped when screen off
4. Notifications not showing
5. Permissions revoked automatically
6. Battery optimization preventing wake locks
7. Doze mode killing foreground service

**Solution**:
1. Acquire test devices or use device farm (Firebase Test Lab)
2. Test critical flows on each device
3. Document workarounds for OEM-specific issues
4. Add in-app guidance for problematic manufacturers

**Effort**: 2-3 weeks
- Week 1: Test on 5 major OEMs
- Week 2: Test on 5 additional devices
- Week 3: Fix issues found, retest

**Test Matrix**:
| OEM | Model | Android | Priority |
|-----|-------|---------|----------|
| Xiaomi | Redmi Note 11 | 12 | HIGH |
| Samsung | Galaxy A52 | 12 | HIGH |
| OnePlus | 9 Pro | 12 | HIGH |
| Google | Pixel 6 | 13 | HIGH |
| Oppo | Reno 7 | 12 | MEDIUM |
| Realme | GT 2 | 12 | MEDIUM |
| Vivo | V23 | 12 | MEDIUM |
| Motorola | Edge 30 | 12 | MEDIUM |
| Nokia | G50 | 11 | LOW |
| Huawei | P40 | 10 | LOW (no GMS) |

**Test Scenarios**:
1. Start tracking, lock screen, wait 30 minutes
2. Start tracking, background app, wait 30 minutes
3. Start tracking, enable battery saver
4. Start tracking, reboot device
5. Start tracking, revoke location permission
6. Trigger alarm on locked screen
7. Run for 2+ hours continuously
8. Low battery scenario (<20%)

**Files to Modify**:
- `README.md` - Add OEM compatibility notes
- `lib/screens/settingsdrawer.dart` - Add OEM-specific guidance
- Android native code - Add OEM-specific workarounds if needed

**Acceptance Criteria**:
- ✅ Tested on 10+ devices
- ✅ Issues documented
- ✅ Critical issues fixed
- ✅ User guidance added for problematic OEMs
- ✅ No crashes on any device
- ✅ Alarms work on all devices

---

### HIGH-004: No UI Tests
- **Status**: ❌ OPEN
- **Priority**: P1 - MANDATORY
- **Impact**: UI regressions undetected, screens could crash
- **Risk**: HIGH - Any UI change could break app

**Details**:
- 0 widget tests for any screen
- Screens not tested:
  - HomeScreen (1,093 LOC)
  - MapTrackingScreen (896 LOC)
  - AlarmFullScreen
  - SettingsDrawer
  - SplashScreen
  - RingtonesScreen
  - PreloadMapScreen

**Solution**:
Add widget tests for critical flows

**Effort**: 1 week
- Day 1-2: Set up widget testing infrastructure
- Day 3-4: Write tests for HomeScreen and MapTrackingScreen
- Day 5: Write tests for other screens

**Tests Needed** (minimum 20):
1. HomeScreen - Basic rendering
2. HomeScreen - Location search
3. HomeScreen - Route display
4. HomeScreen - Start tracking button
5. MapTrackingScreen - Map display
6. MapTrackingScreen - Current location marker
7. MapTrackingScreen - Route polyline
8. MapTrackingScreen - ETA display
9. MapTrackingScreen - Stop tracking button
10. AlarmFullScreen - Alarm display
11. AlarmFullScreen - Dismiss button
12. AlarmFullScreen - Continue tracking button
13. SettingsDrawer - Theme toggle
14. SettingsDrawer - Ringtone selection
15. SplashScreen - Loading indicator
16. RingtonesScreen - List display
17. RingtonesScreen - Ringtone selection
18. Error state - No location permission
19. Error state - No network connection
20. Error state - Invalid route

**Files to Create**:
- `test/screens/homescreen_test.dart`
- `test/screens/maptracking_test.dart`
- `test/screens/alarm_fullscreen_test.dart`
- `test/screens/settings_drawer_test.dart`
- `test/screens/splash_screen_test.dart`
- `test/screens/ringtones_screen_test.dart`

**Acceptance Criteria**:
- ✅ 20+ widget tests added
- ✅ All screens have basic rendering tests
- ✅ Critical user flows tested
- ✅ Error states tested
- ✅ Tests pass in CI

---

### HIGH-005: Force Unwrap Audit (384 instances)
- **Status**: ❌ OPEN
- **Priority**: P1
- **Impact**: Potential null pointer crashes throughout app
- **Risk**: HIGH - Any incorrect assumption leads to crash

**Details**:
- 384 instances of force unwrap operator (!)
- Common patterns:
  ```dart
  _lastProcessedPosition!.latitude
  _sensorFusionManager!.stopFusion()
  _scheduledPending!.id
  ```
- Risk: If assumption is wrong, app crashes immediately
- Mitigated partially by defensive checks, but not comprehensive

**Solution**:
1. Audit all force unwraps in critical paths
2. Add null checks where needed
3. Replace with safe navigation (?.) where appropriate
4. Add assertions where null is truly impossible

**Effort**: 3-4 days
- Day 1: Audit tracking service (highest risk)
- Day 2: Audit alarm orchestrator and notification service
- Day 3: Audit screen files
- Day 4: Test and verify fixes

**Critical Files to Audit**:
1. `lib/services/trackingservice.dart` (868 LOC)
2. `lib/services/trackingservice/background_lifecycle.dart` (1,952 LOC)
3. `lib/services/trackingservice/alarm.dart` (921 LOC)
4. `lib/services/notification_service.dart` (871 LOC)
5. `lib/services/alarm_orchestrator.dart`
6. `lib/screens/homescreen.dart` (1,093 LOC)
7. `lib/screens/maptracking.dart` (896 LOC)

**Strategy**:
- **Keep**: Where null is truly impossible (e.g., after explicit null check)
- **Replace with `?.`**: Where null is possible and can be handled
- **Add assertion**: Where null should never happen (programming error)
- **Add null check**: Where null is a valid state needing handling

**Acceptance Criteria**:
- ✅ All critical path force unwraps audited
- ✅ High-risk unwraps replaced or justified
- ✅ Null check tests added where needed
- ✅ Documentation added for remaining unwraps

---

### HIGH-006: StreamController Disposal (3 potential memory leaks)
- **Status**: ❌ OPEN
- **Priority**: P1
- **Impact**: Memory leaks in long-running app
- **Risk**: MEDIUM-HIGH - Gradual memory growth

**Details**:
- 24 StreamController declarations found
- 21 dispose() methods found
- **Gap**: 3 potential memory leaks

**Files to Audit**:
1. `lib/services/event_bus.dart`
2. `lib/services/metrics/app_metrics.dart`
3. All screen files in `lib/screens/`
4. Any service with streams

**Solution**:
1. Audit all 24 StreamControllers
2. Verify each has corresponding dispose/close
3. Add dispose() methods where missing
4. Add @mustCallSuper annotations

**Effort**: 1-2 days
- Day 1: Audit all StreamControllers
- Day 2: Add missing disposal, test

**Acceptance Criteria**:
- ✅ All StreamControllers accounted for
- ✅ Each has proper disposal
- ✅ @mustCallSuper annotations added
- ✅ Memory leak tests pass

---

### HIGH-007: No Memory Profiling
- **Status**: ❌ OPEN
- **Priority**: P1
- **Impact**: Memory usage not validated on real devices
- **Risk**: MEDIUM - May exceed limits on low-end devices

**Details**:
- Current estimates: 100-150 MB (foreground), 50-80 MB (background)
- Not validated on real devices
- Low-end device behavior unknown
- Memory growth over time not tested

**Solution**:
1. Profile on 5-10 devices (mix of high/mid/low end)
2. Monitor memory usage over 2+ hours
3. Check for memory leaks
4. Validate against targets

**Effort**: 3-4 days
- Day 1-2: Set up profiling tools, collect data
- Day 3: Analyze data, identify issues
- Day 4: Fix issues if found, retest

**Devices to Profile**:
- High-end: Pixel 6, Samsung Galaxy S22
- Mid-range: Redmi Note 11, Galaxy A52
- Low-end: Budget devices with 2-3GB RAM

**Metrics to Track**:
- Initial memory footprint
- Memory after 1 hour of tracking
- Memory after 2 hours of tracking
- Peak memory usage
- Memory growth rate
- Garbage collection frequency

**Acceptance Criteria**:
- ✅ Profiled on 5+ devices
- ✅ Memory usage within targets on all devices
- ✅ No memory leaks detected
- ✅ Low-end devices tested

---

### HIGH-008: No Battery Profiling
- **Status**: ❌ OPEN
- **Priority**: P1
- **Impact**: Battery drain not validated
- **Risk**: MEDIUM - May drain battery faster than acceptable

**Details**:
- Current estimate: 10-15%/hour
- Not validated on real devices
- Different GPS chipsets behave differently
- OEM power optimizations affect drain

**Solution**:
1. Run 24-hour battery tests on multiple devices
2. Test different modes (distance/time/stops)
3. Test different battery levels
4. Test with/without battery saver

**Effort**: 1 week
- Day 1-2: Set up tests on 5 devices
- Day 3-5: Run 24-hour tests
- Day 6: Analyze data
- Day 7: Optimize if needed

**Test Scenarios**:
1. Continuous tracking for 2 hours
2. Continuous tracking with battery saver
3. Intermittent tracking (5 journeys over 8 hours)
4. Overnight tracking (low activity)
5. High activity (frequent GPS updates)

**Acceptance Criteria**:
- ✅ 24-hour tests completed on 5+ devices
- ✅ Battery drain within targets (15%/hour max)
- ✅ No excessive drain on any device
- ✅ Battery saver mode tested

---

### HIGH-009: No Internationalization
- **Status**: ❌ OPEN
- **Priority**: P2 (for global launch)
- **Impact**: English only, cannot expand to non-English markets
- **Risk**: MEDIUM - Limits addressable market significantly

**Details**:
- All strings hardcoded in English
- No i18n framework
- Cannot support:
  - Spanish (~500M speakers)
  - French (~300M speakers)
  - German (~100M speakers)
  - Hindi (~600M speakers)
  - Chinese (~1B speakers)
  - Arabic (~400M speakers)

**Solution**:
1. Add flutter_localizations dependency
2. Extract all strings to .arb files
3. Translate to target languages
4. Test with different locales

**Effort**: 2-3 weeks
- Week 1: Set up i18n, extract strings
- Week 2: Translate to 5 languages (professional translation)
- Week 3: Test and fix formatting issues

**Target Languages** (Priority order):
1. Spanish (es) - Large market
2. French (fr) - Large market
3. German (de) - High-value market
4. Hindi (hi) - Large market (India)
5. Arabic (ar) - Growing market
6. Chinese Simplified (zh_CN) - Huge market

**Files to Modify**:
- `pubspec.yaml` - Add flutter_localizations
- `lib/l10n/` - Create directory for translations
- All screen files - Replace hardcoded strings
- All service files - Replace user-facing strings

**Acceptance Criteria**:
- ✅ i18n framework integrated
- ✅ All strings extracted
- ✅ 5+ languages supported
- ✅ Tested with all locales
- ✅ RTL languages work (Arabic)

---

### HIGH-010: SSL Pinning Not Enabled
- **Status**: ❌ OPEN
- **Priority**: P2
- **Impact**: MITM attacks possible (low risk but security gap)
- **Risk**: LOW-MEDIUM

**Details**:
- Infrastructure exists in `lib/services/ssl_pinning.dart`
- Configuration disabled in `lib/config/ssl_pinning_config.dart`
- Reason: Waiting for stable production backend

**Solution**:
1. Ensure production backend has stable certificates
2. Extract certificate pins
3. Enable in config
4. Test thoroughly

**Effort**: 1 day
- Morning: Extract pins, update config
- Afternoon: Test and verify

**Files to Modify**:
- `lib/config/ssl_pinning_config.dart` - Change `enabled = false` to `enabled = true`
- Update certificate pins if needed

**Acceptance Criteria**:
- ✅ SSL pinning enabled
- ✅ Certificate pins updated
- ✅ All API calls work with pinning
- ✅ Error handling for pin mismatch

---

### HIGH-011: No End-to-End Tests
- **Status**: ❌ OPEN
- **Priority**: P2
- **Impact**: Critical flows not validated end-to-end
- **Risk**: MEDIUM - User flows may break

**Details**:
- Only 1 integration test file exists
- No complete user journey tests
- No real route tests
- No multi-step flow validation

**Solution**:
Add 5-10 E2E tests for critical flows

**Effort**: 1 week
- Day 1-2: Set up E2E testing framework
- Day 3-5: Write tests

**E2E Tests Needed**:
1. Complete distance alarm journey
2. Complete time alarm journey
3. Complete stops alarm journey
4. Alarm fired and dismissed
5. Alarm fired and continued tracking
6. Route cached and reused
7. Offline mode journey
8. Permission flow (denied then granted)
9. Background service recovery after kill
10. Reroute during journey

**Files to Create**:
- `integration_test/distance_alarm_journey_test.dart`
- `integration_test/time_alarm_journey_test.dart`
- `integration_test/stops_alarm_journey_test.dart`
- `integration_test/offline_journey_test.dart`
- `integration_test/permission_flow_test.dart`

**Acceptance Criteria**:
- ✅ 5-10 E2E tests added
- ✅ All critical flows tested
- ✅ Tests run in CI
- ✅ Tests pass consistently

---

### HIGH-012: Backend API Key Validation Missing
- **Status**: ❌ OPEN
- **Priority**: P2
- **Impact**: Cannot verify API key is valid
- **Risk**: MEDIUM - Silent failures possible

**Details**:
- No health check endpoint on backend
- Cannot validate Google Maps API key
- Cannot verify backend connectivity
- Errors only surface when API called

**Solution**:
1. Add `/health` endpoint to backend
2. Add API key validation endpoint
3. Call on app startup
4. Show user-friendly error if invalid

**Effort**: 1 day backend + 1 hour client
- Backend: Add health check endpoint
- Client: Call on startup, handle errors

**Backend Changes Needed**:
```javascript
// geowake-server/server.js
app.get('/api/health', (req, res) => {
  const apiKeyValid = validateGoogleMapsKey();
  res.json({
    status: 'ok',
    apiKeyValid: apiKeyValid,
    timestamp: new Date().toISOString()
  });
});
```

**Client Changes**:
- `lib/services/api_client.dart` - Call health endpoint on init
- Show error dialog if API key invalid

**Acceptance Criteria**:
- ✅ Health check endpoint added
- ✅ Client calls health check
- ✅ User-friendly error shown if invalid
- ✅ Logs indicate API key status

---

## 🟡 MEDIUM PRIORITY ISSUES (Priority P3)

### MED-001: God Object - TrackingService (2,820 LOC)
- **Status**: ❌ OPEN
- **Priority**: P3 (accept for MVP, refactor v2.0)
- **Impact**: Hard to test and maintain
- **Risk**: LOW (for MVP), MEDIUM (long-term)

**Details**:
- TrackingService + background_lifecycle.dart = 2,820 LOC
- Violates Single Responsibility Principle
- Responsibilities: GPS, alarms, state, rerouting, metrics, power, sensors, notifications

**Solution** (v2.0):
Split into:
- `TrackingEngine` - GPS and positioning
- `AlarmEvaluator` - Alarm logic
- `PowerManager` - Battery management
- `StateManager` - Persistence
- `NotificationController` - UI updates

**Effort**: 2-3 weeks major refactor
**Recommendation**: Accept for v1.0, schedule refactor for v2.0

---

### MED-002: Large Screen Files
- **Status**: ❌ OPEN
- **Priority**: P3
- **Impact**: UI and logic mixed
- **Risk**: LOW-MEDIUM

**Details**:
- `homescreen.dart`: 1,093 LOC
- `maptracking.dart`: 896 LOC
- UI, business logic, and state management mixed

**Solution**:
Extract business logic to view models/controllers

**Effort**: 1-2 weeks
**Recommendation**: Schedule for post-launch optimization

---

### MED-003: No Performance Regression Tests
- **Status**: ❌ OPEN
- **Priority**: P3
- **Impact**: Cannot detect performance degradation
- **Risk**: LOW-MEDIUM

**Solution**:
Add benchmark tests for critical operations

**Effort**: 2-3 days

---

### MED-004: No Security Headers Verification
- **Status**: ❌ OPEN
- **Priority**: P3
- **Impact**: Potential security vulnerabilities
- **Risk**: LOW

**Solution**:
Verify backend has proper security headers (HSTS, CSP, X-Frame-Options)

**Effort**: 1 hour

---

### MED-005: Refactor Directory Indicates Migration
- **Status**: ❌ OPEN
- **Priority**: P3
- **Impact**: Incomplete migration may cause confusion
- **Risk**: LOW

**Details**:
- `lib/services/refactor/` directory exists
- Suggests ongoing architectural migration
- Need to complete or remove

**Solution**:
Document intent, complete migration, or remove

**Effort**: Variable

---

### MED-006: No A/B Testing Framework
- **Status**: ❌ OPEN
- **Priority**: P3 (needed for AI/monetization)
- **Impact**: Cannot test different features/UI
- **Risk**: LOW (for MVP)

**Solution**:
Integrate Firebase Remote Config or similar

**Effort**: 3-4 days

---

### MED-007: No Model Validation Tests
- **Status**: ❌ OPEN
- **Priority**: P3
- **Impact**: Data models not comprehensively tested
- **Risk**: LOW

**Solution**:
Add model validation tests for all data models

**Effort**: 2-3 days

---

### MED-008: No Request Signing
- **Status**: ❌ OPEN
- **Priority**: P4 (low risk)
- **Impact**: Replay attacks possible (mitigated by token expiry)
- **Risk**: LOW

**Solution**:
Add HMAC/JWT signing for API requests

**Effort**: 1-2 weeks
**Recommendation**: Schedule for v2.0 if needed

---

## 🟢 LOW PRIORITY ISSUES (Priority P4)

### LOW-001: No Error Recovery E2E Tests
- **Effort**: 1 week
- **Risk**: LOW

### LOW-002: No Platform-Specific Error Handling
- **Effort**: 2-3 days
- **Risk**: LOW

### LOW-003: No Documentation for New Contributors
- **Effort**: 1-2 days
- **Risk**: VERY LOW

### LOW-004: No CI/CD Pipeline
- **Effort**: 2-3 days
- **Risk**: LOW
- **Note**: Manual builds work but automation improves efficiency

### LOW-005: Limited Feature Flags
- **Effort**: 2-3 days
- **Risk**: VERY LOW
- **Note**: Basic system exists, needs expansion

---

## 📊 Issue Summary

### By Priority
- **P0 (Critical)**: 1 (✅ 1 resolved)
- **P1 (High)**: 12 (❌ 12 open)
- **P3 (Medium)**: 8 (❌ 8 open)
- **P4 (Low)**: 5 (❌ 5 open)

**Total**: 26 issues (1 resolved, 25 open)

### By Status
- ✅ **Resolved**: 1 (4%)
- ❌ **Open**: 25 (96%)

### By Effort
- **<1 day**: 3 issues
- **1-3 days**: 8 issues
- **1 week**: 6 issues
- **2-3 weeks**: 5 issues
- **4+ weeks**: 3 issues

**Total Effort**: ~12-15 weeks (with parallel work: 5-6 weeks)

---

## 🎯 Recommended Action Plan

### Week 1: Critical Infrastructure
- ✅ Fix compilation error (DONE)
- HIGH-001: Crash reporting (2-3 days)
- HIGH-002: Analytics (3-4 days)

### Week 2-3: Testing & Validation
- HIGH-003: Device testing (2-3 weeks, can run in parallel)
- HIGH-004: UI tests (1 week)
- HIGH-007: Memory profiling (3-4 days)
- HIGH-008: Battery profiling (1 week)

### Week 4: Polish
- HIGH-005: Force unwrap audit (3-4 days)
- HIGH-006: StreamController audit (1-2 days)
- HIGH-010: Enable SSL pinning (1 day)

### Week 5-6: Launch Prep
- HIGH-011: E2E tests (1 week)
- HIGH-012: API health check (1 day)
- Final QA and bug fixes

### Post-Launch (Optional)
- HIGH-009: Internationalization (2-3 weeks)
- MED issues (as time permits)
- LOW issues (backlog)

---

**Document Version**: 1.0.0  
**Last Updated**: October 21, 2025  
**Next Review**: Weekly during production preparation

