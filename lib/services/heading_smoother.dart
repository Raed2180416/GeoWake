
/// Exponential moving average heading smoother with wrap-around handling
/// and maximum turn-rate clamping (deg/sec) to reduce jitter & hairpin spikes.
class HeadingSmoother {
  double? _smoothed; // degrees 0..360
  DateTime? _lastTs;
  final double emaAlphaFast;
  final double emaAlphaSlow;
  final double maxTurnRateDegPerSec; // cap on instantaneous turn rate applied to delta
  final Duration resetIfIdle; // idle gap -> reset smoothing

  HeadingSmoother({
    this.emaAlphaFast = 0.5,
    this.emaAlphaSlow = 0.15,
    this.maxTurnRateDegPerSec = 180, // allow up to half-turn per second by default
    this.resetIfIdle = const Duration(seconds: 8),
  });

  double update(double rawHeadingDeg, DateTime ts, {double? speedMps}) {
    rawHeadingDeg = _norm(rawHeadingDeg);
    if (_smoothed == null || _lastTs == null) {
      _smoothed = rawHeadingDeg;
      _lastTs = ts;
      return _smoothed!;
    }
    final dt = ts.difference(_lastTs!);
    if (dt.isNegative) {
      // Clock anomaly, reset
      _smoothed = rawHeadingDeg;
      _lastTs = ts;
      return _smoothed!;
    }
    if (dt >= resetIfIdle) {
      _smoothed = rawHeadingDeg;
      _lastTs = ts;
      return _smoothed!;
    }
    // Compute shortest angular difference (-180,180]
    double diff = _shortestDiff(_smoothed!, rawHeadingDeg);
    final seconds = dt.inMilliseconds / 1000.0;
    if (seconds > 0) {
      final maxDelta = maxTurnRateDegPerSec * seconds;
      if (diff.abs() > maxDelta) {
        diff = diff.sign * maxDelta;
      }
    }
    // Adaptive alpha: faster when device moving faster to catch genuine direction changes
    final alpha = (speedMps != null && speedMps > 4.0)
        ? emaAlphaFast
        : emaAlphaSlow; // slower smoothing for low speed / jitter
    final next = _smoothed! + diff * alpha;
    _smoothed = _norm(next);
    _lastTs = ts;
    return _smoothed!;
  }

  double? get current => _smoothed;

  void reset() { _smoothed = null; _lastTs = null; }

  static double _norm(double d) {
    d %= 360.0;
    if (d < 0) d += 360.0;
    return d;
  }

  static double _shortestDiff(double from, double to) {
    double diff = (to - from) % 360.0;
    if (diff > 180) diff -= 360.0;
    if (diff <= -180) diff += 360.0;
    return diff;
  }
}
