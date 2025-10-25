import 'dart:collection';

/// Simple TTL-based alarm deduplication.
/// 
/// **Purpose**: Prevents duplicate alarms from firing in rapid succession.
/// This is critical for preventing alarm spam when GPS signals are noisy or
/// when the same alarm condition is evaluated multiple times quickly.
///
/// **How it works**: 
/// 1. When an alarm wants to fire, it checks `shouldFire(key)`
/// 2. If the same key fired within the TTL window, returns false (suppress)
/// 3. Otherwise, records the current time and returns true (allow)
///
/// **Key composition**: 
/// - Keys are arbitrary strings (e.g., "destination:lat,lng", "transfer:routeId")
/// - Caller is responsible for making keys unique enough to prevent
///   suppressing different alarms, but similar enough to catch duplicates
///
/// **Example**:
/// ```dart
/// final dedup = AlarmDeduplicator(ttl: Duration(seconds: 8));
/// 
/// // First attempt - fires
/// if (dedup.shouldFire('destination:37.123,-122.456')) {
///   showAlarm();
/// }
/// 
/// // Second attempt 2 seconds later - suppressed
/// if (dedup.shouldFire('destination:37.123,-122.456')) {
///   // This won't execute
/// }
/// 
/// // After 8+ seconds - fires again
/// ```
class AlarmDeduplicator {
  /// Time-to-live: how long to suppress duplicates
  /// After this duration, the same key can fire again
  final Duration ttl;
  
  /// Clock provider (injectable for testing)
  final DateTime Function() _now;
  
  /// Map of alarm key -> last fire timestamp
  /// Used to check if alarm was recently fired
  final _lastFire = HashMap<String, DateTime>();

  /// Creates deduplicator with specified TTL
  /// 
  /// In test mode you can supply a custom clock for deterministic testing:
  /// ```dart
  /// var fakeTime = DateTime(2024, 1, 1);
  /// final dedup = AlarmDeduplicator(
  ///   ttl: Duration(seconds: 8),
  ///   now: () => fakeTime,
  /// );
  /// ```
  AlarmDeduplicator({
    required this.ttl,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// Returns true if the alarm should fire (not recently fired / expired),
  /// false if it should be suppressed.
  ///
  /// **Side effect**: If returning true, records current time for this key.
  /// This means calling shouldFire twice in succession will return false
  /// the second time (which is intentional behavior).
  ///
  /// **Thread safety**: Not thread-safe. Assumes single-threaded evaluation
  /// of alarm conditions (typical in Flutter isolate model).
  bool shouldFire(String key) {
    final t = _now();
    final last = _lastFire[key];
    if (last != null && t.difference(last) < ttl) {
      return false; // still within suppression window
    }
    _lastFire[key] = t;
    return true;
  }

  /// Clears all recorded entries (mainly for tests or trip reset).
  /// 
  /// **Usage**:
  /// - Call at start of new tracking session to prevent old alarms from
  ///   affecting new session
  /// - Call in tests to reset state between test cases
  void reset() => _lastFire.clear();
  
  /// For debugging: returns number of tracked keys
  int get trackedKeyCount => _lastFire.length;
  
  /// For debugging: returns all tracked keys
  Set<String> get trackedKeys => _lastFire.keys.toSet();
}
