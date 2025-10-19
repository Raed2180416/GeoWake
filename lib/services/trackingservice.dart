// lib/services/trackingservice.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:geolocator/geolocator.dart';
import 'package:battery_plus/battery_plus.dart';
import 'dart:developer' as dev; // retain for legacy but migrate alarm path to AppLogger
import '../logging/app_logger.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:math' as math; // for adaptive metadata scaling
import 'package:geowake2/services/eta/eta_engine.dart';

// --- ADDED IMPORTS ---
import 'package:geowake2/services/notification_service.dart';
// Note: You may need to create these files if they don't exist yet,
// but the core alarm logic will work without them for now.
import 'package:geowake2/services/sensor_fusion.dart';
import 'package:geowake2/metrics/metrics_registry.dart' as core_metrics;
// ---
import 'package:geowake2/services/route_registry.dart';
import 'package:geowake2/services/active_route_manager.dart';
import 'package:geowake2/services/deviation_monitor.dart';
import 'package:geowake2/services/geometry/segment_projection.dart';
import 'package:geowake2/config/feature_flags.dart';
import 'package:geowake2/services/reroute_policy.dart';
import 'package:geowake2/services/route_cache.dart';
import 'package:geowake2/services/polyline_simplifier.dart';
import 'package:geowake2/services/polyline_decoder.dart';
import 'package:geowake2/services/transfer_utils.dart';
import 'package:geowake2/services/alarm_player.dart';
import 'package:geowake2/services/offline_coordinator.dart';
import 'package:geowake2/config/power_policy.dart';
import 'package:geowake2/services/snap_to_route.dart';
import 'package:geowake2/services/idle_power_scaler.dart';
import 'package:geowake2/services/event_bus.dart';
// Refactor modules (dual-run migration)
import 'package:geowake2/services/refactor/alarm_orchestrator_impl.dart';
import 'package:geowake2/services/refactor/interfaces.dart';
import 'package:geowake2/services/refactor/location_types.dart';
import 'package:geowake2/services/metrics/metrics.dart';
import 'package:geowake2/services/metrics/app_metrics.dart';
import 'package:geowake2/services/heading_smoother.dart';
import 'package:geowake2/services/sample_validator.dart';
import '../config/alarm_thresholds.dart';
import '../config/tweakables.dart';
import 'movement_classifier.dart';
import 'alarm_deduplicator.dart';
import 'alarm_scheduler.dart';
import 'persistence/snapshot.dart';
import 'persistence/persistence_manager.dart';
import 'dart:io';
import 'persistence/tracking_session_state.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';

import 'package:flutter/foundation.dart'; // for @visibleForTesting
import 'package:sensors_plus/sensors_plus.dart';


part 'trackingservice/globals.dart';
part 'trackingservice/background_state.dart';
part 'trackingservice/logging.dart';
part 'trackingservice/alarm.dart';
part 'trackingservice/background_lifecycle.dart';

class TrackingService {
  static bool isTestMode = false;
  // When true and in testMode, skip SharedPreferences persistence to silence MissingPlugin noise.
  static bool suppressPersistenceInTest = true;
  // Optional VM test hook: allows direct injection of Position samples in tests
  // without using FlutterBackgroundService (which is unavailable on VM).
  // Default implementation (safe no-op in production) pushes into the injected stream
  // only when isTestMode is true.
  static void Function(Position p)? injectPositionForTests = (Position p) {
    if (!TrackingService.isTestMode) return; // guard: never mutate prod pipeline
    try {
      _useInjectedPositions = true;
      _injectedCtrl ??= StreamController<Position>.broadcast();
      _injectedCtrl!.add(p);
    } catch (_) {}
  };
  static bool useOrchestratorForDestinationAlarm = false; // feature flag
  static SessionStateStore? sessionStore; // can be injected for persistence
  static bool testForceProximityGating = false;
  // Test overrides for time alarm eligibility
  static double? testTimeAlarmMinDistanceMeters;
  static int? testTimeAlarmMinSamples;
  static bool testBypassProximityForTime = false;
  // One-time schema emission flag
  static bool _logSchemaEmitted = false;
  // Heuristic mapping from one transit stop to meters (used for pre-boarding & transfer distance windows when in stops mode)
  // Empirically urban heavy rail: 600-1200m, light rail/tram: 300-600m, dense metro core: ~400-500m. Choose 550m midpoint.
  // Tests can override this to force deterministic thresholds.
  static double stopsHeuristicMetersPerStop = GeoWakeTweakables.stopsHeuristicMetersPerStop;
  // Idle power scaler test factory & latest mode (for assertions)
  static IdlePowerScaler Function()? testIdleScalerFactory;
  static String? get latestPowerMode => _latestPowerMode;
  @visibleForTesting
  static Duration timeAlarmMinSinceStart = const Duration(seconds: 30);
  static final TrackingService _instance = TrackingService._internal();
  factory TrackingService() => _instance;
  TrackingService._internal();
  final FlutterBackgroundService _service = FlutterBackgroundService();
  // Foreground-side tracking active shadow (fast check for lifecycle decisions)
  static bool _trackingActive = false;
  static bool get trackingActive => _trackingActive;
  // Set true when we auto-resume a session at cold start
  static bool autoResumed = false;
  // Persistent alarm evaluation snapshot keys (file + prefs). Supports dual storage for post-mortem after process death.
  static const String _alarmEvalPrefsKey = 'last_alarm_eval_v1';
  static const String _alarmEvalFileName = 'last_alarm_eval.json';
  static Map<String, dynamic>? _lastAlarmEvalCache; // in-memory copy for quick access
  // One-time log guards
  static bool _sessionCommitLogged = false;
  static bool _etaSourceLogged = false;

  // Transfer / boarding alert tracking (static so background top-level handlers can access)
  static final Set<double> _transferAlertsScheduled = <double>{};
  static final Set<double> _transferAlertsFired = <double>{};
  static String? _lastMovementModeLogged; // for SPEED_MODE_CHANGE

  static Future<void> _persistLastAlarmEval(Map<String, dynamic> json) async {
    _lastAlarmEvalCache = json;
    // SharedPreferences (fast)
    try {
      if (isTestMode && suppressPersistenceInTest) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_alarmEvalPrefsKey, jsonEncode(json));
    } catch (e) {
      try { AppLogger.I.warn('Persist alarm eval prefs failed', domain: 'alarm', context: {'err': e.toString()}); } catch (_) {}
    }
    // File redundancy (slower but survives prefs corruption) – reuse app support dir
    try {
      if (isTestMode && suppressPersistenceInTest) return;
      final dir = await getApplicationSupportDirectory();
      final f = File('${dir.path}/$_alarmEvalFileName');
      await f.writeAsString(jsonEncode(json), flush: true);
    } catch (e) {
      try { AppLogger.I.warn('Persist alarm eval file failed', domain: 'alarm', context: {'err': e.toString()}); } catch (_) {}
    }
  }

  static Future<Map<String, dynamic>?> loadLastAlarmEval() async {
    if (_lastAlarmEvalCache != null) return _lastAlarmEvalCache;
    // Try prefs first
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_alarmEvalPrefsKey);
      if (raw != null) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        _lastAlarmEvalCache = decoded;
        return decoded;
      }
    } catch (_) {}
    // Fallback to file
    try {
      final dir = await getApplicationSupportDirectory();
      final f = File('${dir.path}/$_alarmEvalFileName');
      if (await f.exists()) {
        final raw = await f.readAsString();
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        _lastAlarmEvalCache = decoded;
        return decoded;
      }
    } catch (_) {}
    return null;
  }

  // ---------------- Helper: Session Commit & ETA Source Logging ---------------
  void _maybeEmitSessionCommit({required String routeKey, required Map<String, dynamic> directions}) {
    if (TrackingService._sessionCommitLogged) return;
    try {
      // Compute rough route length (use registry entry if available)
      double? routeLen;
      try {
        final entry = _registry.entries.firstWhere((e) => e.key == routeKey, orElse: () => throw 'na');
        routeLen = entry.lengthMeters;
      } catch (_) {
        routeLen = null;
      }
      // Sum stops cumulative if available
      final totalStops = _stepStopsCumulative.isNotEmpty ? _stepStopsCumulative.last : null;
      final routeEventsByType = <String, int>{};
      for (final ev in _routeEvents) {
        routeEventsByType.update(ev.type, (v) => v + 1, ifAbsent: () => 1);
      }
      // Attempt initial ETA extraction (variant + value)
      double? firstEtaSec;
      String etaVariant = 'none';
      try {
        final routes = (directions['routes'] as List?) ?? const [];
        if (routes.isNotEmpty) {
          final route = routes.first as Map<String, dynamic>;
          final legs = (route['legs'] as List?) ?? const [];
          if (legs.isNotEmpty) {
            final leg = legs.first as Map<String, dynamic>;
            final durVal = ((leg['duration'] as Map<String, dynamic>?)?['value']) as num?;
            final durTraffic = ((leg['duration_in_traffic'] as Map<String, dynamic>?)?['value']) as num?;
            if (durTraffic != null) { firstEtaSec = durTraffic.toDouble(); etaVariant = 'leg.duration_in_traffic.value'; }
            else if (durVal != null) { firstEtaSec = durVal.toDouble(); etaVariant = 'leg.duration.value'; }
            else {
              final durText = ((leg['duration'] as Map<String, dynamic>?)?['text']) as String?;
              if (durText != null) {
                final match = RegExp(r'((\d+\.\d+|\d+)?)\s*h').firstMatch(durText.toLowerCase());
                final m2 = RegExp(r'((\d+\.\d+|\d+)?)\s*min').firstMatch(durText.toLowerCase());
                double hours = 0, mins = 0;
                if (match != null && match.group(1) != null && match.group(1)!.isNotEmpty) hours = double.tryParse(match.group(1)!) ?? 0;
                if (m2 != null && m2.group(1) != null && m2.group(1)!.isNotEmpty) mins = double.tryParse(m2.group(1)!) ?? 0;
                final sec = hours * 3600 + mins * 60;
                if (sec > 0) { firstEtaSec = sec; etaVariant = 'leg.duration.text'; }
              }
              if (firstEtaSec == null) {
                // Steps sum fallback
                double sum = 0; bool any = false;
                for (final lg in legs) {
                  final steps = ((lg as Map<String, dynamic>)['steps'] as List?) ?? const [];
                  for (final s in steps) {
                    final val = (((s as Map<String, dynamic>)['duration'] as Map<String, dynamic>?)?['value']) as num?;
                    if (val != null) { sum += val.toDouble(); any = true; }
                  }
                }
                if (any) { firstEtaSec = sum; etaVariant = 'steps.sum'; }
              }
            }
          }
        }
      } catch (_) {}
      // Emit ETA_SOURCE separately (once)
      if (!TrackingService._etaSourceLogged) {
        TrackingService._etaSourceLogged = true;
        try { AppLogger.I.info('ETA_SOURCE', domain: 'eta', context: {
          'variant': etaVariant,
          'etaSec': firstEtaSec,
        }); } catch (_) {}
      }
      AppLogger.I.info('SESSION_COMMIT', domain: 'session', context: {
        'routeKey': routeKey,
        'destLat': _destination?.latitude,
        'destLng': _destination?.longitude,
        'destName': _destinationName,
        'alarmMode': _alarmMode,
        'alarmValue': _alarmValue,
        'transitMode': _transitMode,
        'routeLengthMeters': routeLen,
        'totalStops': totalStops,
        'events': routeEventsByType,
        'firstEtaSec': firstEtaSec,
        'etaVariant': etaVariant,
        'autoResumed': TrackingService.autoResumed,
        'ts': DateTime.now().toIso8601String(),
      });
      TrackingService._sessionCommitLogged = true;
    } catch (_) {}
  }

  void _logStopsIntegrityIfNeeded() {
    try {
      AppLogger.I.debug('STOPS_DATA', domain: 'stops', context: {
        'count': _stepStopsCumulative.length,
        'totalStops': _stepStopsCumulative.isNotEmpty ? _stepStopsCumulative.last : null,
        'hasBounds': _stepBoundsMeters.isNotEmpty,
        'transitMode': _transitMode,
      });
    } catch (_) {}
  }

  @visibleForTesting
  void injectSyntheticStops(List<double> cumulativeStops) {
    _stepStopsCumulative = cumulativeStops;
    _logStopsIntegrityIfNeeded();
  }

  Future<void> applyScenarioOverrides({
    required List<RouteEventBoundary> events,
    List<double>? stepBounds,
    List<double>? stepStops,
    double? totalRouteMeters,
    double? totalStops,
    double? eventTriggerWindowMeters,
    List<Map<String, dynamic>>? milestones,
    double? totalDurationSeconds,
    Map<String, dynamic>? runConfig,
  }) async {
    final payload = <String, dynamic>{
      'events': events.map((e) => e.toJson()).toList(),
    };
    if (stepBounds != null) {
      payload['stepBounds'] = stepBounds;
      _stepBoundsMeters = stepBounds;
    }
    if (stepStops != null) {
      payload['stepStops'] = stepStops;
      _stepStopsCumulative = stepStops;
      _logStopsIntegrityIfNeeded();
    }
    if (totalRouteMeters != null) {
      payload['totalRouteMeters'] = totalRouteMeters;
    }
    if (totalStops != null) {
      payload['totalStops'] = totalStops;
    }
    if (eventTriggerWindowMeters != null) {
      payload['eventTriggerWindowMeters'] = eventTriggerWindowMeters;
    }
    if (milestones != null) {
      payload['milestones'] = milestones;
    }
    if (totalDurationSeconds != null) {
      payload['totalDurationSeconds'] = totalDurationSeconds;
    }
    if (runConfig != null) {
      payload['runConfig'] = runConfig;
    }

    _routeEvents = events;
    latestScenarioSnapshot = {
      'appliedAt': DateTime.now().toIso8601String(),
      if (totalRouteMeters != null) 'totalRouteMeters': totalRouteMeters,
      if (totalStops != null) 'totalStops': totalStops,
      if (eventTriggerWindowMeters != null) 'eventTriggerWindowMeters': eventTriggerWindowMeters,
      if (milestones != null) 'milestones': milestones,
      if (totalDurationSeconds != null) 'totalDurationSeconds': totalDurationSeconds,
      if (runConfig != null) 'runConfig': runConfig,
    };

    if (isTestMode) {
      if (totalRouteMeters != null) {
        _orchestrator?.setTotalRouteMeters(totalRouteMeters);
      }
      if (totalStops != null) {
        _orchestrator?.setTotalStops(totalStops);
      }
      if (eventTriggerWindowMeters != null) {
        _orchestrator?.setEventTriggerWindowMeters(eventTriggerWindowMeters);
      }
      if (milestones != null) {
        try {
          AppLogger.I.debug('Scenario milestones applied (test mode)', domain: 'scenario', context: {
            'count': milestones.length,
          });
        } catch (_) {}
      }
      _orchestrator?.setRouteEvents(events);
      return;
    }

    try {
      _service.invoke('applyScenarioOverrides', payload);
    } catch (e) {
      try {
        AppLogger.I.warn('Failed to send scenario overrides', domain: 'scenario', context: {
          'error': e.toString(),
        });
      } catch (_) {}
    }
  }
  // If user chooses "Ignore" action we suppress further progress notifications
  static bool suppressProgressNotifications = false;
  // Persisted suppression flag so both isolates honor it and it survives restarts
  static const String progressSuppressedKey = 'gw_progress_suppressed_v1';
  @visibleForTesting
  static Future<void> Function()? debugNativeEndTrackingHandler;
  @visibleForTesting
  static Future<void> Function()? debugNativeIgnoreTrackingHandler;

  @visibleForTesting
  static void resetNativeActionHandlersForTest() {
    debugNativeEndTrackingHandler = null;
    debugNativeIgnoreTrackingHandler = null;
  }

  static Future<void> syncTrackingActiveFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final active = prefs.getBool(TrackingSessionStateFile.trackingActiveFlagKey) ?? false;
      _trackingActive = active;
    } catch (_) {}
  }
  static Future<void> setProgressSuppressed(bool value) async {
    suppressProgressNotifications = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(progressSuppressedKey, value);
    } catch (_) {}
  }
  static Future<bool> isProgressSuppressed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(progressSuppressedKey) ?? false;
    } catch (_) { return suppressProgressNotifications; }
  }
  static Map<String, dynamic>? latestScenarioSnapshot;

  Future<void> handleNativeEndTrackingFromNotification({String? source}) async {
    if (debugNativeEndTrackingHandler != null) {
      await debugNativeEndTrackingHandler!.call();
    } else {
      if (_trackingActive || autoResumed) {
        await stopTracking();
      }
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('flutter.native_end_tracking_signal_v1');
      await prefs.setBool(TrackingSessionStateFile.trackingActiveFlagKey, false);
    } catch (_) {}
  }

  static Future<void> handleNativeIgnoreTrackingFromNotification({String? source}) async {
    if (debugNativeIgnoreTrackingHandler != null) {
      await debugNativeIgnoreTrackingHandler!.call();
      return;
    }
    await setProgressSuppressed(true);
    try {
      suppressProgressNotifications = true;
      await NotificationService().cancelJourneyProgress();
    } catch (_) {}
  }

  // Resume-pending flag: separate from fast trackingActive flag. Used when
  // a background tracking session exists but the foreground main() auto-resume
  // decision path might not run (engine reuse / activity reattach). Foreground
  // UI can poll this to force navigation into tracking screen.
  static const String resumePendingFlagKey = 'tracking_resume_pending_v1';

  static Future<void> _setResumePending(bool value, {String phase = 'unspecified'}) async {
    if (isTestMode) {
      // Avoid plugin channel in widget/unit tests (engine binding not initialized)
      print('GW_ARES_RESUME_FLAG_TEST_SKIP val=$value phase=$phase');
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(resumePendingFlagKey, value);
      print('GW_ARES_RESUME_FLAG_SET val=$value phase=$phase');
    } catch (e) {
      print('GW_ARES_RESUME_FLAG_FAIL val=$value phase=$phase err=$e');
    }
  }

  // Called by UI layer once it successfully attaches to an existing session.
  static Future<void> markUiAttached() async {
    await _setResumePending(false, phase: 'uiAttached');
    markResumedForeground();
    try {
      await NotificationService().restoreJourneyProgressIfNeeded();
    } catch (_) {}
  }

  // Foreground helper: detect and consume a pending resume flag when main()'s
  // normal auto-resume path may have been skipped (e.g. engine reuse). Returns
  // true if caller should navigate to the tracking UI (e.g. '/mapTracking').
  static Future<bool> checkAndConsumeResumePending({bool force = false}) async {
    if (isTestMode) {
      print('GW_ARES_RESUME_CONSUME_TEST_SKIP');
      return false;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final pending = prefs.getBool(resumePendingFlagKey) ?? false;
      print('GW_ARES_RESUME_FLAG_READ consumeCheck=$pending');
      if (!pending && !force) return false;
      // Cross-check fast active flag to reduce false positives.
      final fast = prefs.getBool(TrackingSessionStateFile.trackingActiveFlagKey) ?? false;
      print('GW_ARES_RESUME_FASTFLAG fast=$fast');
      if (!fast && !force) {
        await prefs.setBool(resumePendingFlagKey, false); // clear zombie
        print('GW_ARES_RESUME_FLAG_CLEAR_ZOMBIE');
        return false;
      }
      final state = await TrackingSessionStateFile.load();
      if (state == null) {
        print('GW_ARES_RESUME_NO_STATE');
        await prefs.setBool(resumePendingFlagKey, false);
        return false;
      }
      _trackingActive = true;
      autoResumed = true;
      await prefs.setBool(resumePendingFlagKey, false);
      print('GW_ARES_RESUME_CONSUMED destLat=${state['destinationLat']} destLng=${state['destinationLng']}');
      return true;
    } catch (e) {
      print('GW_ARES_RESUME_CONSUME_FAIL err=$e');
      return false;
    }
  }

  // Allow foreground process (main isolate) to mark that a background
  // tracking session is already active (e.g. user killed UI but service stayed).
  static void markResumedForeground() {
    _trackingActive = true;
  }

  // Expose streams bound to background isolate controllers
  Stream<ActiveRouteState> get activeRouteStateStream => _routeStateCtrl.stream;
  Stream<RouteSwitchEvent> get routeSwitchStream => _routeSwitchCtrl.stream;
  Stream<RerouteDecision> get rerouteDecisionStream => _rerouteCtrl.stream;
  // Derived progress0..1 stream for UI widgets (route progress if route length known)
  static final _progressCtrl = StreamController<double?>.broadcast();
  static Stream<double?> get progressStream => _progressCtrl.stream;
  // Internal: last progress sent to notification to throttle updates
  static double _lastNotifiedProgress = -1;
  static DateTime _lastProgressNotifyAt = DateTime.fromMillisecondsSinceEpoch(0);
  // Alarm deduplicator (destination/time/etc). TTL 8 seconds by default (fast enough to avoid spam)
  static AlarmDeduplicator alarmDeduplicator = AlarmDeduplicator(ttl: const Duration(seconds: 8));
  static FallbackAlarmManager? _fallbackManager; // schedules coarse fallback alarm
  static DateTime _lastFallbackTighten = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _fallbackTightenDebounce = Duration(seconds: 15);
  // Persistence feature flag (mirrors central flag; can be toggled at runtime)
  static bool enablePersistence = FeatureFlags.persistence;
  static PersistenceManager? _persistence;
  // Cache for SegmentProjector when advanced projection enabled
  final Map<String, SegmentProjector> _projectorCache = {};
  // (Alarm evaluation re-entrancy guard lives at background isolate global scope.)

  Future<void> initializeService() async {
    if (isTestMode) return;
    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        isForegroundMode: true,
        autoStart: false,
        notificationChannelId: 'geowake_tracking_channel_v2',
        initialNotificationTitle: 'GeoWake Tracking',
        initialNotificationContent: 'Starting…',
        foregroundServiceNotificationId: 889,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: _onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  // MODIFIED: This method now accepts the alarm parameters from the UI
  Future<void> startTracking({
    required LatLng destination,
    required String destinationName,
    required String alarmMode,
    required double alarmValue,
    bool allowNotificationsInTest = false,
    bool useInjectedPositions = false,
  }) async {
    final Map<String, dynamic> params = {
      'destinationLat': destination.latitude,
      'destinationLng': destination.longitude,
      'destinationName': destinationName,
      'alarmMode': alarmMode,
      'alarmValue': alarmValue,
      'useInjectedPositions': useInjectedPositions,
    };
  // Clear any prior suppression (user started a new journey)
  await TrackingService.setProgressSuppressed(false);
    _lastNotifiedProgress = -1;
    _lastProgressNotifyAt = DateTime.fromMillisecondsSinceEpoch(0);
      TrackingSnapshot? persistedSnapshot;
    _trackingActive = true; // mark immediately so lifecycle pause handler doesn't kill process mid-start
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('pending_home_after_stop');
    } catch (_) {}
    // Persist lightweight session state for cold-start auto resume
    if (isTestMode && suppressPersistenceInTest) {
      print('GW_ARES_ST_SAVE_TEST_SKIP lat=${destination.latitude} lng=${destination.longitude} mode=$alarmMode val=$alarmValue');
    } else {
      try {
        print('GW_ARES_ST_SAVE_ATTEMPT lat=${destination.latitude} lng=${destination.longitude} mode=$alarmMode val=$alarmValue');
        await TrackingSessionStateFile.save({
          'destinationLat': destination.latitude,
          'destinationLng': destination.longitude,
          'destinationName': destinationName,
          'alarmMode': alarmMode,
          'alarmValue': alarmValue,
          'startedAt': DateTime.now().millisecondsSinceEpoch,
          // transitMode may not yet be definitively known (set later when directions registered)
          // but we include current _transitMode (likely false) so file shape stable; will be updated later.
          'transitMode': _transitMode,
        });
        dev.log('TrackingService: session state persisted for auto-resume', name: 'TrackingService');
        print('GW_ARES_ST_SAVE_OK');
        await _setResumePending(true, phase: 'startTrackingForeground');
        // Verify fast flag immediately after save (foreground path)
        try {
          final prefs = await SharedPreferences.getInstance();
          final fast = prefs.getBool(TrackingSessionStateFile.trackingActiveFlagKey);
          print('GW_ARES_FLAG_READ postFGSave=$fast');
        } catch (e) { print('GW_ARES_FLAG_READ_FAIL postFGSave err=$e'); }
      } catch (e) { print('GW_ARES_ST_SAVE_FAIL err=$e'); }
    }
    if (!isTestMode && TrackingService.enablePersistence) {
      try {
        TrackingService._persistence ??= PersistenceManager(baseDir: Directory.systemTemp.createTempSync());
        // Attempt load (for future: detect matching destination to restore)
        final snap = await TrackingService._persistence!.load();
        if (snap != null) {
          persistedSnapshot = snap;
          // Minimal restoration: progress + eta not directly reinstated into streams yet.
          dev.log('Loaded snapshot (ts=${snap.timestampMs}) for potential recovery', name: 'TrackingService');
        }
      } catch (_) {}
    }
    if (persistedSnapshot?.orchestratorState != null) {
      params['orchestratorState'] = Map<String, dynamic>.from(persistedSnapshot!.orchestratorState!);
    }
    if (isTestMode) {
      // In test mode, we can directly call _onStart with the parameters
      _onStart(TestServiceInstance(), initialData: params);
      return;
    }
    if (!await _service.isRunning()) {
      dev.log('TrackingService: starting background service isolate', name: 'TrackingService');
      await _service.startService();
    }
    try {
      await NotificationService().maybePromptBatteryOptimization();
    } catch (_) {}
    try {
      await NotificationService().scheduleProgressWakeFallback();
    } catch (_) {}
    try {
      await NotificationService().showJourneyProgress(
        title: 'Journey to $destinationName',
        subtitle: 'Starting…',
        progress0to1: 0,
      );
    } catch (_) {}
    // Initialize fallback manager (legacy lifecycle path)
    try {
      FallbackAlarmManager.isTestMode = TrackingService.isTestMode;
      _fallbackManager = FallbackAlarmManager(NoopAlarmScheduler());
      _fallbackManager!.onFire = (reason) async {
        // Last-resort safety alarm if primary logic failed to trigger in time.
        try {
          if (!alarmDeduplicator.shouldFire('fallback:$reason')) return;
          await NotificationService().showWakeUpAlarm(
            title: 'Wake Up (Fallback)',
            body: 'Arriving soon (safety alarm)',
            allowContinueTracking: false,
          );
        } catch (_) {}
      };
      await _fallbackManager!.schedule(const Duration(minutes: 45), reason: 'initial');
    } catch (_) {}
    _service.invoke("startTracking", params);
  }

  Future<void> stopTracking() async {
    // Make sure to stop the alarm in the foreground process first
    try {
      await AlarmPlayer.stop();
      NotificationService().stopVibration();
    } catch (e) {
      dev.log('Error stopping alarm in foreground: $e', name: 'TrackingService');
    }
    try { _fallbackManager?.cancel(reason: 'stopTracking'); } catch (_) {}
  _trackingActive = false;
  // Suppress any late progress updates after stopping
  await TrackingService.setProgressSuppressed(true);
    try { await NotificationService().cancelJourneyProgress(); } catch (_) {}
  try { await NotificationService().cancelProgressWakeFallback(); } catch (_) {}
    _lastNotifiedProgress = -1;
    _lastProgressNotifyAt = DateTime.fromMillisecondsSinceEpoch(0);
    try { await TrackingSessionStateFile.clear(); dev.log('TrackingService: session state cleared', name: 'TrackingService'); } catch (_) {}
    // Also ensure fast flag false even if clear encountered issues
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(TrackingSessionStateFile.trackingActiveFlagKey, false);
    } catch (_) {}
    // Clear resume-pending flag
    try { await _setResumePending(false, phase: 'stopTracking'); } catch (_) {}
    // Reset auto-resume indicator
    try { TrackingService.autoResumed = false; } catch (_) {}
    // Also instruct background service (if running) to stop itself so no zombie state remains
    try {
      if (await _service.isRunning()) {
        _service.invoke('stopTracking', { 'stopSelf': true });
      }
    } catch (_) {}
  }

  @visibleForTesting
  bool get fusionActive => _fusionActive;
  @visibleForTesting
  bool get alarmTriggered => _destinationAlarmFired;
  @visibleForTesting
  DateTime? get lastGpsUpdateValue => _lastGpsUpdate;
  @visibleForTesting
  LatLng? get lastValidPosition => _lastProcessedPosition;
  @visibleForTesting
  DateTime? get orchestratorTriggeredAt => _orchTriggeredAt;
}

@pragma('vm:entry-point')
bool onIosBackground(ServiceInstance service) {
  WidgetsFlutterBinding.ensureInitialized();
  try { DartPluginRegistrant.ensureInitialized(); } catch (_) {}
  return true;
}

// No top-level testing getters; use instance getters on TrackingService.