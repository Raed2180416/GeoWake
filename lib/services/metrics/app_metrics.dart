import 'dart:async';

// Transitional metrics facade; currently only wraps the simple in-memory MetricsRegistry.
// Designed so we can later plug in a richer registry without touching call sites.

import 'metrics.dart';
import '../log.dart';

class AppMetrics {
  AppMetrics._();
  static final AppMetrics I = AppMetrics._();

  MetricsRegistry get _reg => MetricsRegistry.I; // singleton

  void inc(String name, {int by = 1}) {
    try {
      _reg.counter(name).inc(by);
    } catch (e) {
      Log.w('AppMetrics', 'Failed to increment counter "$name": $e');
    }
  }

  void observeDuration(String name, Duration d) {
    try {
      _reg.duration(name).record(d);
    } catch (e) {
      Log.w('AppMetrics', 'Failed to record duration "$name": $e');
    }
  }

  Future<T> time<T>(String baseName, FutureOr<T> Function() fn) async {
    final sw = Stopwatch()..start();
    try { return await fn(); } finally {
      sw.stop();
      observeDuration(baseName, sw.elapsed);
    }
  }

  T timeSync<T>(String baseName, T Function() fn) {
    final sw = Stopwatch()..start();
    try { return fn(); } finally {
      sw.stop();
      observeDuration(baseName, sw.elapsed);
    }
  }
}
