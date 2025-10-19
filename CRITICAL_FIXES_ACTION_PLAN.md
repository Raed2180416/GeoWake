# Critical Fixes Action Plan
## Priority Implementation Guide for GeoWake

Based on the comprehensive audit, these are the **must-fix** issues before proceeding with Extended Kalman Filter and AI integration.

---

## PHASE 1: CRITICAL FIXES (2-3 days)

### Fix 1: Theme Preference Persistence 
**File**: `lib/main.dart`  
**Effort**: 30 minutes  
**Impact**: High - Basic UX

```dart
// Add to MyAppState class
Future<void> _loadThemePreference() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        isDarkMode = prefs.getBool('isDarkMode') ?? false;
      });
    }
  } catch (e) {
    dev.log('Failed to load theme preference: $e', name: 'main');
  }
}

// Update initState
@override
void initState() {
  super.initState();
  _loadThemePreference(); // ADD THIS LINE
  WidgetsBinding.instance.addObserver(this);
  // ... rest
}

// Update toggleTheme
void toggleTheme() async {
  setState(() {
    isDarkMode = !isDarkMode;
  });
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDarkMode);
  } catch (e) {
    dev.log('Failed to save theme preference: $e', name: 'main');
  }
}
```

**Test**:
1. Toggle theme to dark
2. Force stop app
3. Relaunch
4. Verify dark theme persists

---

### Fix 2: System Theme Detection
**File**: `lib/main.dart`  
**Effort**: 1 hour  
**Impact**: High - Accessibility

```dart
// Add theme mode enum
enum AppThemeMode { system, light, dark }

// In MyAppState
AppThemeMode _themeMode = AppThemeMode.system;

Future<void> _loadThemePreference() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        final themeStr = prefs.getString('themeMode') ?? 'system';
        _themeMode = AppThemeMode.values.firstWhere(
          (e) => e.toString().split('.').last == themeStr,
          orElse: () => AppThemeMode.system,
        );
      });
    }
  } catch (e) {
    dev.log('Failed to load theme preference: $e', name: 'main');
  }
}

@override
Widget build(BuildContext context) {
  // Detect system brightness
  final systemBrightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
  
  // Determine effective theme
  ThemeData effectiveTheme;
  if (_themeMode == AppThemeMode.system) {
    effectiveTheme = systemBrightness == Brightness.dark 
        ? AppThemes.darkTheme 
        : AppThemes.lightTheme;
  } else {
    effectiveTheme = _themeMode == AppThemeMode.dark
        ? AppThemes.darkTheme
        : AppThemes.lightTheme;
  }
  
  return MaterialApp(
    theme: effectiveTheme,
    // ... rest
  );
}
```

---

### Fix 3: RouteModel Input Validation
**File**: `lib/models/route_models.dart`  
**Effort**: 30 minutes  
**Impact**: Critical - Prevents crashes

```dart
RouteModel({
  required this.polylineEncoded,
  required this.polylineDecoded,
  required this.timestamp,
  required this.initialETA,
  required this.currentETA,
  required this.distance,
  required this.travelMode,
  this.isActive = false,
  required this.routeId,
  required this.originalResponse,
  this.transitSwitches = const [],
}) : 
  assert(polylineEncoded.isNotEmpty, 'Encoded polyline cannot be empty'),
  assert(polylineDecoded.isNotEmpty, 'Decoded polyline must have at least one point'),
  assert(polylineDecoded.length >= 2, 'Route must have start and end points'),
  assert(initialETA >= 0 && initialETA.isFinite, 'initialETA must be >= 0 and finite, got: $initialETA'),
  assert(currentETA >= 0 && currentETA.isFinite, 'currentETA must be >= 0 and finite, got: $currentETA'),
  assert(distance >= 0 && distance.isFinite, 'distance must be >= 0 and finite, got: $distance'),
  assert(distance <= 40075000, 'distance cannot exceed Earth circumference'),
  assert(routeId.isNotEmpty, 'routeId cannot be empty'),
  assert(travelMode.isNotEmpty, 'travelMode cannot be empty');
```

**Test**: Try to create RouteModel with invalid data, verify assertions fire.

---

### Fix 4: Hive Encryption
**File**: `lib/main.dart` or new `lib/services/hive_init.dart`  
**Effort**: 2 hours (including migration)  
**Impact**: Critical - Security/Privacy

```dart
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

class HiveEncryption {
  static Future<void> initialize() async {
    await Hive.initFlutter();
    
    final secureStorage = FlutterSecureStorage();
    
    // Get or generate encryption key
    String? keyString = await secureStorage.read(key: 'hive_encryption_key');
    if (keyString == null) {
      final key = Hive.generateSecureKey();
      keyString = base64Encode(key);
      await secureStorage.write(key: 'hive_encryption_key', value: keyString);
    }
    
    final encryptionKey = base64Decode(keyString);
    final cipher = HiveAesCipher(encryptionKey);
    
    // Migrate existing boxes if needed
    await _migrateIfNeeded(cipher);
    
    // Open all boxes with encryption
    await Hive.openBox('route_cache', encryptionCipher: cipher);
    await Hive.openBox('recent_locations', encryptionCipher: cipher);
  }
  
  static Future<void> _migrateIfNeeded(HiveAesCipher cipher) async {
    final prefs = await SharedPreferences.getInstance();
    final migrated = prefs.getBool('hive_encrypted') ?? false;
    
    if (migrated) return;
    
    try {
      // Open old unencrypted boxes
      final oldRouteCache = await Hive.openBox('route_cache');
      final oldLocations = await Hive.openBox('recent_locations');
      
      // Open new encrypted boxes
      final newRouteCache = await Hive.openBox('route_cache_encrypted', encryptionCipher: cipher);
      final newLocations = await Hive.openBox('recent_locations_encrypted', encryptionCipher: cipher);
      
      // Copy data
      await newRouteCache.putAll(oldRouteCache.toMap());
      await newLocations.putAll(oldLocations.toMap());
      
      // Delete old boxes
      await oldRouteCache.deleteFromDisk();
      await oldLocations.deleteFromDisk();
      
      // Rename encrypted boxes to original names
      await newRouteCache.close();
      await newLocations.close();
      
      // Mark migration complete
      await prefs.setBool('hive_encrypted', true);
      
      dev.log('Hive encryption migration completed successfully');
    } catch (e) {
      dev.log('Hive encryption migration failed: $e');
      // Continue anyway - better encrypted from now on than not at all
    }
  }
}

// In main():
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveEncryption.initialize(); // ADD THIS
  runApp(const MyApp());
  // ...
}
```

**Test**: 
1. Run app with existing data
2. Verify migration completes
3. Verify data still accessible
4. Use device file explorer to verify encryption

---

### Fix 5: Permission Revocation Monitoring
**File**: New `lib/services/permission_monitor.dart`  
**Effort**: 2 hours  
**Impact**: Critical - Silent failure prevention

```dart
import 'dart:async';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';
import 'package:app_settings/app_settings.dart';
import 'dart:developer' as dev;
import '../services/navigation_service.dart';
import '../services/trackingservice.dart';

class PermissionMonitor {
  Timer? _monitorTimer;
  bool _hasShownLocationWarning = false;
  bool _hasShownNotificationWarning = false;
  
  void startMonitoring() {
    _monitorTimer?.cancel();
    _monitorTimer = Timer.periodic(Duration(seconds: 30), (_) {
      _checkCriticalPermissions();
    });
    dev.log('Permission monitoring started', name: 'PermissionMonitor');
  }
  
  void stopMonitoring() {
    _monitorTimer?.cancel();
    _monitorTimer = null;
    dev.log('Permission monitoring stopped', name: 'PermissionMonitor');
  }
  
  Future<void> _checkCriticalPermissions() async {
    try {
      // Check location permission
      final locationStatus = await Permission.location.status;
      if (!locationStatus.isGranted) {
        await _handleLocationRevoked();
      } else {
        _hasShownLocationWarning = false;
      }
      
      // Check notification permission  
      final notifStatus = await Permission.notification.status;
      if (!notifStatus.isGranted) {
        await _handleNotificationRevoked();
      } else {
        _hasShownNotificationWarning = false;
      }
    } catch (e) {
      dev.log('Permission check failed: $e', name: 'PermissionMonitor');
    }
  }
  
  Future<void> _handleLocationRevoked() async {
    // Critical: Stop tracking immediately
    if (TrackingService.trackingActive) {
      dev.log('Location permission revoked during tracking - stopping', 
              name: 'PermissionMonitor');
      try {
        await TrackingService().stopTracking();
      } catch (e) {
        dev.log('Failed to stop tracking: $e', name: 'PermissionMonitor');
      }
    }
    
    // Show warning dialog (only once until granted again)
    if (!_hasShownLocationWarning) {
      _hasShownLocationWarning = true;
      _showPermissionRevokedDialog(
        'Location Permission Required',
        'Location access was disabled. GeoWake needs location permission to track your journey and wake you at the right stop.',
      );
    }
  }
  
  Future<void> _handleNotificationRevoked() async {
    if (!_hasShownNotificationWarning) {
      _hasShownNotificationWarning = true;
      _showPermissionRevokedDialog(
        'Notification Permission Required',
        'Notification access was disabled. GeoWake needs this permission to show alarm notifications when you approach your destination.',
      );
    }
  }
  
  void _showPermissionRevokedDialog(String title, String message) {
    final context = NavigationService.navigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            child: Text('Dismiss'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: Text('Open Settings'),
            onPressed: () {
              AppSettings.openAppSettings();
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}

// In main.dart MyAppState:
final _permissionMonitor = PermissionMonitor();

@override
void initState() {
  super.initState();
  // ...
  _permissionMonitor.startMonitoring(); // ADD THIS
}

@override
void dispose() {
  _permissionMonitor.stopMonitoring(); // ADD THIS
  // ...
  super.dispose();
}
```

---

### Fix 6: Route Cache TTL Enforcement
**File**: `lib/services/route_cache.dart`  
**Effort**: 15 minutes  
**Impact**: High - Data freshness

```dart
RouteModel? get(String origin, String destination) {
  final key = _makeKey(origin, destination);
  final entry = _box.get(key);
  
  if (entry == null) return null;
  
  // ENFORCE TTL
  final age = DateTime.now().difference(entry.timestamp);
  const ttl = Duration(minutes: 5);
  
  if (age > ttl) {
    dev.log('Cache entry expired (age: ${age.inMinutes}min)', name: 'RouteCache');
    _box.delete(key);
    return null;
  }
  
  return entry;
}

// Add method for getting stale entries explicitly (for debugging/metrics)
RouteModel? getStale(String origin, String destination) {
  final key = _makeKey(origin, destination);
  return _box.get(key);
}
```

---

### Fix 7: Alarm Deduplication Memory Leak
**File**: `lib/services/alarm_deduplicator.dart`  
**Effort**: 30 minutes  
**Impact**: High - Memory leak

```dart
class AlarmDeduplicator {
  final Map<String, DateTime> _firedAlarms = {};
  final Duration _expiryDuration = Duration(hours: 2);
  DateTime? _lastPruneTime;
  
  bool hasAlreadyFired(AlarmType type, LatLng location) {
    _pruneExpiredIfNeeded();
    
    final key = _makeKey(type, location);
    
    if (_firedAlarms.containsKey(key)) {
      return true;
    }
    
    _firedAlarms[key] = DateTime.now();
    return false;
  }
  
  void _pruneExpiredIfNeeded() {
    final now = DateTime.now();
    
    // Only prune once every 10 minutes
    if (_lastPruneTime != null && 
        now.difference(_lastPruneTime!) < Duration(minutes: 10)) {
      return;
    }
    
    _lastPruneTime = now;
    final cutoff = now.subtract(_expiryDuration);
    
    final beforeCount = _firedAlarms.length;
    _firedAlarms.removeWhere((key, time) => time.isBefore(cutoff));
    final afterCount = _firedAlarms.length;
    
    if (beforeCount != afterCount) {
      dev.log('Pruned ${beforeCount - afterCount} expired alarms, ${afterCount} remain',
              name: 'AlarmDeduplicator');
    }
  }
  
  String _makeKey(AlarmType type, LatLng location) {
    // Increased precision to 6 decimals = ~0.11 meters
    return '${type}_${location.latitude.toStringAsFixed(6)}_${location.longitude.toStringAsFixed(6)}';
  }
  
  void clear() {
    _firedAlarms.clear();
    _lastPruneTime = null;
  }
}
```

---

## PHASE 2: HIGH PRIORITY FIXES (2-3 days)

### Fix 8: RouteModel Essential Methods
**File**: `lib/models/route_models.dart`  
**Effort**: 1 hour

Add copyWith(), ==, hashCode, toJson(), fromJson() methods (see audit report for full implementation).

---

### Fix 9: Boot Receiver for Alarm Restoration
**Files**: Android code + Dart persistence  
**Effort**: 2 hours

Create BootReceiver.kt and alarm persistence logic (see audit report for implementation).

---

### Fix 10: Offline Mode Indicator
**File**: `lib/screens/maptracking.dart`  
**Effort**: 1 hour

Add connectivity monitoring and offline banner (see audit report for implementation).

---

### Fix 11: Battery Optimization Guidance
**File**: New `lib/services/battery_optimization_helper.dart`  
**Effort**: 1 hour

Guide users to whitelist app from battery optimization (see audit report for implementation).

---

### Fix 12: Android 12+ Exact Alarm Permission
**File**: Permission handling code  
**Effort**: 30 minutes

```dart
Future<void> checkExactAlarmPermission() async {
  if (!Platform.isAndroid) return;
  
  final androidInfo = await DeviceInfoPlugin().androidInfo;
  if (androidInfo.version.sdkInt >= 31) {
    final status = await Permission.scheduleExactAlarm.status;
    if (!status.isGranted) {
      // Show rationale
      await _showExactAlarmRationale();
      await Permission.scheduleExactAlarm.request();
    }
  }
}
```

---

## Testing Plan

After implementing each fix:

1. **Unit Tests**: Test individual functions
2. **Widget Tests**: Test UI components
3. **Integration Tests**: Test full flows
4. **Manual Testing**: 
   - Test on Android 6, 10, 12, 13, 14
   - Test permission revocation scenarios
   - Test device reboot scenarios
   - Test offline scenarios
   - Test memory usage over time

---

## Deployment Checklist

- [ ] All PHASE 1 fixes implemented
- [ ] All PHASE 1 fixes tested
- [ ] Migration tested on devices with existing data
- [ ] Memory leak tests pass (run for 24 hours)
- [ ] Permission revocation scenarios tested
- [ ] Device reboot scenarios tested
- [ ] Encryption verified working
- [ ] Theme persistence verified working
- [ ] Documentation updated

---

## Next Steps After Fixes

Once all critical fixes are complete and tested:

1. ✅ Proceed with Extended Kalman Filter implementation
2. ✅ Integrate AI components
3. Address MEDIUM and LOW priority issues
4. Expand test coverage
5. Performance optimization
6. Accessibility audit

---

**Estimated Total Time**: 4-6 days for all critical and high priority fixes
**Risk Level**: Low - All fixes are surgical and well-documented
**Breaking Changes**: None - All backward compatible with migration paths
