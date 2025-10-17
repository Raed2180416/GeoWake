/// Simple in-memory metrics aggregator for Phase 0 baseline.
/// Lightweight; no external deps. Thread-safety: single isolate usage only.

class CounterMetric {
  int _value = 0;
  void inc([int by = 1]) => _value += by;
  int get value => _value;
}

class DurationMetric {
  int _count = 0;
  int _totalMicros = 0;
  int _maxMicros = 0;
  void record(Duration d) {
    final us = d.inMicroseconds;
    _count += 1;
    _totalMicros += us;
    if (us > _maxMicros) _maxMicros = us;
  }
  int get count => _count;
  Duration get total => Duration(microseconds: _totalMicros);
  Duration get max => Duration(microseconds: _maxMicros);
  Duration? get avg => _count == 0 ? null : Duration(microseconds: (_totalMicros ~/ _count));
}

class MetricsRegistry {
  static final MetricsRegistry I = MetricsRegistry._();
  MetricsRegistry._();

  final Map<String, CounterMetric> _counters = {};
  final Map<String, DurationMetric> _durations = {};

  CounterMetric counter(String name) => _counters.putIfAbsent(name, () => CounterMetric());
  DurationMetric duration(String name) => _durations.putIfAbsent(name, () => DurationMetric());

  Map<String, dynamic> snapshot() {
    return {
      'counters': _counters.map((k, v) => MapEntry(k, v.value)),
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
    final snap = snapshot();
    // Very small manual JSON encoding; structure is predictable.
    final counters = (snap['counters'] as Map<String, dynamic>);
    final durations = (snap['durations'] as Map<String, dynamic>);
    String encodeMap(Map<String, dynamic> m) {
      final parts = <String>[];
      m.forEach((k, v) {
        if (v is Map) {
          parts.add('"' + _escape(k) + '":' + encodeMap(v.cast<String, dynamic>()));
        } else if (v == null) {
          parts.add('"' + _escape(k) + '":null');
        } else if (v is num || v is bool) {
          parts.add('"' + _escape(k) + '":' + v.toString());
        } else {
          parts.add('"' + _escape(k) + '":"' + _escape(v.toString()) + '"');
        }
      });
      return '{' + parts.join(',') + '}';
    }
    return '{"counters":' + encodeMap(counters) + ',"durations":' + encodeMap(durations) + '}';
  }

  static String _escape(String s) => s.replaceAll('"', '\\"');
}
