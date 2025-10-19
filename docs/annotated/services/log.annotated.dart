/// log.dart: Source file from lib/lib/services/log.dart
/// 
/// This annotated version provides detailed documentation for all classes, methods, and fields.

import 'dart:developer' as dev;

/// Simple structured logging utility with level & tag.
/// Can be expanded later for filtering, remote upload, etc.
enum LogLevel { debug, info, warn, error }

/// Log: Class for [brief description]
/// 
/// **Purpose**: [What this class does]
/// 
/// **Usage**: [How to use this class]
class Log {
  /// [Brief description of this field]
  static bool enableDebug = true; // Toggle verbose output

  /// d: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  static void d(String tag, String message) {
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (!enableDebug) return;
    /// log: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    dev.log(message, name: tag, level: 500);
  }

  /// i: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  static void i(String tag, String message) {
    /// log: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    dev.log(message, name: tag, level: 800);
  }

  /// w: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  static void w(String tag, String message) {
    /// log: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    dev.log('WARN: $message', name: tag, level: 900);
  }

  /// e: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  static void e(String tag, String message, [Object? error, StackTrace? st]) {
    /// log: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    dev.log('ERROR: $message ${error != null ? 'err=$error' : ''}', name: tag, level: 1000, stackTrace: st);
  }
}
