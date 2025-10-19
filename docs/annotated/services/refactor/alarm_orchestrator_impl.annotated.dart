/// alarm_orchestrator_impl.dart: Source file from lib/lib/services/refactor/alarm_orchestrator_impl.dart
/// 
/// This annotated version provides detailed documentation for all classes, methods, and fields.

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
  /// broadcast: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  final _eventsCtrl = StreamController<AlarmEvent>.broadcast();
  @override
  Stream<AlarmEvent> get events$ => _eventsCtrl.stream;

  DestinationSpec? _destination;
  AlarmConfig? _config;
  /// ratio: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  double? _totalRouteMeters; // optional hint for progress ratio (future use)
  /// stops: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
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
  /// [Brief description of this field]
  final int _requiredPasses; // 3 in legacy
  /// [Brief description of this field]
  final Duration _minDwell; // 4s in legacy

  bool _fired = false;
  // Emission throttling (TTL suppression) for repeated events (TRIGGERED / EVENT_ALARM)
  /// [Brief description of this field]
  final Map<String, DateTime> _lastEmitAt = {};
  Duration emitTTL = const Duration(seconds: 10);
  // Simple persistence exposure
  /// toState: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Map<String, dynamic> toState() => {
        'timeEligible': _timeEligible,
        'etaSamples': _etaSamples,
        'fired': _fired,
        'proximityPasses': _proximityPasses,
        /// toIso8601String: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        'firstPassAt': _firstPassAt?.toIso8601String(),
        'nextEventIndex': _nextEventIndex,
      };
  /// restoreState: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  void restoreState(Map<String, dynamic> m) {
    try {
      _timeEligible = m['timeEligible'] == true;
      /// toInt: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      _etaSamples = (m['etaSamples'] as num?)?.toInt() ?? _etaSamples;
      _fired = m['fired'] == true;
      /// toInt: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      _proximityPasses = (m['proximityPasses'] as num?)?.toInt() ?? 0;
      /// [Brief description of this field]
      final fpa = m['firstPassAt'] as String?;
      /// if: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      if (fpa != null) _firstPassAt = DateTime.tryParse(fpa);
      /// toInt: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      _nextEventIndex = (m['nextEventIndex'] as num?)?.toInt() ?? 0;
    /// catch: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    } catch (_) {}
  }

  AlarmOrchestratorImpl({int requiredPasses = 3, Duration minDwell = const Duration(seconds: 4)})
      : _requiredPasses = requiredPasses,
        _minDwell = minDwell;

  @override
  /// configure: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  void configure(AlarmConfig config) {
    _config = config;
  }

  @override
  /// registerDestination: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  void registerDestination(DestinationSpec spec) {
    _destination = spec;
    /// now: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    _startedAt = DateTime.now();
    _etaSamples = 0;
    _timeEligible = false;
    _fired = false;
    _proximityPasses = 0;
    _firstPassAt = null;
    _nextEventIndex = 0;
  }

  @override
  /// update: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  void update({required LocationSample sample, required SnappedPosition? snapped}) {
    final sw = Stopwatch()..start();
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (_destination == null || _config == null || _fired) return;
    _firstSample ??= sample;

    /// [Brief description of this field]
    final cfg = _config!;
    /// [Brief description of this field]
    final dest = _destination!;

    /// _distanceMeters: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    final distMeters = _distanceMeters(sample.lat, sample.lng, dest.lat, dest.lng);

    // Naive ETA (straight line / speed) for time threshold eligibility + triggering
    double? etaSeconds;
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (sample.speedMps > 0.5) {
      /// max: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      etaSeconds = distMeters / max(sample.speedMps, 0.5);
      _etaSamples++;
    }

    // Evaluate time eligibility (mirrors legacy conditions – distance since start + samples + min time)
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (!_timeEligible && cfg.timeETALimitSeconds > 0) {
      try {
        /// [Brief description of this field]
        final moved = _firstSample != null
            /// _distanceMeters: [Brief description of what this function does]
            /// 
            /// **Parameters**: [Describe parameters if any]
            /// **Returns**: [Describe return value]
            ? _distanceMeters(_firstSample!.lat, _firstSample!.lng, sample.lat, sample.lng)
            : 0.0;
        /// now: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        final sinceStart = _startedAt != null ? DateTime.now().difference(_startedAt!) : Duration.zero;
        /// if: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        if (moved >= cfg.minTimeEligibilityDistanceMeters && _etaSamples >= cfg.minEtaSamples && sinceStart >= cfg.minTimeEligibilitySinceStart) {
          _timeEligible = true;
          /// _emit: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          _emit('ELIGIBILITY_CHANGED', {'timeEligible': true});
        }
      /// catch: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      } catch (_) {}
    }

    bool inside = false;
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (cfg.distanceThresholdMeters > 0) {
      inside = inside || distMeters <= cfg.distanceThresholdMeters;
    }
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (cfg.timeETALimitSeconds > 0 && etaSeconds != null && _timeEligible) {
      inside = inside || etaSeconds <= cfg.timeETALimitSeconds;
    }
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (cfg.stopsThreshold > 0 && snapped != null && _totalStops != null && _totalStops! > 0) {
      // Approximate remaining stops using snapped.progressMeters -> progress ratio -> stops.
      /// if: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      if (_totalRouteMeters != null && _totalRouteMeters! > 0) {
        /// clamp: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        final ratio = (snapped.progressMeters / _totalRouteMeters!).clamp(0.0, 1.0);
        /// [Brief description of this field]
        final coveredStops = ratio * _totalStops!;
        /// [Brief description of this field]
        final remainingStops = _totalStops! - coveredStops;
        /// if: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        if (remainingStops <= cfg.stopsThreshold) {
          inside = true;
        }
      }
    }

    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (inside) {
      /// if: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      if (_proximityGatingEnabled) {
        _proximityPasses += 1;
        /// now: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        _firstPassAt ??= DateTime.now();
        /// now: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        final dwellOk = DateTime.now().difference(_firstPassAt!) >= _minDwell;
        /// [Brief description of this field]
        final passesOk = _proximityPasses >= _requiredPasses;
        /// if: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        if (dwellOk && passesOk) {
          /// _fire: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          _fire(distMeters: distMeters, etaSeconds: etaSeconds);
        }
      } else {
        /// _fire: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        _fire(distMeters: distMeters, etaSeconds: etaSeconds);
      }
    } else {
      // Reset gating
      /// if: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      if (_proximityPasses > 0) {
        _proximityPasses = 0;
        _firstPassAt = null;
      }
    }

    // Event alarm evaluation (does not interfere with destination alarm firing)
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (snapped != null && _routeEvents.isNotEmpty && _nextEventIndex < _routeEvents.length) {
      /// [Brief description of this field]
      final nextEv = _routeEvents[_nextEventIndex];
      /// [Brief description of this field]
      final progress = snapped.progressMeters;
      /// [Brief description of this field]
      final remainingToEvent = nextEv.meters - progress;
      /// if: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      if (remainingToEvent <= _eventTriggerWindowMeters) {
        /// _emit: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        _emit('EVENT_ALARM', {
          'eventType': nextEv.type,
          'label': nextEv.label,
          'metersFromStart': nextEv.meters,
          'remainingToEvent': remainingToEvent,
        });
        /// counter: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        MetricsRegistry.I.counter('alarm.event').inc();
        _nextEventIndex += 1; // move to following event
      }
    }
    /// stop: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    sw.stop();
    /// duration: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    MetricsRegistry.I.duration('orchestrator.update').record(sw.elapsed);
  }

  /// _fire: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  void _fire({required double distMeters, double? etaSeconds}) {
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (_fired) return;
    _fired = true;
    /// _emit: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    _emit('TRIGGERED', {
      'distanceMeters': distMeters,
      /// if: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      if (etaSeconds != null) 'etaSeconds': etaSeconds,
      'destination': _destination?.name,
    });
    /// info: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    AppLogger.I.info('Alarm triggered', domain: 'alarm', context: {'dist': distMeters, 'dest': _destination?.name});
    /// counter: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    MetricsRegistry.I.counter('alarm.triggered').inc();
  }

  /// _emit: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  void _emit(String type, Map<String, dynamic> data) {
    /// now: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    final now = DateTime.now();
    final key = type + (data['eventType'] != null ? ':${data['eventType']}' : '') + (data['label'] != null ? ':${data['label']}' : '');
    /// [Brief description of this field]
    final prev = _lastEmitAt[key];
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (prev != null && now.difference(prev) < emitTTL) {
      // Suppressed duplicate within TTL
      /// inc: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      try { AppMetrics.I.inc('orchestrator_suppressed'); } catch (_) {}
      return;
    }
    _lastEmitAt[key] = now;
    /// add: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    _eventsCtrl.add(AlarmEvent(type, now, data));
    /// inc: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    try { AppMetrics.I.inc('orchestrator_emit'); } catch (_) {}
  }

  @override
  /// reset: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  void reset() {
    _fired = false;
    _proximityPasses = 0;
    _firstPassAt = null;
    _etaSamples = 0;
    _timeEligible = false;
    _firstSample = null;
    _nextEventIndex = 0;
  }

  // Temporary injection utilities until full route manager wiring is in place
  /// setTotalRouteMeters: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  void setTotalRouteMeters(double meters) => _totalRouteMeters = meters;
  /// setTotalStops: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  void setTotalStops(double stops) => _totalStops = stops;
  /// setProximityGatingEnabled: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  void setProximityGatingEnabled(bool enabled) => _proximityGatingEnabled = enabled;
  /// setRouteEvents: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  void setRouteEvents(List<RouteEventBoundary> events) {
    /// sort: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    _routeEvents = events..sort((a,b)=>a.meters.compareTo(b.meters));
    _nextEventIndex = 0;
  }
  /// setEventTriggerWindowMeters: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  void setEventTriggerWindowMeters(double meters) => _eventTriggerWindowMeters = meters;

  /// _distanceMeters: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  double _distanceMeters(double lat1, double lon1, double lat2, double lon2) {
    // Fast equirectangular approximation (good enough for thresholds of hundreds of meters)
    /// [Brief description of this field]
    const double R = 6371000; // meters
    /// _deg2rad: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    final x = _deg2rad(lon2 - lon1) * cos(_deg2rad((lat1 + lat2) / 2));
    /// _deg2rad: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    final y = _deg2rad(lat2 - lat1);
    /// sqrt: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    return sqrt(x * x + y * y) * R;
  }

  /// _deg2rad: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  double _deg2rad(double deg) => deg * pi / 180.0;
}
