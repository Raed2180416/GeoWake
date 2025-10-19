import 'dart:collection';
import 'dart:developer' as dev;

/// Simple TTL-based alarm deduplication with automatic cleanup.
/// Keys are arbitrary (e.g., composed from title+body or an alarm category).
/// If an alarm with the same key fires within [ttl], it is suppressed.
/// 
/// Improvements from audit:
/// - Automatic cleanup of expired entries to prevent unbounded growth
/// - Max size limit as safety net
/// - Logging for monitoring
class AlarmDeduplicator {
  final Duration ttl;
  final int maxEntries;
  final DateTime Function() _now;
  final _lastFire = HashMap<String, DateTime>();
  DateTime? _lastCleanup;

  /// Create an alarm deduplicator with TTL and optional max size.
  /// [ttl] - Time to live for alarm entries
  /// [maxEntries] - Maximum number of entries (default 100)
  /// [now] - Custom clock for testing
  AlarmDeduplicator({
    required this.ttl,
    this.maxEntries = 100,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// Returns true if the alarm should fire (not recently fired / expired),
  /// false if it should be suppressed.
  bool shouldFire(String key) {
    final t = _now();
    
    // Periodic cleanup to prevent unbounded growth
    _cleanupIfNeeded(t);
    
    final last = _lastFire[key];
    if (last != null && t.difference(last) < ttl) {
      return false; // still within suppression window
    }
    
    _lastFire[key] = t;
    
    // Safety check: if we exceed max entries, remove oldest
    if (_lastFire.length > maxEntries) {
      _pruneOldest();
    }
    
    return true;
  }

  /// Clean up expired entries periodically (every 10 minutes).
  void _cleanupIfNeeded(DateTime now) {
    // Only cleanup once every 10 minutes
    if (_lastCleanup != null && 
        now.difference(_lastCleanup!) < const Duration(minutes: 10)) {
      return;
    }
    
    _lastCleanup = now;
    final cutoff = now.subtract(ttl);
    final sizeBefore = _lastFire.length;
    
    _lastFire.removeWhere((key, time) => time.isBefore(cutoff));
    
    final sizeAfter = _lastFire.length;
    if (sizeBefore != sizeAfter) {
      dev.log(
        'Cleaned up alarm deduplication cache: $sizeBefore -> $sizeAfter entries',
        name: 'AlarmDeduplicator'
      );
    }
  }

  /// Remove oldest entries if we exceed max size.
  void _pruneOldest() {
    if (_lastFire.length <= maxEntries) return;
    
    dev.log(
      'Alarm deduplicator exceeded max size ($maxEntries), pruning oldest entries',
      name: 'AlarmDeduplicator'
    );
    
    // Sort by timestamp and remove oldest
    final sorted = _lastFire.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    
    final toRemove = _lastFire.length - maxEntries;
    for (var i = 0; i < toRemove; i++) {
      _lastFire.remove(sorted[i].key);
    }
    
    dev.log(
      'Pruned $toRemove entries, ${_lastFire.length} remain',
      name: 'AlarmDeduplicator'
    );
  }

  /// Clears all recorded entries (mainly for tests or trip reset).
  void reset() {
    dev.log('Resetting alarm deduplication cache', name: 'AlarmDeduplicator');
    _lastFire.clear();
    _lastCleanup = null;
  }
  
  /// Get current cache size (for monitoring/debugging).
  int get cacheSize => _lastFire.length;
}
