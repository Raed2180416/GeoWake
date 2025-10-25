/// movement_classifier.dart: Source file from lib/lib/services/movement_classifier.dart
/// 
/// This annotated version provides detailed documentation for all classes, methods, and fields.

import 'dart:math';

import 'package:collection/collection.dart';
import '../config/alarm_thresholds.dart';

/// Maintains a rolling window of recent speed samples and classifies movement
/// mode (walk vs drive) plus produces a smoothed representative speed for ETA.
class MovementClassifier {
  /// [Brief description of this field]
  final int capacity;
  /// [Brief description of this field]
  final List<double> _speeds = <double>[];
  String _mode = 'walk';

  MovementClassifier({this.capacity = 10});

  /// add: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  void add(double rawSpeedMps) {
    /// [Brief description of this field]
    final t = ThresholdsProvider.current;
    /// [Brief description of this field]
    final s = rawSpeedMps.isFinite && rawSpeedMps >= 0 ? rawSpeedMps : 0.0;
    // Treat noise
    /// [Brief description of this field]
    final filtered = s < t.gpsNoiseFloorMps ? 0.0 : s;
    /// add: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    _speeds.add(filtered);
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (_speeds.length > capacity) {
      /// removeAt: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      _speeds.removeAt(0);
    }
    /// _recomputeMode: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    _recomputeMode();
  }

  /// _recomputeMode: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  void _recomputeMode() {
    /// [Brief description of this field]
    final t = ThresholdsProvider.current;
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (_speeds.isEmpty) return;
    // Use median to resist spikes
    /// _median: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    final median = _median(_speeds);
    // Hysteresis: only switch if clear boundary crossed relative to current mode
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (_mode == 'walk') {
      /// if: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      if (median >= t.driveSpeedLowerMps) {
        _mode = 'drive';
      }
    } else { // drive
      /// if: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      if (median <= t.walkSpeedUpperMps) {
        _mode = 'walk';
      }
    }
  }

  String get mode => _mode;

  /// Returns a representative speed (median of non-zero samples) falling back
  /// to configured mode fallback speeds if insufficient data.
  double representativeSpeed() {
    /// [Brief description of this field]
    final t = ThresholdsProvider.current;
    /// where: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    final usable = _speeds.where((s) => s > 0).toList();
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (usable.length < 2) {
      return _mode == 'drive' ? t.fallbackDriveMps : t.fallbackWalkMps;
    }
    /// _median: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    final med = _median(usable);
    // Clamp: discard implausible spikes ( > 120 km/h )
    /// clamp: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    final clamped = med.clamp(0.0, 33.0); // 33 m/s ~ 119 km/h
    // Ensure reasonable floor per mode
    /// [Brief description of this field]
    final floor = _mode == 'drive' ? t.fallbackDriveMps * 0.6 : t.fallbackWalkMps * 0.5;
    /// max: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    return max(clamped, floor);
  }

  /// _median: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  static double _median(List<double> list) {
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (list.isEmpty) return 0.0;
    /// sorted: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    final sorted = list.sorted((a,b)=>a.compareTo(b));
    /// [Brief description of this field]
    final mid = sorted.length ~/ 2;
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (sorted.length.isOdd) return sorted[mid];
    /// return: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    return (sorted[mid-1] + sorted[mid]) / 2.0;
  }
}
