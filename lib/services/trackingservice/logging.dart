part of 'package:geowake2/services/trackingservice.dart';

// ------------------ Instrumentation State ------------------
class LastAlarmEvalSnapshot {
  final int counter;
  final DateTime ts;
  final String? mode;
  final double? remainingMeters;
  final double? thresholdMeters;
  final double? remainingStops;
  final double? thresholdStops;
  final double? etaSeconds;
  final double? thresholdEtaSeconds;
  final double? confidence;
  final double? volatility;
  final bool fired;
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

void _emitLogSchemaOnce() {
  if (TrackingService._logSchemaEmitted) return;
  TrackingService._logSchemaEmitted = true;
  try {
    AppLogger.I.info('LOG_SCHEMA', domain: 'schema', context: {
      'version': '1.0',
      'features': {
        'adaptiveEta': true,
        'orchestrator': TrackingService.useOrchestratorForDestinationAlarm,
        'stopsHeuristicMPerStop': TrackingService.stopsHeuristicMetersPerStop,
      }
    });
  } catch (e) {
    AppLogger.I.warn('Operation failed', domain: 'tracking', context: {'error': e.toString()});
  }
}

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
  } catch (e) {
    AppLogger.I.warn('Operation failed', domain: 'tracking', context: {'error': e.toString()});
  }
}

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
    AppLogger.I.debug('ALARM_EVAL', domain: 'alarm', context: snap.toJson());
    try {
      FlutterBackgroundService().invoke('logTail', {
        'level': 'DEBUG',
        'domain': 'alarm',
        'message': 'ALARM_EVAL',
        'context': snap.toJson()
      });
    } catch (e) {
      AppLogger.I.warn('Operation failed', domain: 'tracking', context: {'error': e.toString()});
    }
    // Persist (fire or not) so we always have the latest evaluation context after crash/kill.
    TrackingService._persistLastAlarmEval(snap.toJson());
  } catch (e) {
    AppLogger.I.warn('Operation failed', domain: 'tracking', context: {'error': e.toString()});
  }
}

void _logAlarmGate(String gate, Map<String, Object?> ctx) {
  try {

    AppLogger.I.debug('ALARM_GATE:$gate', domain: 'alarm', context: ctx);

  } catch (e) {

    AppLogger.I.warn('Operation failed', domain: 'tracking', context: {'error': e.toString()});

  }
  try {
    FlutterBackgroundService().invoke('logTail', {
      'level': 'DEBUG',
      'domain': 'alarm',
      'message': 'ALARM_GATE:$gate',
      'context': ctx
    });
  } catch (e) {
    AppLogger.I.warn('Operation failed', domain: 'tracking', context: {'error': e.toString()});
  }
}

void _logAlarmFire(String path, {double? remainingMeters, double? remainingStops, double? etaSeconds}) {
  try {
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
    } catch (e) {
      AppLogger.I.warn('Operation failed', domain: 'tracking', context: {'error': e.toString()});
    }
  } catch (e) {
    AppLogger.I.warn('Operation failed', domain: 'tracking', context: {'error': e.toString()});
  }
}

// (removed) Placeholder for stops integrity previously unused

void _logProgressSample(Position p) {
  try {
    final totalMeters = _registry.entries.isNotEmpty ? _registry.entries.first.lengthMeters : null;
    final progress = _lastActiveState?.progressMeters;
    double? frac;
    if (totalMeters != null && progress != null && totalMeters > 0) {
      frac = (progress / totalMeters).clamp(0.0, 1.0);
    }
    if (frac != null) {
      if (_lastProgressFraction != null) {
        final delta = (frac - _lastProgressFraction!).abs();
        if (delta < _stagnationDeltaFrac) {
          _stagnationSamples += 1;
          if (_stagnationSamples == _stagnationSampleWindow) {
            AppLogger.I.info('PROGRESS_STAGNATION', domain: 'route', context: {
              'samples': _stagnationSamples,
              'frac': frac,
              'deltaThreshold': _stagnationDeltaFrac,
            });
          }
        } else {
          // reset on movement
          if (_stagnationSamples >= _stagnationSampleWindow) {
            AppLogger.I.debug('STAGNATION_RESET', domain: 'route');
          }
          _stagnationSamples = 0;
        }
      }
    }
    _lastProgressFraction = frac ?? _lastProgressFraction;
    if (_progressSampleCounter % 5 == 0) {
      final remainingStraight = (_destination != null)
          ? Geolocator.distanceBetween(
              p.latitude,
              p.longitude,
              _destination!.latitude,
              _destination!.longitude,
            )
          : null;
      AppLogger.I.debug('PROGRESS_SAMPLE', domain: 'route', context: {
        'progressMeters': progress,
        'totalMeters': totalMeters,
        'fraction': frac,
        'straightRemainingM': remainingStraight,
      });
    }
    _progressSampleCounter += 1;
  } catch (e) {
    AppLogger.I.warn('Operation failed', domain: 'tracking', context: {'error': e.toString()});
  }
}
