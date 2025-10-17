import 'dart:math';

/// IdlePowerScaler determines whether tracking can reduce GPS polling frequency.
/// Heuristics (initial version):
/// - ACTIVE initially until at least `minSamples` processed.
/// - Compute sliding window of last N distances & speeds.
/// - If cumulative distance over window < distanceSlackMeters AND speed median < speedThreshold => IDLE.
/// - Return to ACTIVE immediately upon any position whose distance from last sample > wakeDistanceMeters
///   or speed >= wakeSpeedMps.
class IdlePowerScaler {
  final int windowSize;
  final int minSamples;
  final double distanceSlackMeters; // total movement within window to still consider idle
  final double speedThresholdMps;   // median speed below this implies idle candidate
  final double wakeDistanceMeters;  // any jump beyond => active
  final double wakeSpeedMps;        // any speed beyond => active
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

  final List<_Sample> _samples = [];
  bool _isIdle = false;
  DateTime? _idleCandidateSince;

  bool get isIdle => _isIdle;

  void addSample({required double lat, required double lng, required double speedMps, required DateTime ts}) {
    // Append sample
    _samples.add(_Sample(lat, lng, speedMps, ts));
    if (_samples.length > windowSize) {
      _samples.removeAt(0);
    }

    if (_samples.length < 2) {
      _isIdle = false;
      _idleCandidateSince = null;
      return;
    }

    // Wake conditions immediate
    if (speedMps >= wakeSpeedMps) {
      _isIdle = false;
      _idleCandidateSince = null;
      return;
    }
    final last = _samples[_samples.length - 1];
    final prev = _samples[_samples.length - 2];
    final stepDist = _haversine(prev.lat, prev.lng, last.lat, last.lng);
    if (stepDist >= wakeDistanceMeters) {
      _isIdle = false;
      _idleCandidateSince = null;
      return;
    }

    if (_samples.length < minSamples) {
      _isIdle = false;
      return;
    }

    // Evaluate window stats
    double totalDist = 0.0;
    final speeds = <double>[];
    for (int i = 1; i < _samples.length; i++) {
      totalDist += _haversine(_samples[i - 1].lat, _samples[i - 1].lng, _samples[i].lat, _samples[i].lng);
      speeds.add(_samples[i].speed);
    }
    speeds.sort();
    final medianSpeed = speeds[speeds.length ~/ 2];
    final candidate = totalDist <= distanceSlackMeters && medianSpeed <= speedThresholdMps;
    if (candidate) {
      _idleCandidateSince ??= last.ts;
      if (last.ts.difference(_idleCandidateSince!) >= idleMinDuration) {
        _isIdle = true;
      }
    } else {
      _idleCandidateSince = null;
      _isIdle = false;
    }
  }

  static double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000.0; // meters
    double dLat = _deg2rad(lat2 - lat1);
    double dLon = _deg2rad(lon2 - lon1);
    double a = sin(dLat / 2) * sin(dLat / 2) + cos(_deg2rad(lat1)) * cos(_deg2rad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }
  static double _deg2rad(double d) => d * (pi / 180.0);
}

class _Sample {
  final double lat;
  final double lng;
  final double speed;
  final DateTime ts;
  _Sample(this.lat, this.lng, this.speed, this.ts);
}