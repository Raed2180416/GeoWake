/// Simple in-memory metrics registry for counters, gauges, histograms.
/// Lightweight: no external sinks; used for tests & diagnostics.
class MetricsRegistry {
  static final MetricsRegistry _instance = MetricsRegistry._internal();
  factory MetricsRegistry() => _instance;
  MetricsRegistry._internal();

  final Map<String, int> _counters = {};
  final Map<String, double> _gauges = {};
  final Map<String, _Histogram> _histograms = {};

  void inc(String name, [int by = 1]) {
    _counters.update(name, (v) => v + by, ifAbsent: () => by);
  }

  int getCounter(String name) => _counters[name] ?? 0;

  void gauge(String name, double value) {
    _gauges[name] = value;
  }

  double? getGauge(String name) => _gauges[name];

  void observe(String name, double value) {
    _histograms.putIfAbsent(name, () => _Histogram()).observe(value);
  }

  HistogramSnapshot? getHistogram(String name) => _histograms[name]?.snapshot();

  void clear() {
    _counters.clear();
    _gauges.clear();
    _histograms.clear();
  }
}

class _Histogram {
  final List<double> _values = [];
  void observe(double v) { _values.add(v); }
  HistogramSnapshot snapshot() {
    if (_values.isEmpty) return HistogramSnapshot(count: 0, min: 0, max: 0, p50: 0, p95: 0, p99: 0, mean: 0);
    final sorted = [..._values]..sort();
    double pct(double p) => sorted[((p * (sorted.length - 1)).clamp(0, sorted.length - 1)).round()];
    final sum = sorted.fold<double>(0, (a,b)=>a+b);
    return HistogramSnapshot(
      count: sorted.length,
      min: sorted.first,
      max: sorted.last,
      mean: sum / sorted.length,
      p50: pct(0.50),
      p95: pct(0.95),
      p99: pct(0.99),
    );
  }
}

class HistogramSnapshot {
  final int count; final double min; final double max; final double mean; final double p50; final double p95; final double p99;
  HistogramSnapshot({required this.count, required this.min, required this.max, required this.mean, required this.p50, required this.p95, required this.p99});
}
