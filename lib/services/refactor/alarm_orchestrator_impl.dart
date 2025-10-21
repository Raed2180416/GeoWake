import 'dart:async';
import 'dart:math';

import 'interfaces.dart';
import 'location_types.dart';
import '../../logging/app_logger.dart';
import '../transfer_utils.dart';
import '../metrics/metrics.dart';
import '../metrics/app_metrics.dart';

/// First extracted implementation of AlarmOrchestrator.
/// Scope (phase 1):
/// - Distance & time & stops thresholds (single destination)
/// - Time eligibility gating (min samples + movement)
/// - Proximity stability (consecutive passes + dwell) mirroring legacy semantics
/// - Emits TRIGGERED once; ELIGIBILITY_CHANGED when time eligibility flips
/// - No event (transfer) alarms yet; no fallback OS scheduling
class AlarmOrchestratorImpl implements AlarmOrchestrator {
  final _eventsCtrl = StreamController<AlarmEvent>.broadcast();
  @override
  Stream<AlarmEvent> get events$ => _eventsCtrl.stream;

  DestinationSpec? _destination;
  AlarmConfig? _config;
  double? _totalRouteMeters; // optional hint for progress ratio (future use)
  double? _totalStops; // total cumulative stops (injected via configure extension?)
  bool _proximityGatingEnabled = true; // allow disabling during parity harness
  List<RouteEventBoundary> _routeEvents = const [];
  int _nextEventIndex = 0; // pointer to upcoming event
  double _eventTriggerWindowMeters = 30; // window before event to fire

  // Time eligibility gating state
  DateTime? _startedAt;
  LocationSample? _firstSample;
  int _etaSamples = 0;
  bool _timeEligible = false;

  // Proximity dwell gating
  int _proximityPasses = 0;
  DateTime? _firstPassAt;
  final int _requiredPasses; // 3 in legacy
  final Duration _minDwell; // 4s in legacy

  bool _fired = false;
  // Emission throttling (TTL suppression) for repeated events (TRIGGERED / EVENT_ALARM)
  final Map<String, DateTime> _lastEmitAt = {};
  Duration emitTTL = const Duration(seconds: 10);
  // Simple persistence exposure
  Map<String, dynamic> toState() => {
        'timeEligible': _timeEligible,
        'etaSamples': _etaSamples,
        'fired': _fired,
        'proximityPasses': _proximityPasses,
        'firstPassAt': _firstPassAt?.toIso8601String(),
        'nextEventIndex': _nextEventIndex,
      };
  void restoreState(Map<String, dynamic> m) {
    try {
      _timeEligible = m['timeEligible'] == true;
      _etaSamples = (m['etaSamples'] as num?)?.toInt() ?? _etaSamples;
      _fired = m['fired'] == true;
      _proximityPasses = (m['proximityPasses'] as num?)?.toInt() ?? 0;
      final fpa = m['firstPassAt'] as String?;
      if (fpa != null) _firstPassAt = DateTime.tryParse(fpa);
      _nextEventIndex = (m['nextEventIndex'] as num?)?.toInt() ?? 0;
    } catch (e) {
      AppLogger.I.warn('Failed to restore alarm orchestrator state', 
        domain: 'alarm', context: {'error': e.toString()});
    }
  }

  AlarmOrchestratorImpl({int requiredPasses = 3, Duration minDwell = const Duration(seconds: 4)})
      : _requiredPasses = requiredPasses,
        _minDwell = minDwell;

  @override
  void configure(AlarmConfig config) {
    _config = config;
  }

  @override
  void registerDestination(DestinationSpec spec) {
    _destination = spec;
    _startedAt = DateTime.now();
    _etaSamples = 0;
    _timeEligible = false;
    _fired = false;
    _proximityPasses = 0;
    _firstPassAt = null;
    _nextEventIndex = 0;
  }

  @override
  void update({required LocationSample sample, required SnappedPosition? snapped}) {
    final sw = Stopwatch()..start();
    if (_destination == null || _config == null || _fired) return;
    _firstSample ??= sample;

    // Safe unwrap with runtime assertion - should never be null due to check above
    final cfg = _config;
    final dest = _destination;
    if (cfg == null || dest == null) {
      AppLogger.I.error('Config or destination unexpectedly null in update', domain: 'alarm');
      return;
    }

    final distMeters = _distanceMeters(sample.lat, sample.lng, dest.lat, dest.lng);

    // Naive ETA (straight line / speed) for time threshold eligibility + triggering
    double? etaSeconds;
    if (sample.speedMps > 0.5) {
      etaSeconds = distMeters / max(sample.speedMps, 0.5);
      _etaSamples++;
    }

    // Evaluate time eligibility (mirrors legacy conditions – distance since start + samples + min time)
    if (!_timeEligible && cfg.timeETALimitSeconds > 0) {
      try {
        final firstSample = _firstSample;
        final moved = firstSample != null
            ? _distanceMeters(firstSample.lat, firstSample.lng, sample.lat, sample.lng)
            : 0.0;
        final sinceStart = _startedAt != null ? DateTime.now().difference(_startedAt!) : Duration.zero;
        if (moved >= cfg.minTimeEligibilityDistanceMeters && _etaSamples >= cfg.minEtaSamples && sinceStart >= cfg.minTimeEligibilitySinceStart) {
          _timeEligible = true;
          _emit('ELIGIBILITY_CHANGED', {'timeEligible': true});
        }
      } catch (e) {
        AppLogger.I.warn('Error checking time eligibility', 
          domain: 'alarm', context: {'error': e.toString()});
      }
    }

    bool inside = false;
    if (cfg.distanceThresholdMeters > 0) {
      inside = inside || distMeters <= cfg.distanceThresholdMeters;
    }
    if (cfg.timeETALimitSeconds > 0 && etaSeconds != null && _timeEligible) {
      inside = inside || etaSeconds <= cfg.timeETALimitSeconds;
    }
    if (cfg.stopsThreshold > 0 && snapped != null && _totalStops != null && _totalStops! > 0) {
      // Approximate remaining stops using snapped.progressMeters -> progress ratio -> stops.
      final totalRouteMeters = _totalRouteMeters;
      final totalStops = _totalStops;
      if (totalRouteMeters != null && totalRouteMeters > 0 && totalStops != null && totalStops > 0) {
        final ratio = (snapped.progressMeters / totalRouteMeters).clamp(0.0, 1.0);
        final coveredStops = ratio * totalStops;
        final remainingStops = totalStops - coveredStops;
        if (remainingStops <= cfg.stopsThreshold) {
          inside = true;
        }
      }
    }

    if (inside) {
      if (_proximityGatingEnabled) {
        _proximityPasses += 1;
        _firstPassAt ??= DateTime.now();
        final firstPassAt = _firstPassAt;
        final dwellOk = firstPassAt != null && DateTime.now().difference(firstPassAt) >= _minDwell;
        final passesOk = _proximityPasses >= _requiredPasses;
        if (dwellOk && passesOk) {
          _fire(distMeters: distMeters, etaSeconds: etaSeconds);
        }
      } else {
        _fire(distMeters: distMeters, etaSeconds: etaSeconds);
      }
    } else {
      // Reset gating
      if (_proximityPasses > 0) {
        _proximityPasses = 0;
        _firstPassAt = null;
      }
    }

    // Event alarm evaluation (does not interfere with destination alarm firing)
    if (snapped != null && _routeEvents.isNotEmpty && _nextEventIndex < _routeEvents.length) {
      final nextEv = _routeEvents[_nextEventIndex];
      final progress = snapped.progressMeters;
      final remainingToEvent = nextEv.meters - progress;
      if (remainingToEvent <= _eventTriggerWindowMeters) {
        _emit('EVENT_ALARM', {
          'eventType': nextEv.type,
          'label': nextEv.label,
          'metersFromStart': nextEv.meters,
          'remainingToEvent': remainingToEvent,
        });
        MetricsRegistry.I.counter('alarm.event').inc();
        _nextEventIndex += 1; // move to following event
      }
    }
    sw.stop();
    MetricsRegistry.I.duration('orchestrator.update').record(sw.elapsed);
  }

  void _fire({required double distMeters, double? etaSeconds}) {
    if (_fired) return;
    _fired = true;
    _emit('TRIGGERED', {
      'distanceMeters': distMeters,
      if (etaSeconds != null) 'etaSeconds': etaSeconds,
      'destination': _destination?.name,
    });
    AppLogger.I.info('Alarm triggered', domain: 'alarm', context: {'dist': distMeters, 'dest': _destination?.name});
    MetricsRegistry.I.counter('alarm.triggered').inc();
  }

  void _emit(String type, Map<String, dynamic> data) {
    final now = DateTime.now();
    final key = type + (data['eventType'] != null ? ':${data['eventType']}' : '') + (data['label'] != null ? ':${data['label']}' : '');
    final prev = _lastEmitAt[key];
    if (prev != null && now.difference(prev) < emitTTL) {
      // Suppressed duplicate within TTL
      AppMetrics.I.inc('orchestrator_suppressed');
      return;
    }
    _lastEmitAt[key] = now;
    _eventsCtrl.add(AlarmEvent(type, now, data));
    AppMetrics.I.inc('orchestrator_emit');
  }

  @override
  void reset() {
    _fired = false;
    _proximityPasses = 0;
    _firstPassAt = null;
    _etaSamples = 0;
    _timeEligible = false;
    _firstSample = null;
    _nextEventIndex = 0;
  }
  
  /// Dispose of resources to prevent memory leaks.
  void dispose() {
    if (!_eventsCtrl.isClosed) {
      _eventsCtrl.close();
    }
  }

  // Temporary injection utilities until full route manager wiring is in place
  void setTotalRouteMeters(double meters) => _totalRouteMeters = meters;
  void setTotalStops(double stops) => _totalStops = stops;
  void setProximityGatingEnabled(bool enabled) => _proximityGatingEnabled = enabled;
  void setRouteEvents(List<RouteEventBoundary> events) {
    _routeEvents = events..sort((a,b)=>a.meters.compareTo(b.meters));
    _nextEventIndex = 0;
  }
  void setEventTriggerWindowMeters(double meters) => _eventTriggerWindowMeters = meters;

  double _distanceMeters(double lat1, double lon1, double lat2, double lon2) {
    // Fast equirectangular approximation (good enough for thresholds of hundreds of meters)
    const double R = 6371000; // meters
    final x = _deg2rad(lon2 - lon1) * cos(_deg2rad((lat1 + lat2) / 2));
    final y = _deg2rad(lat2 - lat1);
    return sqrt(x * x + y * y) * R;
  }

  double _deg2rad(double deg) => deg * pi / 180.0;
}
