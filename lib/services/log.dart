import 'dart:developer' as dev;

/// Simple structured logging utility with level & tag.
/// Can be expanded later for filtering, remote upload, etc.
enum LogLevel { debug, info, warn, error }

class Log {
  static bool enableDebug = true; // Toggle verbose output

  static void d(String tag, String message) {
    if (!enableDebug) return;
    dev.log(message, name: tag, level: 500);
  }

  static void i(String tag, String message) {
    dev.log(message, name: tag, level: 800);
  }

  static void w(String tag, String message) {
    dev.log('WARN: $message', name: tag, level: 900);
  }

  static void e(String tag, String message, [Object? error, StackTrace? st]) {
    dev.log('ERROR: $message ${error != null ? 'err=$error' : ''}', name: tag, level: 1000, stackTrace: st);
  }
}
