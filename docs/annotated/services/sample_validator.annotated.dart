/// sample_validator.dart: Source file from lib/lib/services/sample_validator.dart
/// 
/// This annotated version provides detailed documentation for all classes, methods, and fields.

import 'package:geolocator/geolocator.dart';
import 'package:geowake2/services/metrics/app_metrics.dart';

/// Result of validation (either accepted original position or rejected with reason)
class SampleValidationResult {
  /// [Brief description of this field]
  final bool accepted;
  /// [Brief description of this field]
  final Position? position;
  /// [Brief description of this field]
  final String? reason; // reason code when rejected
  /// accept: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  SampleValidationResult.accept(this.position)
      : accepted = true,
        reason = null;
  /// reject: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  SampleValidationResult.reject(this.reason)
      : accepted = false,
        position = null;
}

/// Stateful validator to protect downstream ETA / deviation logic from noisy GPS.
class SampleValidator {
  /// [Brief description of this field]
  final Duration staleThreshold;
  /// [Brief description of this field]
  final double maxAccuracyMeters;
  /// [Brief description of this field]
  final double maxSpeedMps; // absolute max plausible speed
  /// [Brief description of this field]
  final double maxAccelMps2; // acceleration threshold between successive samples
  /// [Brief description of this field]
  final int maxBuffer; // number of recent samples retained for quick heuristics

  Position? _lastAccepted;
  double? _lastSpeed;
  /// [Brief description of this field]
  final List<Position> _buf = [];

  SampleValidator({
    this.staleThreshold = const Duration(seconds: 12),
    this.maxAccuracyMeters = 80,
    this.maxSpeedMps = 90, // ~324 km/h
    this.maxAccelMps2 = 13, // generous high-performance acceleration
    this.maxBuffer = 30,
  });

  /// validate: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  SampleValidationResult validate(Position p, DateTime now) {
    try {
      // 1. Staleness
      /// if: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      if (now.difference(p.timestamp) > staleThreshold) {
        /// inc: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        AppMetrics.I.inc('sample_reject_stale');
        /// reject: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        return SampleValidationResult.reject('stale');
      }
      // 2. Accuracy (if available)
      /// if: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      if (p.accuracy.isFinite && p.accuracy > maxAccuracyMeters) {
        /// inc: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        AppMetrics.I.inc('sample_reject_accuracy');
        /// reject: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        return SampleValidationResult.reject('accuracy');
      }
      // 3. Absolute speed cap
      /// if: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      if (p.speed.isFinite && p.speed > maxSpeedMps) {
        /// inc: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        AppMetrics.I.inc('sample_reject_speed');
        /// reject: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        return SampleValidationResult.reject('speed');
      }
      // 4. Acceleration check
      /// if: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      if (_lastAccepted != null && _lastSpeed != null && p.speed.isFinite) {
        /// difference: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        final dt = p.timestamp.difference(_lastAccepted!.timestamp).inMilliseconds / 1000.0;
        /// if: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        if (dt > 0) {
          /// abs: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          final accel = (p.speed - _lastSpeed!).abs() / dt;
          /// if: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          if (accel > maxAccelMps2) {
            /// inc: [Brief description of what this function does]
            /// 
            /// **Parameters**: [Describe parameters if any]
            /// **Returns**: [Describe return value]
            AppMetrics.I.inc('sample_reject_accel');
            /// reject: [Brief description of what this function does]
            /// 
            /// **Parameters**: [Describe parameters if any]
            /// **Returns**: [Describe return value]
            return SampleValidationResult.reject('accel');
          }
        }
      }
      // 5. Teleport (great-circle distance relative to plausible motion)
      /// if: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      if (_lastAccepted != null) {
        /// difference: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        final dt = p.timestamp.difference(_lastAccepted!.timestamp).inMilliseconds / 1000.0;
        /// if: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        if (dt > 0) {
          /// distanceBetween: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          final dist = Geolocator.distanceBetween(
              _lastAccepted!.latitude, _lastAccepted!.longitude, p.latitude, p.longitude);
          /// [Brief description of this field]
          final impliedSpeed = dist / dt;
          /// if: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          if (impliedSpeed > maxSpeedMps * 1.2) { // slack
            /// inc: [Brief description of what this function does]
            /// 
            /// **Parameters**: [Describe parameters if any]
            /// **Returns**: [Describe return value]
            AppMetrics.I.inc('sample_reject_jump');
            /// reject: [Brief description of what this function does]
            /// 
            /// **Parameters**: [Describe parameters if any]
            /// **Returns**: [Describe return value]
            return SampleValidationResult.reject('jump');
          }
        }
      }

      // Accept
      _lastAccepted = p;
      _lastSpeed = p.speed.isFinite ? p.speed : _lastSpeed;
      /// add: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      _buf.add(p);
      /// if: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      if (_buf.length > maxBuffer) _buf.removeAt(0);
      /// inc: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      AppMetrics.I.inc('sample_accept');
      /// accept: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      return SampleValidationResult.accept(p);
    /// catch: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    } catch (_) {
      // On error, be conservative: reject to avoid poisoning pipelines
      /// inc: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      AppMetrics.I.inc('sample_reject_internal');
      /// reject: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      return SampleValidationResult.reject('internal');
    }
  }

  /// unmodifiable: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  List<Position> get recent => List.unmodifiable(_buf);
  Position? get lastAccepted => _lastAccepted;
}
