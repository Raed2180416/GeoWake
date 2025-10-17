import 'dart:math';

import 'package:collection/collection.dart';
import '../config/alarm_thresholds.dart';

/// Maintains a rolling window of recent speed samples and classifies movement
/// mode (walk vs drive) plus produces a smoothed representative speed for ETA.
class MovementClassifier {
  final int capacity;
  final List<double> _speeds = <double>[];
  String _mode = 'walk';

  MovementClassifier({this.capacity = 10});

  void add(double rawSpeedMps) {
    final t = ThresholdsProvider.current;
    final s = rawSpeedMps.isFinite && rawSpeedMps >= 0 ? rawSpeedMps : 0.0;
    // Treat noise
    final filtered = s < t.gpsNoiseFloorMps ? 0.0 : s;
    _speeds.add(filtered);
    if (_speeds.length > capacity) {
      _speeds.removeAt(0);
    }
    _recomputeMode();
  }

  void _recomputeMode() {
    final t = ThresholdsProvider.current;
    if (_speeds.isEmpty) return;
    // Use median to resist spikes
    final median = _median(_speeds);
    // Hysteresis: only switch if clear boundary crossed relative to current mode
    if (_mode == 'walk') {
      if (median >= t.driveSpeedLowerMps) {
        _mode = 'drive';
      }
    } else { // drive
      if (median <= t.walkSpeedUpperMps) {
        _mode = 'walk';
      }
    }
  }

  String get mode => _mode;

  /// Returns a representative speed (median of non-zero samples) falling back
  /// to configured mode fallback speeds if insufficient data.
  double representativeSpeed() {
    final t = ThresholdsProvider.current;
    final usable = _speeds.where((s) => s > 0).toList();
    if (usable.length < 2) {
      return _mode == 'drive' ? t.fallbackDriveMps : t.fallbackWalkMps;
    }
    final med = _median(usable);
    // Clamp: discard implausible spikes ( > 120 km/h )
    final clamped = med.clamp(0.0, 33.0); // 33 m/s ~ 119 km/h
    // Ensure reasonable floor per mode
    final floor = _mode == 'drive' ? t.fallbackDriveMps * 0.6 : t.fallbackWalkMps * 0.5;
    return max(clamped, floor);
  }

  static double _median(List<double> list) {
    if (list.isEmpty) return 0.0;
    final sorted = list.sorted((a,b)=>a.compareTo(b));
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[mid];
    return (sorted[mid-1] + sorted[mid]) / 2.0;
  }
}
