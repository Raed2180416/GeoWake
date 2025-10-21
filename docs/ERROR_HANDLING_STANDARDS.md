# Error Handling and Logging Standards

## Overview
This document establishes the error handling and logging standards for the GeoWake codebase to ensure consistency, debuggability, and production readiness.

## Current State

### Logging Infrastructure
The codebase currently uses three logging approaches:

1. **AppLogger** (Structured, Recommended) - `lib/logging/app_logger.dart`
   - ✅ Structured logging with context
   - ✅ Log levels: debug, info, warn, error
   - ✅ Domain-based categorization
   - ✅ Integration with diagnostics
   - **Usage**: ~163+ locations (all catch blocks)

2. **Log utility** (Semi-structured) - `lib/services/log.dart`
   - ✅ Log levels with dart:developer
   - ⚠️ Less structured than AppLogger
   - **Usage**: Widely used across services

3. **print() and dev.log()** (Legacy, Inconsistent)
   - ❌ No structure
   - ❌ No filtering
   - ❌ Hard to aggregate
   - **Usage**: ~330+ locations

### Error Handling Improvements Made

#### Phase 1: Empty Catch Blocks (COMPLETE ✅)
- **Fixed**: 163+ empty catch blocks
- **Before**:
  ```dart
  try { 
    await SomeOperation(); 
  } catch (_) {}  // Silent failure!
  ```
- **After**:
  ```dart
  try { 
    await SomeOperation(); 
  } catch (e) {
    AppLogger.I.warn('Operation failed', 
      domain: 'tracking', 
      context: {'error': e.toString()});
  }
  ```

#### Phase 2: Force Unwrap Operators (COMPLETE ✅)
- **Fixed**: 20+ unsafe null assertions
- **Before**:
  ```dart
  final value = _someNullable!;  // Runtime crash if null!
  ```
- **After**:
  ```dart
  final value = _someNullable ?? defaultValue;  // Safe fallback
  // OR
  if (_someNullable == null) {
    AppLogger.I.error('Unexpected null value', domain: 'tracking');
    return;
  }
  final value = _someNullable;
  ```

## Recommended Standards

### 1. Exception Handling Strategy

#### For User-Facing Operations
```dart
try {
  await performOperation();
} catch (e, stackTrace) {
  AppLogger.I.error(
    'Operation failed - user impact expected',
    domain: 'user_operation',
    context: {
      'error': e.toString(),
      'operation': 'create_route',
    }
  );
  
  // Show user-friendly error
  showErrorDialog('Could not create route. Please try again.');
  
  // Optionally report to crash reporting service
  // await CrashReporting.recordError(e, stackTrace);
}
```

#### For Background Operations
```dart
try {
  await backgroundTask();
} catch (e) {
  AppLogger.I.warn(
    'Background task failed - will retry',
    domain: 'background',
    context: {
      'error': e.toString(),
      'task': 'sync_routes',
      'retry_count': retryCount,
    }
  );
  
  // Implement exponential backoff retry
  await Future.delayed(Duration(seconds: 2 << retryCount));
  // ... retry logic
}
```

#### For Cleanup/Disposal Operations
```dart
try {
  await cleanup();
} catch (e) {
  AppLogger.I.debug(
    'Cleanup operation failed - non-critical',
    domain: 'lifecycle',
    context: {'error': e.toString()}
  );
  // Continue - cleanup failures are usually non-critical
}
```

### 2. Log Level Guidelines

| Level | When to Use | Examples |
|-------|-------------|----------|
| **debug** | Development info, verbose details | "GPS update received", "Cache hit" |
| **info** | Important events, milestones | "Tracking started", "Route cached" |
| **warn** | Recoverable errors, degraded functionality | "Network timeout (will retry)", "Permission denied" |
| **error** | Critical failures requiring attention | "Database corruption", "Fatal parsing error" |

### 3. Domain Categorization

Use consistent domains for filtering:

```dart
// Core domains
'tracking'       // GPS tracking, location updates
'alarm'          // Alarm triggering, scheduling
'network'        // API calls, network operations
'persistence'    // Database, file I/O
'ui'             // User interface events
'background'     // Background service operations
'session'        // Session management
'security'       // Authentication, encryption
```

### 4. Context Best Practices

Always include relevant context:

```dart
AppLogger.I.warn('Route fetch failed', 
  domain: 'network',
  context: {
    'error': e.toString(),
    'url': sanitizedUrl,          // NEVER include tokens/secrets
    'retry_count': retryCount,
    'elapsed_ms': elapsed,
    'user_id': anonymizedUserId,  // Anonymize PII
  }
);
```

### 5. Error Classification

Classify errors for appropriate handling:

```dart
enum ErrorSeverity { 
  minor,      // Log and continue
  moderate,   // Log, notify user, attempt recovery
  critical,   // Log, notify user, potentially block operation
  fatal,      // Log, report to crash service, graceful degradation
}

enum ErrorType {
  network,      // Retryable network failures
  validation,   // Invalid user input
  permission,   // Missing permissions
  state,        // Invalid state transitions
  data,         // Data corruption/inconsistency
}
```

## Migration Path

### Short Term (Next Release)
1. ✅ All catch blocks use AppLogger (DONE)
2. ✅ All force unwraps removed (DONE)
3. ⚠️ Consider adding error classification utilities
4. ⚠️ Consider crash reporting integration (Firebase Crashlytics or Sentry)

### Medium Term (Next 3 Months)
1. Migrate print() statements to AppLogger
2. Standardize dev.log() usage
3. Add error recovery mechanisms
4. Implement retry strategies with exponential backoff

### Long Term (Future)
1. Centralized error reporting service
2. Real-time error monitoring dashboard
3. Automated error aggregation and alerting
4. A/B testing for error recovery strategies

## Examples from Codebase

### Good Examples

#### Proper Error Logging (New Standard)
```dart
// lib/services/trackingservice/background_lifecycle.dart
try {
  await NotificationService().cancelJourneyProgress();
} catch (e) {
  AppLogger.I.warn('Failed to cancel journey progress notification', 
    domain: 'tracking', 
    context: {'error': e.toString()});
}
```

#### Safe Null Handling
```dart
// lib/services/eta/eta_engine.dart
final currentSmoothed = _smoothedEta ?? rawEta;
_smoothedEta = alpha * rawEta + (1 - alpha) * currentSmoothed;
```

### Areas for Improvement

#### Replace print() with Structured Logging
```dart
// BEFORE (98 locations)
print('GW_BOOT_PHASE start');

// AFTER (recommended)
AppLogger.I.info('Bootstrap phase started', 
  domain: 'bootstrap',
  context: {'phase': 'initialization'});
```

#### Add Error Recovery
```dart
// BEFORE
try {
  await apiCall();
} catch (e) {
  AppLogger.I.warn('API call failed', 
    domain: 'network', 
    context: {'error': e.toString()});
}

// AFTER (with retry)
for (int i = 0; i < 3; i++) {
  try {
    await apiCall();
    break;  // Success
  } catch (e) {
    if (i == 2) {  // Last attempt
      AppLogger.I.error('API call failed after retries', 
        domain: 'network',
        context: {
          'error': e.toString(),
          'attempts': 3,
        });
      rethrow;  // Or handle gracefully
    }
    AppLogger.I.warn('API call failed, retrying', 
      domain: 'network',
      context: {
        'error': e.toString(),
        'attempt': i + 1,
      });
    await Future.delayed(Duration(seconds: 2 << i));
  }
}
```

## Testing Error Handling

### Unit Tests
```dart
test('handles network timeout gracefully', () async {
  // Inject mock that throws
  final mockClient = MockHttpClient();
  when(mockClient.get(any)).thenThrow(TimeoutException(''));
  
  // Verify error is logged
  final result = await service.fetchRoute();
  
  expect(result, isNull);  // Graceful degradation
  verify(mockLogger.warn(any, domain: 'network')).called(1);
});
```

### Integration Tests
```dart
testWidgets('shows error dialog on route creation failure', (tester) async {
  await tester.pumpWidget(MyApp());
  await tester.tap(find.text('Create Route'));
  await tester.pump();
  
  expect(find.text('Could not create route'), findsOneWidget);
});
```

## Monitoring and Alerting

### Recommended Metrics
1. Error rate by domain
2. Error rate by severity
3. Time to recover from errors
4. User impact (errors affecting user sessions)

### Alert Thresholds
- **Warning**: Error rate > 1% of requests
- **Critical**: Error rate > 5% of requests
- **Emergency**: Error rate > 25% or critical errors > 0.1%

## Summary

- ✅ **163+ empty catch blocks fixed** with proper logging
- ✅ **20+ force unwraps removed** with safe null handling
- ✅ **Consistent error handling patterns** established
- ⚠️ **98 print() statements** remain (can be migrated to AppLogger)
- ⚠️ **234 dev.log() statements** remain (can be standardized)
- 🎯 **Foundation established** for production-grade error handling

The codebase now has a solid foundation for error handling and logging. Future work can focus on:
1. Migrating legacy print/dev.log to AppLogger
2. Adding crash reporting integration
3. Implementing retry strategies
4. Adding error classification utilities
