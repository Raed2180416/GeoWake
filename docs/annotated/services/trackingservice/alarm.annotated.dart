/// alarm.dart: Source file from lib/lib/services/trackingservice/alarm.dart
/// 
/// This annotated version provides detailed documentation for all classes, methods, and fields.

part of 'package:geowake2/services/trackingservice.dart';

/// _makeAlarmConfig: [Brief description of what this function does]
/// 
/// **Parameters**: [Describe parameters if any]
/// **Returns**: [Describe return value]
AlarmConfig _makeAlarmConfig() {
  // Map legacy UI mode/value to orchestrator config; only one threshold active at a time.
  final mode = _alarmMode;
  final v = _alarmValue ?? 0.0;
  /// if: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  if (mode == 'distance') {
    return AlarmConfig(
      distanceThresholdMeters: v * 1000.0,
      timeETALimitSeconds: 0,
      minEtaSamples: 3,
      stopsThreshold: 0,
    );
  /// if: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  } else if (mode == 'time') {
    return const AlarmConfig(
      distanceThresholdMeters: 0,
      /// value: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      timeETALimitSeconds: 0, // will be set below using value (minutes)
      minEtaSamples: 3,
      stopsThreshold: 0,
    /// copyWith: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    ).copyWith(timeETALimitSeconds: v * 60.0);
  /// if: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  } else if (mode == 'stops') {
    return AlarmConfig(
      distanceThresholdMeters: 0,
      timeETALimitSeconds: 0,
      minEtaSamples: 0,
      stopsThreshold: v,
    );
  }
  return const AlarmConfig(distanceThresholdMeters: 0, timeETALimitSeconds: 0, minEtaSamples: 3, stopsThreshold: 0);
}

extension _AlarmConfigCopy on AlarmConfig {
  /// copyWith: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  AlarmConfig copyWith({double? distanceThresholdMeters, double? timeETALimitSeconds, int? minEtaSamples, double? stopsThreshold}) {
    return AlarmConfig(
      distanceThresholdMeters: distanceThresholdMeters ?? this.distanceThresholdMeters,
      timeETALimitSeconds: timeETALimitSeconds ?? this.timeETALimitSeconds,
      minEtaSamples: minEtaSamples ?? this.minEtaSamples,
      stopsThreshold: stopsThreshold ?? this.stopsThreshold,
    );
  }
}

/// _computeDesiredAlarmEvalInterval: [Brief description of what this function does]
/// 
/// **Parameters**: [Describe parameters if any]
/// **Returns**: [Describe return value]
Duration _computeDesiredAlarmEvalInterval({double? etaSeconds, double? distanceMeters}) {
  /// if: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  if (TrackingService.isTestMode) return const Duration(milliseconds: 0);
  /// if: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  if (_alarmMode == null) return const Duration(seconds: 15);
  // Feature flag: optionally incorporate EtaEngine metadata (confidence/volatility)
  const bool adaptiveUseEtaMetadata = true; // can toggle to false if instability occurs
  final movementMode = _movementClassifier.mode; // walk / drive / transit
  double activityScalar;
  /// switch: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  switch (movementMode) {
    case 'walk':
      activityScalar = 0.75; // denser updates
      break;
    case 'transit':
      activityScalar = 0.9;
      break;
    case 'drive':
    default:
      activityScalar = 1.0;
  }
  /// if: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  if (_alarmMode == 'time') {
    final thresholdSec = (_alarmValue ?? 0) * 60.0;
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (thresholdSec <= 0 || etaSeconds == null || !etaSeconds.isFinite) {
      return const Duration(seconds: 20);
    }
    final ratio = etaSeconds / thresholdSec; // >1 outside threshold
    Duration base;
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (ratio > 5) {
      base = adaptiveFarInterval;
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    } else if (ratio > 2) {
      base = adaptiveMidInterval;
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    } else if (ratio > 1) {
      base = adaptiveNearInterval;
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    } else if (ratio > 0.5) {
      base = adaptiveCloseInterval;
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    } else if (ratio > 0.25) {
      base = adaptiveVeryCloseInterval;
    } else {
      base = adaptiveBurstInterval;
    }
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (ratio <= 1) {
      /// _enterBurstMode: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      _enterBurstMode();
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    } else if (_inBurstMode && ratio > adaptiveReentryHysteresis) {
      /// _exitBurstMode: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      _exitBurstMode();
    }
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (_inBurstMode && ratio <= 1) base = adaptiveBurstInterval;
    double scalar = activityScalar;
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (adaptiveUseEtaMetadata && _lastEtaResult != null) {
      // Lower confidence -> slightly longer interval (except when very close)
      final c = _lastEtaResult!.confidence; // 0..1
      final v = _lastEtaResult!.volatility; // 0 stable, >0 higher variance
      // Confidence adjustment (cap effect to +/-30%)
      final confAdj = (1.0 - c) * 0.3; // at c=0 add +30%, c=1 add 0%
      scalar *= (1.0 + confAdj);
      // Volatility adjustment: higher volatility shortens interval up to -40%
      /// min: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      final volAdj = (-math.min(v, 1.0)) * 0.4; // v>=1 => -40%
      scalar *= (1.0 + volAdj);
      // If within threshold (ratio <=1) never let metadata push interval above close tiers
      /// if: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      if (ratio <= 1) {
        /// clamp: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        scalar = scalar.clamp(0.5, 1.2); // keep near-threshold dense
      } else {
        /// clamp: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        scalar = scalar.clamp(0.8, 1.6);
      }
    }
    return Duration(milliseconds: (base.inMilliseconds * scalar).round().clamp(500, 60000));
  }
  /// if: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  if (_alarmMode == 'distance') {
    /// toDouble: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    final thresholdMeters = (_alarmValue ?? 0).toDouble();
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (thresholdMeters <= 0 || distanceMeters == null || !distanceMeters.isFinite) {
      return const Duration(seconds: 20);
    }
    final ratio = distanceMeters / thresholdMeters;
    Duration base;
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (ratio > 5) {
      base = adaptiveDistFarInterval;
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    } else if (ratio > 2) {
      base = adaptiveDistMidInterval;
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    } else if (ratio > 1) {
      base = adaptiveDistNearInterval;
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    } else if (ratio > 0.5) {
      base = adaptiveDistCloseInterval;
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    } else if (ratio > 0.25) {
      base = adaptiveDistVeryCloseInterval;
    } else {
      base = adaptiveDistBurstInterval;
    }
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (ratio <= 1) {
      /// _enterBurstMode: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      _enterBurstMode();
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    } else if (_inBurstMode && ratio > adaptiveReentryHysteresis) {
      /// _exitBurstMode: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      _exitBurstMode();
    }
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (_inBurstMode && ratio <= 1) base = adaptiveDistBurstInterval;
    double scalar = activityScalar;
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (adaptiveUseEtaMetadata && _lastEtaResult != null) {
      final c = _lastEtaResult!.confidence;
      final v = _lastEtaResult!.volatility;
      final confAdj = (1.0 - c) * 0.25; // up to +25%
      scalar *= (1.0 + confAdj);
      /// min: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      final volAdj = (-math.min(v, 1.0)) * 0.35; // up to -35%
      scalar *= (1.0 + volAdj);
      /// if: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      if (ratio <= 1) {
        /// clamp: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        scalar = scalar.clamp(0.5, 1.2);
      } else {
        /// clamp: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        scalar = scalar.clamp(0.8, 1.6);
      }
    }
    return Duration(milliseconds: (base.inMilliseconds * scalar).round().clamp(500, 60000));
  }
  return const Duration(seconds: 15);
}

/// pragma: [Brief description of what this function does]
/// 
/// **Parameters**: [Describe parameters if any]
/// **Returns**: [Describe return value]
@pragma('vm:entry-point')
/// _checkAndTriggerAlarm: [Brief description of what this function does]
/// 
/// **Parameters**: [Describe parameters if any]
/// **Returns**: [Describe return value]
Future<void> _checkAndTriggerAlarm(Position currentPosition, ServiceInstance service) async {
  final sw = Stopwatch()..start();
  /// if: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  if (_destination == null || _alarmValue == null) {
    /// stop: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    sw.stop();
    return;
  }

  bool shouldTriggerDestination = false;
  String? destinationReasonLabel;

  /// if: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  if (_alarmMode == 'distance') {
    /// distanceBetween: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    double distanceInMeters = Geolocator.distanceBetween(
      currentPosition.latitude,
      currentPosition.longitude,
      _destination!.latitude,
      _destination!.longitude,
    );
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (distanceInMeters <= (_alarmValue! * 1000)) { // alarmValue is in km
      shouldTriggerDestination = true;
      destinationReasonLabel = _destinationName;
    }
    /// _logAlarmEvalSnapshot: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    _logAlarmEvalSnapshot(
      fired: false,
      reason: 'distance_preGate',
      remainingMeters: distanceInMeters,
      thresholdMeters: (_alarmValue! * 1000),
    );
    /// debug: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    AppLogger.I.debug('Distance check', domain: 'alarm', context: {
      /// toStringAsFixed: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      'dist': distanceInMeters.toStringAsFixed(1),
      /// toStringAsFixed: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      'threshold': (_alarmValue! * 1000).toStringAsFixed(1)
    });
  /// if: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  } else if (_alarmMode == 'time') {
    // Gate time-based alarms to avoid immediate false triggers when stationary
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (!_timeAlarmEligible) {
      /// debug: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      AppLogger.I.debug('Time alarm not yet eligible', domain: 'alarm', context: {
        'samples': _etaSamples,
        /// toStringAsFixed: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        'movedMeters': _distanceTravelledMeters.toStringAsFixed(1),
        /// now: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        'sinceStartSec': _startedAt != null ? DateTime.now().difference(_startedAt!).inSeconds : -1
      });
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    } else if (_smoothedETA != null && _smoothedETA! <= (_alarmValue! * 60)) { // alarmValue is in minutes
      shouldTriggerDestination = true;
      destinationReasonLabel = _destinationName;
    }
    /// _logAlarmEvalSnapshot: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    _logAlarmEvalSnapshot(
      fired: false,
      reason: 'time_preGate',
      etaSeconds: _smoothedETA,
      thresholdEtaSeconds: (_alarmValue! * 60),
    );
    /// debug: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    AppLogger.I.debug('Time check', domain: 'alarm', context: {
      /// toStringAsFixed: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      'etaSec': _smoothedETA?.toStringAsFixed(0),
      /// toString: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      'thresholdSec': (_alarmValue! * 60).toString(),
      'eligible': _timeAlarmEligible
    });
  }

  // Metro pre-boarding alert: if stops-mode + transit route; trigger once near boarding point
  /// if: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  if (_alarmMode == 'stops' && _transitMode && !_preBoardingAlertFired) {
    try {
      /// if: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      if (_firstTransitBoarding != null) {
        /// distanceBetween: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        final d = Geolocator.distanceBetween(
          currentPosition.latitude, currentPosition.longitude,
          _firstTransitBoarding!.latitude, _firstTransitBoarding!.longitude,
        );
        /// debug: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        AppLogger.I.debug('Pre-boarding check', domain: 'alarm', context: {
          'mode': _alarmMode,
          'transit': _transitMode,
          /// toStringAsFixed: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          'dMeters': d.toStringAsFixed(1),
          'toBoarding': _firstTransitBoarding
        });
        // Dynamic heuristic: distance window before first boarding derived from configured stops threshold (alarmValue)
        // If user set a stops alarm (e.g., wake me N stops before destination), we scale the pre-boarding alert window
        // so earlier boarding preparation scales moderately with that preference. Empirically average urban rail stop spacing
        // ranges 400-600m; we choose a default of 550m to give a slight buffer while minimizing premature alerts on dense systems.
        final perStopHeuristic = TrackingService.stopsHeuristicMetersPerStop;
        final stopsThreshold = _alarmValue ?? 1.0; // alarmValue represents destination stops prior; reuse as mild scaler.
        // Cap scaler so very large stop thresholds (e.g., 10) don't create excessively early pre-board (> ~1.5km)
        final maxWindowMeters = 1500.0;
        /// clamp: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        final windowMeters = (stopsThreshold * perStopHeuristic).clamp(400.0, maxWindowMeters);
        // Emit PREBOARDING_SCHEDULED once when entering window (but before firing alert) if not already fired and not previously scheduled
        /// if: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        if (d <= windowMeters && !_preBoardingAlertFired) {
          try {
            /// info: [Brief description of what this function does]
            /// 
            /// **Parameters**: [Describe parameters if any]
            /// **Returns**: [Describe return value]
            AppLogger.I.info('PREBOARDING_SCHEDULED', domain: 'boarding', context: {
              'distanceMeters': d,
              'windowMeters': windowMeters,
              'stopsThreshold': stopsThreshold,
              'boardingLat': _firstTransitBoarding!.latitude,
              'boardingLng': _firstTransitBoarding!.longitude,
            });
          /// catch: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          } catch (_) {}
        }
        /// if: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        if (d <= windowMeters) {
          try {
            /// info: [Brief description of what this function does]
            /// 
            /// **Parameters**: [Describe parameters if any]
            /// **Returns**: [Describe return value]
            AppLogger.I.info('Pre-boarding alert firing', domain: 'alarm', context: {'dMeters': d.toStringAsFixed(1)});
            /// toStringAsFixed: [Brief description of what this function does]
            /// 
            /// **Parameters**: [Describe parameters if any]
            /// **Returns**: [Describe return value]
            final dedupeKey = 'preboard:${_firstTransitBoarding!.latitude.toStringAsFixed(5)},${_firstTransitBoarding!.longitude.toStringAsFixed(5)}';
            /// if: [Brief description of what this function does]
            /// 
            /// **Parameters**: [Describe parameters if any]
            /// **Returns**: [Describe return value]
            if (!TrackingService.alarmDeduplicator.shouldFire(dedupeKey)) {
              /// debug: [Brief description of what this function does]
              /// 
              /// **Parameters**: [Describe parameters if any]
              /// **Returns**: [Describe return value]
              AppLogger.I.debug('Suppressed duplicate pre-boarding alarm', domain: 'alarm');
            /// if: [Brief description of what this function does]
            /// 
            /// **Parameters**: [Describe parameters if any]
            /// **Returns**: [Describe return value]
            } else if (TrackingService.isTestMode) {
              await NotificationService().showWakeUpAlarm(
                title: 'Approaching metro station',
                body: 'Get ready to board',
                allowContinueTracking: true,
              );
            } else {
              /// invoke: [Brief description of what this function does]
              /// 
              /// **Parameters**: [Describe parameters if any]
              /// **Returns**: [Describe return value]
              service.invoke('fireAlarm', {
                'title': 'Approaching metro station',
                'body': 'Get ready to board',
                'allowContinueTracking': true,
              });
            }
            _preBoardingAlertFired = true;
            try {
              /// info: [Brief description of what this function does]
              /// 
              /// **Parameters**: [Describe parameters if any]
              /// **Returns**: [Describe return value]
              AppLogger.I.info('BOARDING_DETECT', domain: 'boarding', context: {
                'distanceMeters': d,
                'windowMeters': windowMeters,
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
      }
    /// catch: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    } catch (_) {}
  }

  // Also check upcoming route events (transfer/mode change) with the same threshold semantics
  /// if: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  if (_routeEvents.isNotEmpty) {
    // We need progressMeters along the active route; grab latest from manager by listening state earlier.
    // Since we don't keep state here, approximate using last known remaining distance if available via registry lastProgress.
    try {
      // Use authoritative progress from the active route manager state
      double? progressMeters = _lastActiveState?.progressMeters;
      // Fallback: if manager progress is unavailable, approximate using straight-line
      /// if: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      if ((progressMeters == null || progressMeters.isNaN) && _origin != null && _destination != null) {
        try {
          /// distanceBetween: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          final total = Geolocator.distanceBetween(
            _origin!.latitude, _origin!.longitude, _destination!.latitude, _destination!.longitude,
          );
          /// distanceBetween: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          final covered = Geolocator.distanceBetween(
            _origin!.latitude, _origin!.longitude, currentPosition.latitude, currentPosition.longitude,
          );
          /// clamp: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          final approx = covered.clamp(0.0, total);
          /// if: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          if (progressMeters == null) {
            progressMeters = approx;
          } else {
            // take the larger to avoid regressions
            progressMeters = approx > progressMeters ? approx : progressMeters;
          }
        /// catch: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        } catch (_) {}
      }
      /// if: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      if (progressMeters != null) {
        final thresholdMeters = _alarmMode == 'distance' ? (_alarmValue! * 1000.0) : null;
        final thresholdSeconds = _alarmMode == 'time' ? (_alarmValue! * 60.0) : null;
        final thresholdStops = _alarmMode == 'stops' ? (_alarmValue!) : null;
        // Compute simple speed for time threshold
        final spd = _lastSpeedMps != null && _lastSpeedMps! > 0.3 ? _lastSpeedMps! : 10.0;
        // Compute progressStops if needed
        double? progressStops;
        /// if: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        if (thresholdStops != null && _stepBoundsMeters.isNotEmpty && _stepStopsCumulative.isNotEmpty) {
          /// for: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          for (int i = 0; i < _stepBoundsMeters.length; i++) {
            /// if: [Brief description of what this function does]
            /// 
            /// **Parameters**: [Describe parameters if any]
            /// **Returns**: [Describe return value]
            if (progressMeters <= _stepBoundsMeters[i]) {
              progressStops = _stepStopsCumulative[i];
              break;
            }
          }
          progressStops ??= 0.0;
        }
        /// for: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        for (int idx = 0; idx < _routeEvents.length; idx++) {
          final ev = _routeEvents[idx];
          /// if: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          if (_firedEventIndexes.contains(idx)) continue; // already alerted
          /// if: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          if (ev.meters <= progressMeters) continue; // already passed
          final toEventM = ev.meters - progressMeters;
          bool eventAlarm = false;
          // When in stops mode we allow two pathways for raising an event alarm:
          // 1. Classic stops/time/distance threshold semantics (user-configured alarmValue for destination)
          // 2. Heuristic distance pre-window derived from stops heuristic for transfer awareness (distinct from destination stops threshold)
          double? heuristicWindowM;
          /// if: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          if (_alarmMode == 'stops') {
            // Use a modest fixed window based on 1 * per-stop heuristic; transfers often need slightly earlier heads-up than destination.
            // Cap to 800m to avoid low-density long-stop spacing causing very early transfer alerts.
            /// clamp: [Brief description of what this function does]
            /// 
            /// **Parameters**: [Describe parameters if any]
            /// **Returns**: [Describe return value]
            heuristicWindowM = TrackingService.stopsHeuristicMetersPerStop.clamp(300.0, 800.0);
          }
          /// if: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          if (thresholdMeters != null) {
            eventAlarm = toEventM <= thresholdMeters;
            /// debug: [Brief description of what this function does]
            /// 
            /// **Parameters**: [Describe parameters if any]
            /// **Returns**: [Describe return value]
            AppLogger.I.debug('Event distance check', domain: 'alarm', context: {
              'eventIdx': idx,
              'eventType': ev.type,
              /// toStringAsFixed: [Brief description of what this function does]
              /// 
              /// **Parameters**: [Describe parameters if any]
              /// **Returns**: [Describe return value]
              'toEventM': toEventM.toStringAsFixed(1),
              /// toStringAsFixed: [Brief description of what this function does]
              /// 
              /// **Parameters**: [Describe parameters if any]
              /// **Returns**: [Describe return value]
              'thresholdM': thresholdMeters.toStringAsFixed(1),
              'willFire': eventAlarm,
            });
          /// if: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          } else if (thresholdSeconds != null) {
            /// if: [Brief description of what this function does]
            /// 
            /// **Parameters**: [Describe parameters if any]
            /// **Returns**: [Describe return value]
            if (!_timeAlarmEligible) {
              // Do not raise time-based event alarms until eligible
              continue;
            }
            final estSec = toEventM / spd;
            eventAlarm = estSec <= thresholdSeconds;
            /// debug: [Brief description of what this function does]
            /// 
            /// **Parameters**: [Describe parameters if any]
            /// **Returns**: [Describe return value]
            AppLogger.I.debug('Event time check', domain: 'alarm', context: {
              'eventIdx': idx,
              'eventType': ev.type,
              /// toStringAsFixed: [Brief description of what this function does]
              /// 
              /// **Parameters**: [Describe parameters if any]
              /// **Returns**: [Describe return value]
              'toEventM': toEventM.toStringAsFixed(1),
              /// toStringAsFixed: [Brief description of what this function does]
              /// 
              /// **Parameters**: [Describe parameters if any]
              /// **Returns**: [Describe return value]
              'estSec': estSec.toStringAsFixed(1),
              /// toStringAsFixed: [Brief description of what this function does]
              /// 
              /// **Parameters**: [Describe parameters if any]
              /// **Returns**: [Describe return value]
              'thresholdSec': thresholdSeconds.toStringAsFixed(1),
              'willFire': eventAlarm,
            });
          /// if: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          } else if (thresholdStops != null && progressStops != null) {
            // Map event meters to event stops
            double? eventStops;
            /// for: [Brief description of what this function does]
            /// 
            /// **Parameters**: [Describe parameters if any]
            /// **Returns**: [Describe return value]
            for (int i = 0; i < _stepBoundsMeters.length; i++) {
              /// if: [Brief description of what this function does]
              /// 
              /// **Parameters**: [Describe parameters if any]
              /// **Returns**: [Describe return value]
              if (ev.meters <= _stepBoundsMeters[i]) {
                eventStops = _stepStopsCumulative[i];
                break;
              }
            }
            /// if: [Brief description of what this function does]
            /// 
            /// **Parameters**: [Describe parameters if any]
            /// **Returns**: [Describe return value]
            if (eventStops != null) {
              final toEventStops = eventStops - progressStops;
              eventAlarm = toEventStops <= thresholdStops;
              /// debug: [Brief description of what this function does]
              /// 
              /// **Parameters**: [Describe parameters if any]
              /// **Returns**: [Describe return value]
              AppLogger.I.debug('Event stops check', domain: 'alarm', context: {
                'eventIdx': idx,
                'eventType': ev.type,
                /// toStringAsFixed: [Brief description of what this function does]
                /// 
                /// **Parameters**: [Describe parameters if any]
                /// **Returns**: [Describe return value]
                'toEventM': toEventM.toStringAsFixed(1),
                /// toStringAsFixed: [Brief description of what this function does]
                /// 
                /// **Parameters**: [Describe parameters if any]
                /// **Returns**: [Describe return value]
                'toEventStops': toEventStops.toStringAsFixed(1),
                /// toStringAsFixed: [Brief description of what this function does]
                /// 
                /// **Parameters**: [Describe parameters if any]
                /// **Returns**: [Describe return value]
                'thresholdStops': thresholdStops.toStringAsFixed(1),
                /// toStringAsFixed: [Brief description of what this function does]
                /// 
                /// **Parameters**: [Describe parameters if any]
                /// **Returns**: [Describe return value]
                'progressStops': progressStops.toStringAsFixed(1),
                /// toStringAsFixed: [Brief description of what this function does]
                /// 
                /// **Parameters**: [Describe parameters if any]
                /// **Returns**: [Describe return value]
                'eventStops': eventStops.toStringAsFixed(1),
                'willFire': eventAlarm,
              });
            }
          }
          // If not already decided and heuristic window applies, use it (pre-transfer alert)
          /// if: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          if (!eventAlarm && heuristicWindowM != null) {
            /// if: [Brief description of what this function does]
            /// 
            /// **Parameters**: [Describe parameters if any]
            /// **Returns**: [Describe return value]
            if (toEventM <= heuristicWindowM) {
              eventAlarm = true;
              /// debug: [Brief description of what this function does]
              /// 
              /// **Parameters**: [Describe parameters if any]
              /// **Returns**: [Describe return value]
              AppLogger.I.debug('Event heuristic window triggered', domain: 'alarm', context: {
                'eventIdx': idx,
                'eventType': ev.type,
                /// toStringAsFixed: [Brief description of what this function does]
                /// 
                /// **Parameters**: [Describe parameters if any]
                /// **Returns**: [Describe return value]
                'toEventM': toEventM.toStringAsFixed(1),
                /// toStringAsFixed: [Brief description of what this function does]
                /// 
                /// **Parameters**: [Describe parameters if any]
                /// **Returns**: [Describe return value]
                'heuristicWindowM': heuristicWindowM.toStringAsFixed(1),
              });
            }
          }
          /// if: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          if (eventAlarm) {
            // Fire an event alarm (do not stop service). In test mode, use NotificationService for observability.
            try {
              final title = ev.type == 'transfer' ? 'Upcoming transfer' : 'Upcoming change';
              final body = ev.label != null ? ev.label! : (ev.type == 'transfer' ? 'Transfer ahead' : 'Mode change ahead');
              /// toStringAsFixed: [Brief description of what this function does]
              /// 
              /// **Parameters**: [Describe parameters if any]
              /// **Returns**: [Describe return value]
              final dedupeKey = 'event:${ev.type}:${ev.meters.toStringAsFixed(1)}';
              /// if: [Brief description of what this function does]
              /// 
              /// **Parameters**: [Describe parameters if any]
              /// **Returns**: [Describe return value]
              if (!TrackingService.alarmDeduplicator.shouldFire(dedupeKey)) {
                /// debug: [Brief description of what this function does]
                /// 
                /// **Parameters**: [Describe parameters if any]
                /// **Returns**: [Describe return value]
                AppLogger.I.debug('Suppressed duplicate event alarm', domain: 'alarm', context: {'key': dedupeKey});
              } else {
                /// info: [Brief description of what this function does]
                /// 
                /// **Parameters**: [Describe parameters if any]
                /// **Returns**: [Describe return value]
                AppLogger.I.info('Firing event alarm', domain: 'alarm', context: {
                  'eventIdx': idx,
                  'eventType': ev.type,
                  'title': title,
                  'body': body,
                  /// toStringAsFixed: [Brief description of what this function does]
                  /// 
                  /// **Parameters**: [Describe parameters if any]
                  /// **Returns**: [Describe return value]
                  'toEventM': toEventM.toStringAsFixed(1),
                });
                /// if: [Brief description of what this function does]
                /// 
                /// **Parameters**: [Describe parameters if any]
                /// **Returns**: [Describe return value]
                if (TrackingService.isTestMode) {
                  await NotificationService().showWakeUpAlarm(
                    title: title,
                    body: body,
                    allowContinueTracking: true,
                  );
                } else {
                  /// invoke: [Brief description of what this function does]
                  /// 
                  /// **Parameters**: [Describe parameters if any]
                  /// **Returns**: [Describe return value]
                  service.invoke('fireAlarm', {
                    'title': title,
                    'body': body,
                    'allowContinueTracking': true,
                  });
                }
              }
            /// catch: [Brief description of what this function does]
            /// 
            /// **Parameters**: [Describe parameters if any]
            /// **Returns**: [Describe return value]
            } catch (e) {
              /// warn: [Brief description of what this function does]
              /// 
              /// **Parameters**: [Describe parameters if any]
              /// **Returns**: [Describe return value]
              AppLogger.I.warn('Failed to fire event alarm', domain: 'alarm', context: {
                'eventIdx': idx,
                /// toString: [Brief description of what this function does]
                /// 
                /// **Parameters**: [Describe parameters if any]
                /// **Returns**: [Describe return value]
                'error': e.toString(),
              });
            }
            /// add: [Brief description of what this function does]
            /// 
            /// **Parameters**: [Describe parameters if any]
            /// **Returns**: [Describe return value]
            _firedEventIndexes.add(idx);
            // Continue to check destination separately
          }
        }
      }
    /// catch: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    } catch (_) {}
  }

  // Destination threshold check considering stops mode
  /// if: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  if (_alarmMode == 'stops' && !_destinationAlarmFired) {
    // Compute remaining stops based on progress
    try {
      /// if: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      if (_stepBoundsMeters.isNotEmpty && _stepStopsCumulative.isNotEmpty) {
        double? pm = _lastActiveState?.progressMeters;
        // Fallback: if route polyline length is far shorter than step distance totals, approximate with straight-line progress
        try {
          /// if: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          if (pm != null && _origin != null && _destination != null && _lastProcessedPosition != null) {
            /// distanceBetween: [Brief description of what this function does]
            /// 
            /// **Parameters**: [Describe parameters if any]
            /// **Returns**: [Describe return value]
            final straightCovered = Geolocator.distanceBetween(
              _origin!.latitude, _origin!.longitude,
              _lastProcessedPosition!.latitude, _lastProcessedPosition!.longitude,
            );
            /// if: [Brief description of what this function does]
            /// 
            /// **Parameters**: [Describe parameters if any]
            /// **Returns**: [Describe return value]
            if (straightCovered > pm) {
              // Use the larger to avoid under-reporting progress (helps parity harness where simplified polyline is tiny)
              pm = straightCovered;
            }
          }
        /// catch: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        } catch (_) {}
        /// if: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        if (pm != null) {
          double progressStops = 0.0;
          /// for: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          for (int i = 0; i < _stepBoundsMeters.length; i++) {
            /// if: [Brief description of what this function does]
            /// 
            /// **Parameters**: [Describe parameters if any]
            /// **Returns**: [Describe return value]
            if (pm <= _stepBoundsMeters[i]) {
              progressStops = _stepStopsCumulative[i];
              break;
            }
          }
          final totalStops = _stepStopsCumulative.isNotEmpty ? _stepStopsCumulative.last : 0.0;
          final remainingStops = (totalStops - progressStops);
          // Hysteresis: require we stay below threshold for consecutive evaluations
          const int requiredPasses = 2; // light hysteresis for stops
          _stopsPassesBelow ??= 0;
          /// if: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          if (remainingStops <= _alarmValue!) {
            /// clamp: [Brief description of what this function does]
            /// 
            /// **Parameters**: [Describe parameters if any]
            /// **Returns**: [Describe return value]
            _stopsPassesBelow = (_stopsPassesBelow! + 1).clamp(0, 10);
          } else {
            _stopsPassesBelow = 0; // reset if we exit band
          }
          /// if: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          if (_stopsPassesBelow! >= requiredPasses) {
            shouldTriggerDestination = true;
            destinationReasonLabel = _destinationName;
          }
          /// _logAlarmEvalSnapshot: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          _logAlarmEvalSnapshot(
            fired: false,
            reason: 'stops_preGate',
            remainingStops: remainingStops,
            thresholdStops: _alarmValue,
          );
        }
      }
    /// catch: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    } catch (_) {}
  }

  /// if: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  if (shouldTriggerDestination && !_destinationAlarmFired) {
    // Proximity stability gating (distance/time/stops unified): ensure consecutive confirmations & dwell.
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if ((!TrackingService.isTestMode || TrackingService.testForceProximityGating) && !(_alarmMode == 'time' && TrackingService.testBypassProximityForTime)) {
      _proximityConsecutivePasses += 1;
      /// now: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      _proximityFirstPassAt ??= DateTime.now();
      /// now: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      final dwellOk = DateTime.now().difference(_proximityFirstPassAt!) >= _proximityMinDwell;
      final passesOk = _proximityConsecutivePasses >= _proximityRequiredPasses;
      /// if: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      if (TrackingService.testForceProximityGating) {
        // ignore: avoid_print
        /// if: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        if (TrackingService.isTestMode) {
          /// debug: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          AppLogger.I.debug('Gating debug', domain: 'test', context: {
            /// toString: [Brief description of what this function does]
            /// 
            /// **Parameters**: [Describe parameters if any]
            /// **Returns**: [Describe return value]
            'passes': _proximityConsecutivePasses.toString(),
            /// toString: [Brief description of what this function does]
            /// 
            /// **Parameters**: [Describe parameters if any]
            /// **Returns**: [Describe return value]
            'dwellOk': dwellOk.toString(),
            /// toString: [Brief description of what this function does]
            /// 
            /// **Parameters**: [Describe parameters if any]
            /// **Returns**: [Describe return value]
            'passesOk': passesOk.toString(),
          });
        }
      }
      /// if: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      if (!(dwellOk && passesOk)) {
        /// debug: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        AppLogger.I.debug('Proximity gating', domain: 'alarm', context: {
          'passes': _proximityConsecutivePasses,
          'dwellOk': dwellOk,
          'needPasses': _proximityRequiredPasses,
          'needDwellSec': _proximityMinDwell.inSeconds
        });
        /// _logAlarmGate: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        _logAlarmGate('proximity', {
          'passes': _proximityConsecutivePasses,
          'dwellOk': dwellOk,
          'requiredPasses': _proximityRequiredPasses,
          'requiredDwellSec': _proximityMinDwell.inSeconds,
        });
        // Do not fire yet
        shouldTriggerDestination = false;
      }
    }
  /// if: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  } else if (!shouldTriggerDestination) {
    // Reset gating counters if we leave threshold band
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (_proximityConsecutivePasses > 0) {
      _proximityConsecutivePasses = 0;
      _proximityFirstPassAt = null;
    }
  }

  /// if: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  if (shouldTriggerDestination && !_destinationAlarmFired) {
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (!TrackingService.useOrchestratorForDestinationAlarm) {
      /// _handleDestinationAlarmTrigger: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      await _handleDestinationAlarmTrigger(
        service,
        source: 'legacy',
        destinationReasonLabel: destinationReasonLabel,
        remainingMeters: null,
        etaSeconds: _smoothedETA,
      );
    } else {
      /// debug: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      AppLogger.I.debug('Feature flag suppressed legacy destination alarm (orchestrator should handle).', domain: 'alarm');
    }
  }

  // Periodic snapshot (very lightweight; could be throttled externally)
  try {
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (TrackingService.sessionStore != null && _orchestrator != null) {
      final snap = SessionSnapshot(
        activeRouteId: null,
        progressMeters: _lastActiveState?.progressMeters,
        alarmEligible: _timeAlarmEligible,
        /// now: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        savedAt: DateTime.now(),
      );
      /// save: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      TrackingService.sessionStore!.save(snap);
    }
  /// catch: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  } catch (_) {}
  /// stop: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  sw.stop();
  /// duration: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  MetricsRegistry.I.duration('alarm.legacy.check').record(sw.elapsed);
}

/// _dispatchAlarmNotification: [Brief description of what this function does]
/// 
/// **Parameters**: [Describe parameters if any]
/// **Returns**: [Describe return value]
Future<void> _dispatchAlarmNotification(
  ServiceInstance service, {
  required String dedupeKey,
  required String title,
  required String body,
  required bool allowContinueTracking,
}) async {
  try {
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (!TrackingService.alarmDeduplicator.shouldFire(dedupeKey)) {
      /// debug: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      AppLogger.I.debug('Suppressed duplicate alarm', domain: 'alarm', context: {
        'key': dedupeKey,
      });
      return;
    }
    // Always call NotificationService directly to ensure alarm shows even if
    // the foreground UI is detached; NotificationService handles native activity launch.
    await NotificationService().showWakeUpAlarm(
      title: title,
      body: body,
      allowContinueTracking: allowContinueTracking,
    );
  /// catch: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  } catch (e) {
    try {
      /// warn: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      AppLogger.I.warn('Alarm dispatch failed', domain: 'alarm', context: {
        /// toString: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        'error': e.toString(),
        'key': dedupeKey,
      });
    /// catch: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    } catch (_) {}
  }
}

/// _handleDestinationAlarmTrigger: [Brief description of what this function does]
/// 
/// **Parameters**: [Describe parameters if any]
/// **Returns**: [Describe return value]
Future<void> _handleDestinationAlarmTrigger(
  ServiceInstance service, {
  required String source,
  String? destinationReasonLabel,
  double? remainingMeters,
  double? etaSeconds,
}) async {
  /// if: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  if (_destinationAlarmFired) {
    return;
  }

  _destinationAlarmFired = true;
  _proximityConsecutivePasses = 0;
  _proximityFirstPassAt = null;

  try {
    /// info: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    AppLogger.I.info('Destination alarm triggered ($source path)', domain: 'alarm', context: {
      'mode': _alarmMode,
      'value': _alarmValue,
      'source': source,
      'etaSec': etaSeconds,
      'remainingMeters': remainingMeters,
    });
  /// catch: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  } catch (_) {}

  /// _logAlarmFire: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  _logAlarmFire(source, remainingMeters: remainingMeters, etaSeconds: etaSeconds);

  try {
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (source == 'legacy') {
      /// counter: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      MetricsRegistry.I.counter('alarm.legacy.triggered').inc();
    } else {
      /// counter: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      MetricsRegistry.I.counter('alarm.orchestrator.triggered').inc();
    }
    /// counter: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    MetricsRegistry.I.counter('alarm.triggered').inc();
  /// catch: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  } catch (_) {}

  final title = 'Wake Up! ';
  final body = destinationReasonLabel != null
      ? 'Approaching: $destinationReasonLabel'
      : 'You are nearing your target';
  /// toStringAsFixed: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  final dedupeKey = 'destination:${_destination?.latitude.toStringAsFixed(5)},${_destination?.longitude.toStringAsFixed(5)}';
  /// _dispatchAlarmNotification: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  await _dispatchAlarmNotification(
    service,
    dedupeKey: dedupeKey,
    title: title,
    body: body,
    allowContinueTracking: false,
  );

  try {
    /// cancel: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    TrackingService._fallbackManager?.cancel(reason: 'destination_alarm');
  /// catch: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  } catch (_) {}

  // Stop the service to save battery once destination alarm fires
  try {
    /// invoke: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    service.invoke('stopTracking', {'stopSelf': true});
  /// catch: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  } catch (_) {
    /// invoke: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    service.invoke('stopTracking');
  }
}

/// _handleOrchestratorEvent: [Brief description of what this function does]
/// 
/// **Parameters**: [Describe parameters if any]
/// **Returns**: [Describe return value]
void _handleOrchestratorEvent(ServiceInstance service, AlarmEvent ev) {
  try {
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (TrackingService.isTestMode && ev.type == 'TRIGGERED') {
      _orchTriggeredAt = ev.at;
      /// log: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      dev.log('[ORCH] TRIGGERED at ${ev.at.toIso8601String()} data=${ev.data}', name: 'TrackingService');
    }

    /// switch: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    switch (ev.type) {
      case 'TRIGGERED':
        /// if: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        if (!TrackingService.useOrchestratorForDestinationAlarm) {
          return;
        }
        final destLabel = ev.data['destination'] as String?;
        /// toDouble: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        final remainingMeters = (ev.data['distanceMeters'] as num?)?.toDouble();
        /// toDouble: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        final etaSeconds = (ev.data['etaSeconds'] as num?)?.toDouble();
        () async {
          /// _handleDestinationAlarmTrigger: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          await _handleDestinationAlarmTrigger(
            service,
            source: 'orchestrator',
            destinationReasonLabel: destLabel,
            remainingMeters: remainingMeters,
            etaSeconds: etaSeconds,
          );
        }();
        break;
      case 'EVENT_ALARM':
        /// if: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        if (!TrackingService.useOrchestratorForDestinationAlarm) {
          return;
        }
        final eventType = ev.data['eventType'] as String? ?? 'change';
        final label = ev.data['label'] as String? ?? (eventType == 'transfer' ? 'Transfer ahead' : 'Mode change ahead');
        /// toDouble: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        final metersFromStart = (ev.data['metersFromStart'] as num?)?.toDouble();
        /// if: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        if (metersFromStart != null) {
          /// for: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          for (int i = 0; i < _routeEvents.length; i++) {
            final evMeters = _routeEvents[i].meters;
            /// if: [Brief description of what this function does]
            /// 
            /// **Parameters**: [Describe parameters if any]
            /// **Returns**: [Describe return value]
            if ((evMeters - metersFromStart).abs() <= 1.0) {
              /// add: [Brief description of what this function does]
              /// 
              /// **Parameters**: [Describe parameters if any]
              /// **Returns**: [Describe return value]
              _firedEventIndexes.add(i);
              break;
            }
          }
        }
        final dedupeKey = metersFromStart != null
            /// toStringAsFixed: [Brief description of what this function does]
            /// 
            /// **Parameters**: [Describe parameters if any]
            /// **Returns**: [Describe return value]
            ? 'event:$eventType:${metersFromStart.toStringAsFixed(1)}'
            : 'event:$eventType:$label';
        final title = eventType == 'transfer' ? 'Upcoming transfer' : 'Upcoming change';
        final body = label;
        try {
          /// invoke: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          service.invoke('orchestratorEvent', {
            'eventType': eventType,
            'label': label,
            'metersFromStart': metersFromStart,
            /// now: [Brief description of what this function does]
            /// 
            /// **Parameters**: [Describe parameters if any]
            /// **Returns**: [Describe return value]
            'ts': DateTime.now().toIso8601String(),
          });
        /// catch: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        } catch (_) {}
        () async {
          /// _dispatchAlarmNotification: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          await _dispatchAlarmNotification(
            service,
            dedupeKey: dedupeKey,
            title: title,
            body: body,
            allowContinueTracking: true,
          );
        }();
        break;
      case 'ELIGIBILITY_CHANGED':
        /// if: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        if (!TrackingService.useOrchestratorForDestinationAlarm) {
          return;
        }
        final timeEligible = ev.data['timeEligible'];
        /// if: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        if (timeEligible is bool) {
          _timeAlarmEligible = timeEligible;
          try {
            /// debug: [Brief description of what this function does]
            /// 
            /// **Parameters**: [Describe parameters if any]
            /// **Returns**: [Describe return value]
            AppLogger.I.debug('Time eligibility updated from orchestrator', domain: 'alarm', context: {
              'eligible': timeEligible,
            });
          /// catch: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          } catch (_) {}
        }
        break;
      default:
        break;
    }
  /// catch: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  } catch (e, st) {
    try {
      /// warn: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      AppLogger.I.warn('Failed handling orchestrator event', domain: 'alarm', context: {
        'type': ev.type,
        /// toString: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        'error': e.toString(),
      });
      /// log: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      dev.log('Orchestrator event handling error: $e', name: 'TrackingService', error: e, stackTrace: st);
    /// catch: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    } catch (_) {}
  }
}
