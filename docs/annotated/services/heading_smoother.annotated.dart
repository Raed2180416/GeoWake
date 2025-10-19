/// heading_smoother.dart: Source file from lib/lib/services/heading_smoother.dart
/// 
/// This annotated version provides detailed documentation for all classes, methods, and fields.


/// Exponential moving average heading smoother with wrap-around handling
/// and maximum turn-rate clamping (deg/sec) to reduce jitter & hairpin spikes.
class HeadingSmoother {
  double? _smoothed; // degrees 0..360
  DateTime? _lastTs;
  /// [Brief description of this field]
  final double emaAlphaFast;
  /// [Brief description of this field]
  final double emaAlphaSlow;
  /// [Brief description of this field]
  final double maxTurnRateDegPerSec; // cap on instantaneous turn rate applied to delta
  /// [Brief description of this field]
  final Duration resetIfIdle; // idle gap -> reset smoothing

  HeadingSmoother({
    this.emaAlphaFast = 0.5,
    this.emaAlphaSlow = 0.15,
    this.maxTurnRateDegPerSec = 180, // allow up to half-turn per second by default
    this.resetIfIdle = const Duration(seconds: 8),
  });

  /// update: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  double update(double rawHeadingDeg, DateTime ts, {double? speedMps}) {
    /// _norm: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    rawHeadingDeg = _norm(rawHeadingDeg);
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (_smoothed == null || _lastTs == null) {
      _smoothed = rawHeadingDeg;
      _lastTs = ts;
      return _smoothed!;
    }
    /// difference: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    final dt = ts.difference(_lastTs!);
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (dt.isNegative) {
      // Clock anomaly, reset
      _smoothed = rawHeadingDeg;
      _lastTs = ts;
      return _smoothed!;
    }
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (dt >= resetIfIdle) {
      _smoothed = rawHeadingDeg;
      _lastTs = ts;
      return _smoothed!;
    }
    // Compute shortest angular difference (-180,180]
    /// _shortestDiff: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    double diff = _shortestDiff(_smoothed!, rawHeadingDeg);
    /// [Brief description of this field]
    final seconds = dt.inMilliseconds / 1000.0;
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (seconds > 0) {
      /// [Brief description of this field]
      final maxDelta = maxTurnRateDegPerSec * seconds;
      /// if: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      if (diff.abs() > maxDelta) {
        diff = diff.sign * maxDelta;
      }
    }
    // Adaptive alpha: faster when device moving faster to catch genuine direction changes
    final alpha = (speedMps != null && speedMps > 4.0)
        ? emaAlphaFast
        : emaAlphaSlow; // slower smoothing for low speed / jitter
    /// [Brief description of this field]
    final next = _smoothed! + diff * alpha;
    /// _norm: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    _smoothed = _norm(next);
    _lastTs = ts;
    return _smoothed!;
  }

  double? get current => _smoothed;

  /// reset: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  void reset() { _smoothed = null; _lastTs = null; }

  /// _norm: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  static double _norm(double d) {
    d %= 360.0;
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (d < 0) d += 360.0;
    return d;
  }

  /// _shortestDiff: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  static double _shortestDiff(double from, double to) {
    double diff = (to - from) % 360.0;
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (diff > 180) diff -= 360.0;
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (diff <= -180) diff += 360.0;
    return diff;
  }
}
