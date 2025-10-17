import 'dart:collection';

/// Simple TTL-based alarm deduplication.
/// Keys are arbitrary (e.g., composed from title+body or an alarm category).
/// If an alarm with the same key fires within [ttl], it is suppressed.
class AlarmDeduplicator {
  final Duration ttl;
  final DateTime Function() _now;
  final _lastFire = HashMap<String, DateTime>();

  /// In test mode you can supply a custom clock.
  AlarmDeduplicator({
    required this.ttl,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// Returns true if the alarm should fire (not recently fired / expired),
  /// false if it should be suppressed.
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
  void reset() => _lastFire.clear();
}
