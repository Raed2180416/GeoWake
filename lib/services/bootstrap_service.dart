import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'trackingservice.dart';
import 'api_client.dart';
import 'notification_service.dart';
import 'persistence/tracking_session_state.dart';
import 'secure_hive_init.dart';

/// Fast bootstrap strategy:
/// 1. Perform ultra-lightweight auto-resume decision (SharedPreferences + optional
///    tracking_session.json load) and emit `ready` ASAP so UI can navigate off splash.
/// 2. Defer heavy / potentially slow initializations (Hive, ApiClient auth, Notification
///    channel creation, TrackingService.initializeService) in the background.
/// 3. Provide instrumentation logs for each step so slow devices / ANR reports can be
///    correlated (tokens: GW_BOOT_FAST_READY, GW_BOOT_STEP_<NAME>_OK/FAIL/TIMEOUT, GW_BOOT_LATE_DONE).
/// 4. Make the process idempotent and resilient: failures in deferred phase never block UI.

enum BootstrapPhase { idle, initializing, deciding, ready, error }

class BootstrapState {
  final BootstrapPhase phase;
  final bool autoResumed;
  final String? targetRoute; // '/mapTracking' or '/'
  final Map<String, dynamic>? mapTrackingArgs;
  final String? error;
  const BootstrapState({
    required this.phase,
    this.autoResumed = false,
    this.targetRoute,
    this.mapTrackingArgs,
    this.error,
  });
  BootstrapState copyWith({
    BootstrapPhase? phase,
    bool? autoResumed,
    String? targetRoute,
    Map<String, dynamic>? mapTrackingArgs,
    String? error,
  }) => BootstrapState(
    phase: phase ?? this.phase,
    autoResumed: autoResumed ?? this.autoResumed,
    targetRoute: targetRoute ?? this.targetRoute,
    mapTrackingArgs: mapTrackingArgs ?? this.mapTrackingArgs,
    error: error ?? this.error,
  );
}

// Internal container for early decision outputs (top-level so it can be referenced inside service)
class _EarlyDecisionResult {
  final String targetRoute; // '/' or '/mapTracking'
  final bool autoResumed;
  final Map<String,dynamic>? mapArgs;
  _EarlyDecisionResult({required this.targetRoute, required this.autoResumed, this.mapArgs});
}

class BootstrapService {
  BootstrapService._internal();
  static final BootstrapService I = BootstrapService._internal();
  final _stateCtrl = StreamController<BootstrapState>.broadcast();
  BootstrapState _state = const BootstrapState(phase: BootstrapPhase.idle);
  bool _started = false;
  Stream<BootstrapState> get states => _stateCtrl.stream;
  BootstrapState get current => _state;

  void _emit(BootstrapState s) {
    _state = s;
    _stateCtrl.add(s);
  }

  Future<void> start() async {
    if (_started) return;
    _started = true;
    final int t0 = DateTime.now().millisecondsSinceEpoch;
    print('GW_BOOT_PHASE start');
    _emit(const BootstrapState(phase: BootstrapPhase.initializing));
    // 1. EARLY DECISION (fast path)
  late final _EarlyDecisionResult early;
    try {
      await TrackingService.syncTrackingActiveFromPrefs();
      early = await _earlyDecision();
    } catch (e) {
      print('GW_BOOT_EARLY_FAIL err=$e');
      early = _EarlyDecisionResult(targetRoute: '/', autoResumed: false);
    }
    final int tReady = DateTime.now().millisecondsSinceEpoch;
    final dt = tReady - t0;
    _emit(_state.copyWith(
      phase: BootstrapPhase.ready,
      autoResumed: early.autoResumed,
      targetRoute: early.targetRoute,
      mapTrackingArgs: early.mapArgs,
    ));
    print('GW_BOOT_FAST_READY route=${early.targetRoute} autoResumed=${early.autoResumed} dtMs=$dt');
    // 2. LATE INIT (do not await for UI navigation)
    // ignore: unawaited_futures
    _lateInit(t0: t0);
  }

  Future<_EarlyDecisionResult> _earlyDecision() async {
    print('GW_ARES_BOOT_START_EARLY');
    String targetRoute = '/';
    Map<String, dynamic>? mapArgs;
    bool autoResumed = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final fastFlag = prefs.getBool(TrackingSessionStateFile.trackingActiveFlagKey) ?? false;
      print('GW_ARES_FAST_FLAG=$fastFlag');
      final bgRunning = await FlutterBackgroundService().isRunning();
      print('GW_ARES_BG_RUNNING=$bgRunning');
      Map<String,dynamic>? session;
      if (fastFlag || bgRunning) {
        // Attempt quick file load with small timeout
        try {
          session = await TrackingSessionStateFile.load().timeout(const Duration(milliseconds: 600));
        } catch (e) { print('GW_ARES_SESSION_EARLY_TIMEOUT_OR_FAIL err=$e'); }
      } else {
        print('GW_ARES_SKIP_LOAD_NO_FLAG');
      }
      if (bgRunning) {
        if (session != null) {
          TrackingService.markResumedForeground();
          TrackingService.autoResumed = true;
          autoResumed = true;
          targetRoute = '/mapTracking';
          mapArgs = {
            'lat': (session['destinationLat'] as num).toDouble(),
            'lng': (session['destinationLng'] as num).toDouble(),
            'destination': session['destinationName'] ?? 'Destination',
            'alarmMode': session['alarmMode'],
            'alarmValue': session['alarmValue'],
            'metroMode': session['alarmMode'] == 'stops',
          };
          print('GW_ARES_DECISION_ATTACH');
        } else {
            // Skip recovery event stage in early path; will be handled in late init
            print('GW_ARES_DECISION_ATTACH_NOFILE_EARLY');
        }
      } else if (session != null) {
        final lat = (session['destinationLat'] as num?)?.toDouble();
        final lng = (session['destinationLng'] as num?)?.toDouble();
        if (lat != null && lng != null) {
          TrackingService.autoResumed = true;
          autoResumed = true;
          targetRoute = '/mapTracking';
          mapArgs = {
            'lat': lat,
            'lng': lng,
            'destination': session['destinationName'] ?? 'Destination',
            'alarmMode': session['alarmMode'],
            'alarmValue': session['alarmValue'],
            'metroMode': session['alarmMode'] == 'stops',
          };
          print('GW_ARES_DECISION_RESTART name=${session['destinationName']}');
          // Fire and forget restart (best effort)
          try { TrackingService().startTracking(
            destination: LatLng(lat,lng),
            destinationName: session['destinationName'] ?? 'Destination',
            alarmMode: session['alarmMode'] ?? 'distance',
            alarmValue: (session['alarmValue'] as num?)?.toDouble() ?? 1.0,
          ); } catch (e) { print('GW_ARES_DECISION_RESTART_FAIL err=$e'); }
        } else {
          print('GW_ARES_DECISION_RESTART_ABORT missingLatLng');
        }
      } else {
        print('GW_ARES_DECISION_STANDARD');
      }
      print('GW_ARES_DECISION_SUMMARY {fastFlag:$fastFlag,bgRunning:$bgRunning,autoResumed:$autoResumed,route:$targetRoute}');
    } catch (e) {
      print('GW_ARES_BOOT_EXCEPTION_EARLY err=$e');
    }
    return _EarlyDecisionResult(targetRoute: targetRoute, autoResumed: autoResumed, mapArgs: mapArgs);
  }

  Future<void> _lateInit({required int t0}) async {
    final int start = DateTime.now().millisecondsSinceEpoch;
    print('GW_BOOT_LATE_START');
    // Steps executed in parallel with individual timeouts to avoid indefinite stall
    Future<void> _guard(String name, Future<void> Function() action) async {
      final int s = DateTime.now().millisecondsSinceEpoch;
      try {
        await action().timeout(const Duration(seconds: 5));
        final int e = DateTime.now().millisecondsSinceEpoch;
        print('GW_BOOT_STEP_${name}_OK dtMs=${e-s}');
      } on TimeoutException {
        print('GW_BOOT_STEP_${name}_TIMEOUT');
      } catch (e) {
        print('GW_BOOT_STEP_${name}_FAIL err=$e');
      }
    }
    await Future.wait([
      _guard('HIVE', () async { 
        await Hive.initFlutter();
        // Initialize encryption immediately after Hive
        await SecureHiveInit.initialize();
      }),
      _guard('API', () async { await ApiClient.instance.initialize(); }),
      _guard('NOTIF', () async { await NotificationService().initialize(); }),
      _guard('TRACKING_INIT', () async { await TrackingService().initializeService(); }),
      _guard('RESTORE_PROGRESS', () async { await NotificationService().restoreJourneyProgressIfNeeded(); }),
      _guard('RECOVERY', () async { await _attemptLateRecovery(); }),
    ]);
    final int end = DateTime.now().millisecondsSinceEpoch;
    print('GW_BOOT_LATE_DONE totalMs=${end-start} sinceAppStart=${end-t0}');
  }

  Future<void> _attemptLateRecovery() async {
    // If we attached early without session file but bg service running, attempt recovery event now.
    if (!TrackingService.autoResumed) return; // only relevant if autoResumed & missing args already handled
    // Heuristic: if UI already has map args we skip (mapTrackingArgs != null)
    if (_state.mapTrackingArgs != null) return;
    print('GW_ARES_LATE_RECOVERY_START');
    try {
      final service = FlutterBackgroundService();
      final isRunning = await service.isRunning();
      if (!isRunning) { print('GW_ARES_LATE_RECOVERY_SKIP notRunning'); return; }
      Map<String, dynamic>? recovered;
      final completer = Completer<void>();
      late StreamSubscription sub;
      try { sub = service.on('sessionInfo').listen((data) { if (data == null) return; recovered = Map<String,dynamic>.from(data); print('GW_ARES_RECOVER_INFO_LATE event=$data'); completer.complete(); }); } catch (e) { print('GW_ARES_RECOVER_LISTEN_FAIL_LATE err=$e'); }
      try { service.invoke('requestSessionInfo'); } catch (e) { print('GW_ARES_RECOVER_INVOKE_FAIL_LATE err=$e'); }
      try { await completer.future.timeout(const Duration(milliseconds: 1500)); } catch (_) { print('GW_ARES_RECOVER_TIMEOUT_LATE'); }
      try {
        await sub.cancel();
      } catch (e) {
        if (!e.toString().contains('already') && !e.toString().contains('closed')) {
          print('GW_ARES_RECOVER_CANCEL_FAIL err=$e');
        }
      }
      if (recovered != null && recovered['empty'] != true && recovered['error'] != true) {
        final lat = (recovered['destinationLat'] as num?)?.toDouble();
        final lng = (recovered['destinationLng'] as num?)?.toDouble();
        if (lat != null && lng != null) {
          print('GW_ARES_RECOVER_SUCCESS_LATE lat=$lat lng=$lng');
          // Persist for next launch resilience
          try { await TrackingSessionStateFile.save({
            'destinationLat': lat,
            'destinationLng': lng,
            'destinationName': recovered['destinationName'] ?? 'Destination',
            'alarmMode': recovered['alarmMode'] ?? 'distance',
            'alarmValue': (recovered['alarmValue'] as num?)?.toDouble() ?? 1.0,
            'startedAt': DateTime.now().millisecondsSinceEpoch,
          }); } catch (e) { print('GW_ARES_RECOVER_SAVE_FAIL_LATE err=$e'); }
          // If state still pointing to home (rare race), we could emit updated args (not changing phase)
          if (_state.targetRoute != '/mapTracking') {
            _emit(_state.copyWith(targetRoute: '/mapTracking', mapTrackingArgs: {
              'lat': lat,
              'lng': lng,
              'destination': recovered['destinationName'] ?? 'Destination',
              'alarmMode': recovered['alarmMode'],
              'alarmValue': recovered['alarmValue'],
              'metroMode': recovered['alarmMode'] == 'stops',
            }));
            print('GW_ARES_LATE_RECOVERY_EMIT');
          }
        } else {
          print('GW_ARES_RECOVER_FAIL_LATE missingLatLng');
        }
      } else {
        print('GW_ARES_RECOVER_FAIL_LATE noData');
      }
    } catch (e) {
      print('GW_ARES_LATE_RECOVERY_EXCEPTION err=$e');
    }
  }
  
  /// Dispose of resources to prevent memory leaks.
  void dispose() {
    if (!_stateCtrl.isClosed) {
      _stateCtrl.close();
    }
  }
}
