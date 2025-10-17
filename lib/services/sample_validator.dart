import 'package:geolocator/geolocator.dart';
import 'package:geowake2/services/metrics/app_metrics.dart';

/// Result of validation (either accepted original position or rejected with reason)
class SampleValidationResult {
  final bool accepted;
  final Position? position;
  final String? reason; // reason code when rejected
  SampleValidationResult.accept(this.position)
      : accepted = true,
        reason = null;
  SampleValidationResult.reject(this.reason)
      : accepted = false,
        position = null;
}

/// Stateful validator to protect downstream ETA / deviation logic from noisy GPS.
class SampleValidator {
  final Duration staleThreshold;
  final double maxAccuracyMeters;
  final double maxSpeedMps; // absolute max plausible speed
  final double maxAccelMps2; // acceleration threshold between successive samples
  final int maxBuffer; // number of recent samples retained for quick heuristics

  Position? _lastAccepted;
  double? _lastSpeed;
  final List<Position> _buf = [];

  SampleValidator({
    this.staleThreshold = const Duration(seconds: 12),
    this.maxAccuracyMeters = 80,
    this.maxSpeedMps = 90, // ~324 km/h
    this.maxAccelMps2 = 13, // generous high-performance acceleration
    this.maxBuffer = 30,
  });

  SampleValidationResult validate(Position p, DateTime now) {
    try {
      // 1. Staleness
      if (now.difference(p.timestamp) > staleThreshold) {
        AppMetrics.I.inc('sample_reject_stale');
        return SampleValidationResult.reject('stale');
      }
      // 2. Accuracy (if available)
      if (p.accuracy.isFinite && p.accuracy > maxAccuracyMeters) {
        AppMetrics.I.inc('sample_reject_accuracy');
        return SampleValidationResult.reject('accuracy');
      }
      // 3. Absolute speed cap
      if (p.speed.isFinite && p.speed > maxSpeedMps) {
        AppMetrics.I.inc('sample_reject_speed');
        return SampleValidationResult.reject('speed');
      }
      // 4. Acceleration check
      if (_lastAccepted != null && _lastSpeed != null && p.speed.isFinite) {
        final dt = p.timestamp.difference(_lastAccepted!.timestamp).inMilliseconds / 1000.0;
        if (dt > 0) {
          final accel = (p.speed - _lastSpeed!).abs() / dt;
          if (accel > maxAccelMps2) {
            AppMetrics.I.inc('sample_reject_accel');
            return SampleValidationResult.reject('accel');
          }
        }
      }
      // 5. Teleport (great-circle distance relative to plausible motion)
      if (_lastAccepted != null) {
        final dt = p.timestamp.difference(_lastAccepted!.timestamp).inMilliseconds / 1000.0;
        if (dt > 0) {
          final dist = Geolocator.distanceBetween(
              _lastAccepted!.latitude, _lastAccepted!.longitude, p.latitude, p.longitude);
          final impliedSpeed = dist / dt;
          if (impliedSpeed > maxSpeedMps * 1.2) { // slack
            AppMetrics.I.inc('sample_reject_jump');
            return SampleValidationResult.reject('jump');
          }
        }
      }

      // Accept
      _lastAccepted = p;
      _lastSpeed = p.speed.isFinite ? p.speed : _lastSpeed;
      _buf.add(p);
      if (_buf.length > maxBuffer) _buf.removeAt(0);
      AppMetrics.I.inc('sample_accept');
      return SampleValidationResult.accept(p);
    } catch (_) {
      // On error, be conservative: reject to avoid poisoning pipelines
      AppMetrics.I.inc('sample_reject_internal');
      return SampleValidationResult.reject('internal');
    }
  }

  List<Position> get recent => List.unmodifiable(_buf);
  Position? get lastAccepted => _lastAccepted;
}
