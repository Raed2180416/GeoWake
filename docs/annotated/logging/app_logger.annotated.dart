import 'dart:developer' as dev;
import 'package:flutter_background_service/flutter_background_service.dart';

/// Simple structured logger facade to enable future redirection to metrics or files.
/// 
/// **Purpose**: Centralized logging with structured context. Provides a single
/// point to control log output, filtering, and routing.
///
/// **Current implementation**: Routes to `dart:developer` log for simplicity.
/// Can be enhanced to write to files, send to analytics, or integrate with
/// crash reporting in the future.
///
/// **Why not print()?**: 
/// - `print()` can't be filtered by level
/// - `print()` lacks structure (no timestamps, domains, context)
/// - `print()` is hard to disable in production
///
/// **Usage - Basic**:
/// ```dart
/// AppLogger.I.info('User started tracking', domain: 'session');
/// AppLogger.I.warn('GPS signal weak', domain: 'location');
/// AppLogger.I.error('API call failed', domain: 'network');
/// ```
///
/// **Usage - With context**:
/// ```dart
/// AppLogger.I.info('Alarm triggered', 
///   domain: 'alarm',
///   context: {
///     'remainingMeters': 145.2,
///     'etaSeconds': 58,
///     'mode': 'distance',
///   }
/// );
/// ```
///
/// **Usage - In tests**:
/// ```dart
/// // Disable noisy debug logs
/// AppLogger.I.minimumLevel = LogLevel.warn;
/// ```
///
/// **Domains**: Logical grouping for log filtering
/// - `alarm`: Alarm evaluation and firing
/// - `session`: Tracking session lifecycle
/// - `location`: GPS and positioning
/// - `network`: API calls and connectivity
/// - `eta`: ETA calculations
/// - `core`: General app logic
///
/// For now routes to dev.log; kept lightweight to avoid impacting production until wired.
class AppLogger {
  /// Singleton instance
  static AppLogger? _instance;
  
  /// Access the singleton logger instance
  /// Creates instance on first access
  static AppLogger get I => _instance ??= AppLogger();

  /// Minimum log level to output
  /// Logs below this level are silently dropped
  /// 
  /// **Production tip**: Set to `LogLevel.warn` or `LogLevel.error` in release
  /// builds to reduce log volume and improve performance
  LogLevel minimumLevel = LogLevel.debug; // can be raised in release builds

  /// Core logging method - all other methods delegate to this
  /// 
  /// **Parameters**:
  /// - `message`: Human-readable log message
  /// - `domain`: Logical grouping (alarm, session, location, etc)
  /// - `level`: Severity (debug, info, warn, error)
  /// - `context`: Structured key-value pairs for filtering/analysis
  void log(String message, {String domain = 'core', LogLevel level = LogLevel.info, Map<String, Object?> context = const {}}) {
    // Filter by minimum level
    if (level.index < minimumLevel.index) return;
    
    // Format: [timestamp][LEVEL][domain] message key1=val1 key2=val2
    final ts = DateTime.now().toIso8601String();
    final levelStr = level.name.toUpperCase();
    final ctx = context.isEmpty ? '' : ' ' + _encodeContext(context);
    dev.log('[$ts][$levelStr][$domain] $message$ctx', name: 'AppLogger');
    
    // Best-effort bridge to foreground Diagnostics live log tail for interesting domains
    // If background service is running, forward alarm/session logs to UI
    try {
      if (domain == 'alarm' || domain == 'session') {
        FlutterBackgroundService().invoke('logTail', {
          'level': levelStr,
          'domain': domain,
          'message': message,
          'context': context,
        });
      }
    } catch (_) {
      // Silently fail - background service may not be running
    }
  }

  /// Log at DEBUG level - detailed diagnostic information
  /// Use for: Algorithm internals, intermediate calculations, verbose state
  void debug(String m, {String domain='core', Map<String,Object?> context=const {}}) =>
      log(m, domain: domain, level: LogLevel.debug, context: context);
  
  /// Log at INFO level - normal operational messages
  /// Use for: Milestones, state changes, user actions
  void info(String m, {String domain='core', Map<String,Object?> context=const {}}) =>
      log(m, domain: domain, level: LogLevel.info, context: context);
  
  /// Log at WARN level - unexpected but recoverable situations
  /// Use for: Degraded functionality, retries, fallbacks
  void warn(String m, {String domain='core', Map<String,Object?> context=const {}}) =>
      log(m, domain: domain, level: LogLevel.warn, context: context);
  
  /// Log at ERROR level - errors requiring attention
  /// Use for: Failures, exceptions, data corruption
  void error(String m, {String domain='core', Map<String,Object?> context=const {}}) =>
      log(m, domain: domain, level: LogLevel.error, context: context);

  /// Formats context map as space-separated key=value pairs
  String _encodeContext(Map<String,Object?> ctx) => ctx.entries.map((e) => '${e.key}=${e.value}').join(' ');
}

/// Log severity levels (ordered from least to most severe)
/// 
/// **Filtering**: Set `AppLogger.I.minimumLevel` to control output
/// - `debug`: Verbose, only needed during development
/// - `info`: Normal operational events
/// - `warn`: Unexpected but handled situations
/// - `error`: Failures requiring investigation
enum LogLevel { debug, info, warn, error }
