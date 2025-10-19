/// logging.dart: Source file from lib/lib/services/trackingservice/logging.dart
/// 
/// This annotated version provides detailed documentation for all classes, methods, and fields.

part of 'package:geowake2/services/trackingservice.dart';

// ------------------ Instrumentation State ------------------
/// LastAlarmEvalSnapshot: Class for [brief description]
/// 
/// **Purpose**: [What this class does]
/// 
/// **Usage**: [How to use this class]
class LastAlarmEvalSnapshot {
  /// [Brief description of this field]
  final int counter;
  /// [Brief description of this field]
  final DateTime ts;
  /// [Brief description of this field]
  final String? mode;
  /// [Brief description of this field]
  final double? remainingMeters;
  /// [Brief description of this field]
  final double? thresholdMeters;
  /// [Brief description of this field]
  final double? remainingStops;
  /// [Brief description of this field]
  final double? thresholdStops;
  /// [Brief description of this field]
  final double? etaSeconds;
  /// [Brief description of this field]
  final double? thresholdEtaSeconds;
  /// [Brief description of this field]
  final double? confidence;
  /// [Brief description of this field]
  final double? volatility;
  /// [Brief description of this field]
  final bool fired;
  /// [Brief description of this field]
  final String reason;
  LastAlarmEvalSnapshot({
    required this.counter,
    required this.ts,
    required this.mode,
    required this.remainingMeters,
    required this.thresholdMeters,
    required this.remainingStops,
    required this.thresholdStops,
    required this.etaSeconds,
    required this.thresholdEtaSeconds,
    required this.confidence,
    required this.volatility,
    required this.fired,
    required this.reason,
  });
  /// toJson: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Map<String, dynamic> toJson() => {
        'counter': counter,
        'ts': ts.millisecondsSinceEpoch,
        'mode': mode,
        'remainingMeters': remainingMeters,
        'thresholdMeters': thresholdMeters,
        'remainingStops': remainingStops,
        'thresholdStops': thresholdStops,
        'etaSeconds': etaSeconds,
        'thresholdEtaSeconds': thresholdEtaSeconds,
        'confidence': confidence,
        'volatility': volatility,
        'fired': fired,
        'reason': reason,
      };
}

// (Removed obsolete snapshot storage & duplicate counters – logging only)
int _alarmEvalCounter = 0;
int _progressSampleCounter = 0;
double? _lastProgressFraction;
int _stagnationSamples = 0;
final int _stagnationSampleWindow = 12; // class-level constant instance
final double _stagnationDeltaFrac = 0.001;

/// _emitLogSchemaOnce: [Brief description of what this function does]
/// 
/// **Parameters**: [Describe parameters if any]
/// **Returns**: [Describe return value]
void _emitLogSchemaOnce() {
  /// if: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  if (TrackingService._logSchemaEmitted) return;
  TrackingService._logSchemaEmitted = true;
  try {
    /// info: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    AppLogger.I.info('LOG_SCHEMA', domain: 'schema', context: {
      'version': '1.0',
      'features': {
        'adaptiveEta': true,
        'orchestrator': TrackingService.useOrchestratorForDestinationAlarm,
        'stopsHeuristicMPerStop': TrackingService.stopsHeuristicMetersPerStop,
      }
    });
  /// catch: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  } catch (_) {}
}

/// _logEvalInterval: [Brief description of what this function does]
/// 
/// **Parameters**: [Describe parameters if any]
/// **Returns**: [Describe return value]
void _logEvalInterval({
  required Duration interval,
  double? remainingMeters,
  double? etaSeconds,
  double? remainingStops,
  double? confidence,
  double? volatility,
  bool immediateHint = false,
}) {
  try {
    /// debug: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    AppLogger.I.debug('EVAL_INTERVAL', domain: 'alarm', context: {
      'mode': _alarmMode,
      'intervalMs': interval.inMilliseconds,
      'remainingMeters': remainingMeters,
      'etaSec': etaSeconds,
      'remainingStops': remainingStops,
      'confidence': confidence,
      'volatility': volatility,
      'immediateHint': immediateHint,
    });
  /// catch: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  } catch (_) {}
}

/// _logAlarmEvalSnapshot: [Brief description of what this function does]
/// 
/// **Parameters**: [Describe parameters if any]
/// **Returns**: [Describe return value]
void _logAlarmEvalSnapshot({
  required bool fired,
  required String reason,
  double? remainingMeters,
  double? thresholdMeters,
  double? remainingStops,
  double? thresholdStops,
  double? etaSeconds,
  double? thresholdEtaSeconds,
}) {
  _alarmEvalCounter += 1;
  final snap = LastAlarmEvalSnapshot(
    counter: _alarmEvalCounter,
    /// now: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    ts: DateTime.now(),
    mode: _alarmMode,
    remainingMeters: remainingMeters,
    thresholdMeters: thresholdMeters,
    remainingStops: remainingStops,
    thresholdStops: thresholdStops,
    etaSeconds: etaSeconds,
    thresholdEtaSeconds: thresholdEtaSeconds,
    confidence: _lastEtaResult?.confidence,
    volatility: _lastEtaResult?.volatility,
    fired: fired,
    reason: reason,
  );
  try {
    /// debug: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    AppLogger.I.debug('ALARM_EVAL', domain: 'alarm', context: snap.toJson());
    try {
      FlutterBackgroundService().invoke('logTail', {
        'level': 'DEBUG',
        'domain': 'alarm',
        'message': 'ALARM_EVAL',
        /// toJson: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        'context': snap.toJson()
      });
    /// catch: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    } catch (_) {}
    // Persist (fire or not) so we always have the latest evaluation context after crash/kill.
    /// _persistLastAlarmEval: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    TrackingService._persistLastAlarmEval(snap.toJson());
  /// catch: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  } catch (_) {}
}

/// _logAlarmGate: [Brief description of what this function does]
/// 
/// **Parameters**: [Describe parameters if any]
/// **Returns**: [Describe return value]
void _logAlarmGate(String gate, Map<String, Object?> ctx) {
  try {
    /// debug: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    AppLogger.I.debug('ALARM_GATE:$gate', domain: 'alarm', context: ctx);
  /// catch: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  } catch (_) {}
  try {
    FlutterBackgroundService().invoke('logTail', {
      'level': 'DEBUG',
      'domain': 'alarm',
      'message': 'ALARM_GATE:$gate',
      'context': ctx
    });
  /// catch: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  } catch (_) {}
}

/// _logAlarmFire: [Brief description of what this function does]
/// 
/// **Parameters**: [Describe parameters if any]
/// **Returns**: [Describe return value]
void _logAlarmFire(String path, {double? remainingMeters, double? remainingStops, double? etaSeconds}) {
  try {
    /// info: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    AppLogger.I.info('ALARM_FIRE', domain: 'alarm', context: {
      'mode': _alarmMode,
      'value': _alarmValue,
      'path': path,
      'remainingMeters': remainingMeters,
      'remainingStops': remainingStops,
      'etaSec': etaSeconds,
      'preBoardingFired': _preBoardingAlertFired,
    });
    try {
      FlutterBackgroundService().invoke('logTail', {
        'level': 'INFO',
        'domain': 'alarm',
        'message': 'ALARM_FIRE',
        'context': {
          'mode': _alarmMode,
          'value': _alarmValue,
          'path': path,
          'remainingMeters': remainingMeters,
          'remainingStops': remainingStops,
          'etaSec': etaSeconds,
          'preBoardingFired': _preBoardingAlertFired,
        }
      });
    /// catch: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    } catch (_) {}
  /// catch: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  } catch (_) {}
}

// (removed) Placeholder for stops integrity previously unused

/// _logProgressSample: [Brief description of what this function does]
/// 
/// **Parameters**: [Describe parameters if any]
/// **Returns**: [Describe return value]
void _logProgressSample(Position p) {
  try {
    final totalMeters = _registry.entries.isNotEmpty ? _registry.entries.first.lengthMeters : null;
    final progress = _lastActiveState?.progressMeters;
    double? frac;
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (totalMeters != null && progress != null && totalMeters > 0) {
      /// clamp: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      frac = (progress / totalMeters).clamp(0.0, 1.0);
    }
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (frac != null) {
      /// if: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      if (_lastProgressFraction != null) {
        /// abs: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        final delta = (frac - _lastProgressFraction!).abs();
        /// if: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        if (delta < _stagnationDeltaFrac) {
          _stagnationSamples += 1;
          /// if: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          if (_stagnationSamples == _stagnationSampleWindow) {
            /// info: [Brief description of what this function does]
            /// 
            /// **Parameters**: [Describe parameters if any]
            /// **Returns**: [Describe return value]
            AppLogger.I.info('PROGRESS_STAGNATION', domain: 'route', context: {
              'samples': _stagnationSamples,
              'frac': frac,
              'deltaThreshold': _stagnationDeltaFrac,
            });
          }
        } else {
          // reset on movement
          /// if: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          if (_stagnationSamples >= _stagnationSampleWindow) {
            /// debug: [Brief description of what this function does]
            /// 
            /// **Parameters**: [Describe parameters if any]
            /// **Returns**: [Describe return value]
            AppLogger.I.debug('STAGNATION_RESET', domain: 'route');
          }
          _stagnationSamples = 0;
        }
      }
    }
    _lastProgressFraction = frac ?? _lastProgressFraction;
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (_progressSampleCounter % 5 == 0) {
      final remainingStraight = (_destination != null)
          /// distanceBetween: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          ? Geolocator.distanceBetween(
              p.latitude,
              p.longitude,
              _destination!.latitude,
              _destination!.longitude,
            )
          : null;
      /// debug: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      AppLogger.I.debug('PROGRESS_SAMPLE', domain: 'route', context: {
        'progressMeters': progress,
        'totalMeters': totalMeters,
        'fraction': frac,
        'straightRemainingM': remainingStraight,
      });
    }
    _progressSampleCounter += 1;
  /// catch: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  } catch (_) {}
}
