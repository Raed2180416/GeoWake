/// app_metrics.dart: Source file from lib/lib/services/metrics/app_metrics.dart
/// 
/// This annotated version provides detailed documentation for all classes, methods, and fields.

import 'dart:async';

// Transitional metrics facade; currently only wraps the simple in-memory MetricsRegistry.
// Designed so we can later plug in a richer registry without touching call sites.

import 'metrics.dart';

/// AppMetrics: Class for [brief description]
/// 
/// **Purpose**: [What this class does]
/// 
/// **Usage**: [How to use this class]
class AppMetrics {
  /// _: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  AppMetrics._();
  /// _: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  static final AppMetrics I = AppMetrics._();

  MetricsRegistry get _reg => MetricsRegistry.I; // singleton

  /// inc: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  void inc(String name, {int by = 1}) {
    /// counter: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    try { _reg.counter(name).inc(by); } catch (_) {}
  }

  /// observeDuration: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  void observeDuration(String name, Duration d) {
    /// duration: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    try { _reg.duration(name).record(d); } catch (_) {}
  }

  Future<T> time<T>(String baseName, FutureOr<T> Function() fn) async {
    final sw = Stopwatch()..start();
    /// fn: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    try { return await fn(); } finally {
      /// stop: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      sw.stop();
      /// observeDuration: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      observeDuration(baseName, sw.elapsed);
    }
  }

  T timeSync<T>(String baseName, T Function() fn) {
    final sw = Stopwatch()..start();
    /// fn: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    try { return fn(); } finally {
      /// stop: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      sw.stop();
      /// observeDuration: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      observeDuration(baseName, sw.elapsed);
    }
  }
}
