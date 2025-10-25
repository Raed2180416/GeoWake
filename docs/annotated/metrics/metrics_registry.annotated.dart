/// Simple in-memory metrics registry for counters, gauges, histograms.
/// Lightweight: no external sinks; used for tests & diagnostics.
/// 
/// **Purpose**: Provides a lightweight metrics collection system for monitoring application
/// behavior during tests and diagnostics. Unlike production metrics systems that send data
/// to external services, this registry keeps everything in memory for immediate inspection.
/// 
/// **Key Features**:
/// - Counters: Track event occurrences (incremental values)
/// - Gauges: Track current state values (snapshots)
/// - Histograms: Track value distributions with percentile calculations
/// 
/// **Usage**: Access via singleton pattern. Call inc() to increment counters, gauge() to 
/// record current values, and observe() to add samples to histograms.
/// 
/// **Example**:
/// ```dart
/// MetricsRegistry().inc('api_calls');
/// MetricsRegistry().gauge('active_sessions', 3.0);
/// MetricsRegistry().observe('request_latency_ms', 150.0);
/// ```
class MetricsRegistry {
  /// Singleton instance - ensures one registry across the application
  static final MetricsRegistry _instance = MetricsRegistry._internal();
  
  /// Factory constructor returns singleton instance
  factory MetricsRegistry() => _instance;
  
  /// Private constructor for singleton pattern
  MetricsRegistry._internal();

  /// Storage for counter metrics (event counts)
  final Map<String, int> _counters = {};
  
  /// Storage for gauge metrics (current values)
  final Map<String, double> _gauges = {};
  
  /// Storage for histogram metrics (value distributions)
  final Map<String, _Histogram> _histograms = {};

  /// inc: Increment a counter by the specified amount
  /// 
  /// **Parameters**:
  /// - name: Unique identifier for the counter
  /// - by: Amount to increment (default: 1)
  /// 
  /// **Usage**: Track event occurrences
  void inc(String name, [int by = 1]) {
    _counters.update(name, (v) => v + by, ifAbsent: () => by);
  }

  /// getCounter: Retrieve current value of a counter
  /// 
  /// **Parameters**: name - Counter identifier
  /// **Returns**: Current count, or 0 if counter doesn't exist
  int getCounter(String name) => _counters[name] ?? 0;

  /// gauge: Record a gauge value (current state snapshot)
  /// 
  /// **Parameters**:
  /// - name: Unique identifier for the gauge
  /// - value: Current value to record
  /// 
  /// **Usage**: Track instantaneous measurements like active connections, memory usage
  void gauge(String name, double value) {
    _gauges[name] = value;
  }

  /// getGauge: Retrieve current value of a gauge
  /// 
  /// **Parameters**: name - Gauge identifier
  /// **Returns**: Current value, or null if gauge doesn't exist
  double? getGauge(String name) => _gauges[name];

  /// observe: Add a sample to a histogram for distribution analysis
  /// 
  /// **Parameters**:
  /// - name: Unique identifier for the histogram
  /// - value: Sample value to add
  /// 
  /// **Usage**: Track latencies, sizes, or other values where you need percentiles
  void observe(String name, double value) {
    _histograms.putIfAbsent(name, () => _Histogram()).observe(value);
  }

  /// getHistogram: Retrieve histogram snapshot with percentile calculations
  /// 
  /// **Parameters**: name - Histogram identifier
  /// **Returns**: Snapshot with statistics, or null if histogram doesn't exist
  HistogramSnapshot? getHistogram(String name) => _histograms[name]?.snapshot();

  /// clear: Reset all metrics (useful for test isolation)
  /// 
  /// **Purpose**: Removes all stored counters, gauges, and histograms
  void clear() {
    _counters.clear();
    _gauges.clear();
    _histograms.clear();
  }
}

/// _Histogram: Internal histogram implementation for tracking value distributions
/// 
/// **Purpose**: Accumulates samples and calculates percentiles on demand
class _Histogram {
  /// Raw samples storage (sorted for percentile calculation)
  final List<double> _values = [];
  
  /// observe: Add a sample to the histogram
  void observe(double v) { _values.add(v); }
  
  /// snapshot: Generate statistics snapshot from accumulated samples
  /// 
  /// **Returns**: HistogramSnapshot with count, min, max, mean, and percentiles (p50, p95, p99)
  /// 
  /// **Implementation**: Sorts values and uses linear interpolation for percentiles
  HistogramSnapshot snapshot() {
    if (_values.isEmpty) return HistogramSnapshot(count: 0, min: 0, max: 0, p50: 0, p95: 0, p99: 0, mean: 0);
    final sorted = [..._values]..sort();
    
    /// pct: Helper to calculate percentile using linear interpolation
    double pct(double p) => sorted[((p * (sorted.length - 1)).clamp(0, sorted.length - 1)).round()];
    
    final sum = sorted.fold<double>(0, (a,b)=>a+b);
    return HistogramSnapshot(
      count: sorted.length,
      min: sorted.first,
      max: sorted.last,
      mean: sum / sorted.length,
      p50: pct(0.50),  // Median
      p95: pct(0.95),  // 95th percentile
      p99: pct(0.99),  // 99th percentile
    );
  }
}

/// HistogramSnapshot: Immutable statistics snapshot of a histogram
/// 
/// **Purpose**: Provides comprehensive statistics about value distribution
/// 
/// **Fields**:
/// - count: Total number of samples
/// - min: Minimum observed value
/// - max: Maximum observed value
/// - mean: Average value
/// - p50: Median (50th percentile)
/// - p95: 95th percentile (95% of values are below this)
/// - p99: 99th percentile (99% of values are below this)
class HistogramSnapshot {
  /// Total number of samples in the histogram
  final int count;
  
  /// Minimum observed value
  final double min;
  
  /// Maximum observed value
  final double max;
  
  /// Arithmetic mean of all values
  final double mean;
  
  /// Median (50th percentile)
  final double p50;
  
  /// 95th percentile
  final double p95;
  
  /// 99th percentile
  final double p99;
  
  HistogramSnapshot({required this.count, required this.min, required this.max, required this.mean, required this.p50, required this.p95, required this.p99});
}
