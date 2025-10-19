/// idle_power_scaler.dart: Source file from lib/lib/services/idle_power_scaler.dart
/// 
/// This annotated version provides detailed documentation for all classes, methods, and fields.

import 'dart:math';

/// IdlePowerScaler determines whether tracking can reduce GPS polling frequency.
/// Heuristics (initial version):
/// - ACTIVE initially until at least `minSamples` processed.
/// - Compute sliding window of last N distances & speeds.
/// - If cumulative distance over window < distanceSlackMeters AND speed median < speedThreshold => IDLE.
/// - Return to ACTIVE immediately upon any position whose distance from last sample > wakeDistanceMeters
///   or speed >= wakeSpeedMps.
class IdlePowerScaler {
  /// [Brief description of this field]
  final int windowSize;
  /// [Brief description of this field]
  final int minSamples;
  /// [Brief description of this field]
  final double distanceSlackMeters; // total movement within window to still consider idle
  /// [Brief description of this field]
  final double speedThresholdMps;   // median speed below this implies idle candidate
  /// [Brief description of this field]
  final double wakeDistanceMeters;  // any jump beyond => active
  /// [Brief description of this field]
  final double wakeSpeedMps;        // any speed beyond => active
  /// [Brief description of this field]
  final Duration idleMinDuration;   // must remain in candidate idle this long before switching

  IdlePowerScaler({
    this.windowSize = 6,
    this.minSamples = 6,
    this.distanceSlackMeters = 12.0,
    this.speedThresholdMps = 0.7,
    this.wakeDistanceMeters = 25.0,
    this.wakeSpeedMps = 2.2,
    this.idleMinDuration = const Duration(seconds: 20),
  });

  /// [Brief description of this field]
  final List<_Sample> _samples = [];
  bool _isIdle = false;
  DateTime? _idleCandidateSince;

  bool get isIdle => _isIdle;

  /// addSample: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  void addSample({required double lat, required double lng, required double speedMps, required DateTime ts}) {
    // Append sample
    /// add: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    _samples.add(_Sample(lat, lng, speedMps, ts));
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (_samples.length > windowSize) {
      /// removeAt: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      _samples.removeAt(0);
    }

    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (_samples.length < 2) {
      _isIdle = false;
      _idleCandidateSince = null;
      return;
    }

    // Wake conditions immediate
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (speedMps >= wakeSpeedMps) {
      _isIdle = false;
      _idleCandidateSince = null;
      return;
    }
    /// [Brief description of this field]
    final last = _samples[_samples.length - 1];
    /// [Brief description of this field]
    final prev = _samples[_samples.length - 2];
    /// _haversine: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    final stepDist = _haversine(prev.lat, prev.lng, last.lat, last.lng);
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (stepDist >= wakeDistanceMeters) {
      _isIdle = false;
      _idleCandidateSince = null;
      return;
    }

    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (_samples.length < minSamples) {
      _isIdle = false;
      return;
    }

    // Evaluate window stats
    double totalDist = 0.0;
    /// [Brief description of this field]
    final speeds = <double>[];
    /// for: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    for (int i = 1; i < _samples.length; i++) {
      /// _haversine: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      totalDist += _haversine(_samples[i - 1].lat, _samples[i - 1].lng, _samples[i].lat, _samples[i].lng);
      /// add: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      speeds.add(_samples[i].speed);
    }
    /// sort: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    speeds.sort();
    /// [Brief description of this field]
    final medianSpeed = speeds[speeds.length ~/ 2];
    /// [Brief description of this field]
    final candidate = totalDist <= distanceSlackMeters && medianSpeed <= speedThresholdMps;
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (candidate) {
      _idleCandidateSince ??= last.ts;
      /// if: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      if (last.ts.difference(_idleCandidateSince!) >= idleMinDuration) {
        _isIdle = true;
      }
    } else {
      _idleCandidateSince = null;
      _isIdle = false;
    }
  }

  /// _haversine: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  static double _haversine(double lat1, double lon1, double lat2, double lon2) {
    /// [Brief description of this field]
    const R = 6371000.0; // meters
    /// _deg2rad: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    double dLat = _deg2rad(lat2 - lat1);
    /// _deg2rad: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    double dLon = _deg2rad(lon2 - lon1);
    /// sin: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    double a = sin(dLat / 2) * sin(dLat / 2) + cos(_deg2rad(lat1)) * cos(_deg2rad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    /// atan2: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }
  /// _deg2rad: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  static double _deg2rad(double d) => d * (pi / 180.0);
}

/// _Sample: Class for [brief description]
/// 
/// **Purpose**: [What this class does]
/// 
/// **Usage**: [How to use this class]
class _Sample {
  /// [Brief description of this field]
  final double lat;
  /// [Brief description of this field]
  final double lng;
  /// [Brief description of this field]
  final double speed;
  /// [Brief description of this field]
  final DateTime ts;
  /// _Sample: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  _Sample(this.lat, this.lng, this.speed, this.ts);
}