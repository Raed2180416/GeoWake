/// Simple in-memory metrics aggregator for Phase 0 baseline.
/// Lightweight; no external deps. Thread-safety: single isolate usage only.

/// CounterMetric: Class for [brief description]
/// 
/// **Purpose**: [What this class does]
/// 
/// **Usage**: [How to use this class]
class CounterMetric {
  int _value = 0;
  /// inc: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  void inc([int by = 1]) => _value += by;
  int get value => _value;
}

/// DurationMetric: Class for [brief description]
/// 
/// **Purpose**: [What this class does]
/// 
/// **Usage**: [How to use this class]
class DurationMetric {
  int _count = 0;
  int _totalMicros = 0;
  int _maxMicros = 0;
  /// record: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  void record(Duration d) {
    /// [Brief description of this field]
    final us = d.inMicroseconds;
    _count += 1;
    _totalMicros += us;
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (us > _maxMicros) _maxMicros = us;
  }
  int get count => _count;
  Duration get total => Duration(microseconds: _totalMicros);
  Duration get max => Duration(microseconds: _maxMicros);
  Duration? get avg => _count == 0 ? null : Duration(microseconds: (_totalMicros ~/ _count));
}

/// MetricsRegistry: Class for [brief description]
/// 
/// **Purpose**: [What this class does]
/// 
/// **Usage**: [How to use this class]
class MetricsRegistry {
  /// _: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  static final MetricsRegistry I = MetricsRegistry._();
  /// _: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  MetricsRegistry._();

  /// [Brief description of this field]
  final Map<String, CounterMetric> _counters = {};
  /// [Brief description of this field]
  final Map<String, DurationMetric> _durations = {};

  /// counter: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  CounterMetric counter(String name) => _counters.putIfAbsent(name, () => CounterMetric());
  /// duration: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  DurationMetric duration(String name) => _durations.putIfAbsent(name, () => DurationMetric());

  /// snapshot: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Map<String, dynamic> snapshot() {
    return {
      /// map: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      'counters': _counters.map((k, v) => MapEntry(k, v.value)),
      /// map: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      'durations': _durations.map((k, v) => MapEntry(k, {
            'count': v.count,
            'avgMicros': v.avg?.inMicroseconds,
            'maxMicros': v.max.inMicroseconds,
          })),
    };
  }

  /// Serialize current snapshot to a compact JSON string. Avoids adding a JSON dependency by
  /// implementing minimal encoding (keys and primitive values only).
  String toJsonString() {
    /// snapshot: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    final snap = snapshot();
    // Very small manual JSON encoding; structure is predictable.
    final counters = (snap['counters'] as Map<String, dynamic>);
    final durations = (snap['durations'] as Map<String, dynamic>);
    /// encodeMap: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    String encodeMap(Map<String, dynamic> m) {
      /// [Brief description of this field]
      final parts = <String>[];
      /// forEach: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      m.forEach((k, v) {
        /// if: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        if (v is Map) {
          /// add: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          parts.add('"' + _escape(k) + '":' + encodeMap(v.cast<String, dynamic>()));
        /// if: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        } else if (v == null) {
          /// add: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          parts.add('"' + _escape(k) + '":null');
        /// if: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        } else if (v is num || v is bool) {
          /// add: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          parts.add('"' + _escape(k) + '":' + v.toString());
        } else {
          /// add: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          parts.add('"' + _escape(k) + '":"' + _escape(v.toString()) + '"');
        }
      });
      /// join: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      return '{' + parts.join(',') + '}';
    }
    /// encodeMap: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    return '{"counters":' + encodeMap(counters) + ',"durations":' + encodeMap(durations) + '}';
  }

  /// _escape: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  static String _escape(String s) => s.replaceAll('"', '\\"');
}
