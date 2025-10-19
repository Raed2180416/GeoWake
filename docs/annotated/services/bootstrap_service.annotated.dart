/// bootstrap_service.dart: Source file from lib/lib/services/bootstrap_service.dart
/// 
/// This annotated version provides detailed documentation for all classes, methods, and fields.

import 'dart:async';
import 'package:flutter/foundation.dart' show kDebugMode, kProfileMode;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'trackingservice.dart';
import 'api_client.dart';
import 'notification_service.dart';
import 'persistence/tracking_session_state.dart';
import '../debug/dev_server.dart';

/// Fast bootstrap strategy:
/// 1. Perform ultra-lightweight auto-resume decision (SharedPreferences + optional
///    tracking_session.json load) and emit `ready` ASAP so UI can navigate off splash.
/// 2. Defer heavy / potentially slow initializations (Hive, ApiClient auth, Notification
///    channel creation, TrackingService.initializeService) in the background.
/// 3. Provide instrumentation logs for each step so slow devices / ANR reports can be
///    correlated (tokens: GW_BOOT_FAST_READY, GW_BOOT_STEP_<NAME>_OK/FAIL/TIMEOUT, GW_BOOT_LATE_DONE).
/// 4. Make the process idempotent and resilient: failures in deferred phase never block UI.

enum BootstrapPhase { idle, initializing, deciding, ready, error }

/// BootstrapState: Class for [brief description]
/// 
/// **Purpose**: [What this class does]
/// 
/// **Usage**: [How to use this class]
class BootstrapState {
  /// [Brief description of this field]
  final BootstrapPhase phase;
  /// [Brief description of this field]
  final bool autoResumed;
  /// [Brief description of this field]
  final String? targetRoute; // '/mapTracking' or '/'
  /// [Brief description of this field]
  final Map<String, dynamic>? mapTrackingArgs;
  /// [Brief description of this field]
  final String? error;
  const BootstrapState({
    required this.phase,
    this.autoResumed = false,
    this.targetRoute,
    this.mapTrackingArgs,
    this.error,
  });
  /// copyWith: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
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
/// _EarlyDecisionResult: Class for [brief description]
/// 
/// **Purpose**: [What this class does]
/// 
/// **Usage**: [How to use this class]
class _EarlyDecisionResult {
  /// [Brief description of this field]
  final String targetRoute; // '/' or '/mapTracking'
  /// [Brief description of this field]
  final bool autoResumed;
  /// [Brief description of this field]
  final Map<String,dynamic>? mapArgs;
  /// _EarlyDecisionResult: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  _EarlyDecisionResult({required this.targetRoute, required this.autoResumed, this.mapArgs});
}

/// BootstrapService: Class for [brief description]
/// 
/// **Purpose**: [What this class does]
/// 
/// **Usage**: [How to use this class]
class BootstrapService {
  /// _internal: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  BootstrapService._internal();
  /// _internal: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  static final BootstrapService I = BootstrapService._internal();
  /// broadcast: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  final _stateCtrl = StreamController<BootstrapState>.broadcast();
  BootstrapState _state = const BootstrapState(phase: BootstrapPhase.idle);
  bool _started = false;
  Stream<BootstrapState> get states => _stateCtrl.stream;
  BootstrapState get current => _state;

  /// _emit: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  void _emit(BootstrapState s) {
    _state = s;
    /// add: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    _stateCtrl.add(s);
  }

  /// start: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Future<void> start() async {
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (_started) return;
    _started = true;
    /// now: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    final int t0 = DateTime.now().millisecondsSinceEpoch;
    /// print: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    print('GW_BOOT_PHASE start');
    /// _emit: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    _emit(const BootstrapState(phase: BootstrapPhase.initializing));
    // 1. EARLY DECISION (fast path)
  /// [Brief description of this field]
  late final _EarlyDecisionResult early;
    try {
      /// syncTrackingActiveFromPrefs: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      await TrackingService.syncTrackingActiveFromPrefs();
      /// _earlyDecision: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      early = await _earlyDecision();
    /// catch: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    } catch (e) {
      /// print: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      print('GW_BOOT_EARLY_FAIL err=$e');
      /// _EarlyDecisionResult: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      early = _EarlyDecisionResult(targetRoute: '/', autoResumed: false);
    }
    /// now: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    final int tReady = DateTime.now().millisecondsSinceEpoch;
    /// [Brief description of this field]
    final dt = tReady - t0;
    /// _emit: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    _emit(_state.copyWith(
      phase: BootstrapPhase.ready,
      autoResumed: early.autoResumed,
      targetRoute: early.targetRoute,
      mapTrackingArgs: early.mapArgs,
    ));
    /// print: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    print('GW_BOOT_FAST_READY route=${early.targetRoute} autoResumed=${early.autoResumed} dtMs=$dt');
    // Start lightweight dev server after UI navigates
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (kDebugMode || kProfileMode) {
      // ignore: unawaited_futures
      /// start: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      DevServer.start();
    }
    // 2. LATE INIT (do not await for UI navigation)
    // ignore: unawaited_futures
    /// _lateInit: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    _lateInit(t0: t0);
  }

  /// _earlyDecision: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Future<_EarlyDecisionResult> _earlyDecision() async {
    /// print: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    print('GW_ARES_BOOT_START_EARLY');
    String targetRoute = '/';
    Map<String, dynamic>? mapArgs;
    bool autoResumed = false;
    try {
      /// getInstance: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      final prefs = await SharedPreferences.getInstance();
      /// getBool: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      final fastFlag = prefs.getBool(TrackingSessionStateFile.trackingActiveFlagKey) ?? false;
      /// print: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      print('GW_ARES_FAST_FLAG=$fastFlag');
      final bgRunning = await FlutterBackgroundService().isRunning();
      /// print: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      print('GW_ARES_BG_RUNNING=$bgRunning');
      Map<String,dynamic>? session;
      /// if: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      if (fastFlag || bgRunning) {
        // Attempt quick file load with small timeout
        try {
          /// load: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          session = await TrackingSessionStateFile.load().timeout(const Duration(milliseconds: 600));
        /// catch: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        } catch (e) { print('GW_ARES_SESSION_EARLY_TIMEOUT_OR_FAIL err=$e'); }
      } else {
        /// print: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        print('GW_ARES_SKIP_LOAD_NO_FLAG');
      }
      /// if: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      if (bgRunning) {
        /// if: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        if (session != null) {
          /// markResumedForeground: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          TrackingService.markResumedForeground();
          TrackingService.autoResumed = true;
          autoResumed = true;
          targetRoute = '/mapTracking';
          mapArgs = {
            /// toDouble: [Brief description of what this function does]
            /// 
            /// **Parameters**: [Describe parameters if any]
            /// **Returns**: [Describe return value]
            'lat': (session['destinationLat'] as num).toDouble(),
            /// toDouble: [Brief description of what this function does]
            /// 
            /// **Parameters**: [Describe parameters if any]
            /// **Returns**: [Describe return value]
            'lng': (session['destinationLng'] as num).toDouble(),
            'destination': session['destinationName'] ?? 'Destination',
            'alarmMode': session['alarmMode'],
            'alarmValue': session['alarmValue'],
            'metroMode': session['alarmMode'] == 'stops',
          };
          /// print: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          print('GW_ARES_DECISION_ATTACH');
        } else {
            // Skip recovery event stage in early path; will be handled in late init
            /// print: [Brief description of what this function does]
            /// 
            /// **Parameters**: [Describe parameters if any]
            /// **Returns**: [Describe return value]
            print('GW_ARES_DECISION_ATTACH_NOFILE_EARLY');
        }
      /// if: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      } else if (session != null) {
        /// toDouble: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        final lat = (session['destinationLat'] as num?)?.toDouble();
        /// toDouble: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        final lng = (session['destinationLng'] as num?)?.toDouble();
        /// if: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
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
          /// print: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          print('GW_ARES_DECISION_RESTART name=${session['destinationName']}');
          // Fire and forget restart (best effort)
          try { TrackingService().startTracking(
            destination: LatLng(lat,lng),
            destinationName: session['destinationName'] ?? 'Destination',
            alarmMode: session['alarmMode'] ?? 'distance',
            /// toDouble: [Brief description of what this function does]
            /// 
            /// **Parameters**: [Describe parameters if any]
            /// **Returns**: [Describe return value]
            alarmValue: (session['alarmValue'] as num?)?.toDouble() ?? 1.0,
          /// catch: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          ); } catch (e) { print('GW_ARES_DECISION_RESTART_FAIL err=$e'); }
        } else {
          /// print: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          print('GW_ARES_DECISION_RESTART_ABORT missingLatLng');
        }
      } else {
        /// print: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        print('GW_ARES_DECISION_STANDARD');
      }
      /// print: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      print('GW_ARES_DECISION_SUMMARY {fastFlag:$fastFlag,bgRunning:$bgRunning,autoResumed:$autoResumed,route:$targetRoute}');
    /// catch: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    } catch (e) {
      /// print: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      print('GW_ARES_BOOT_EXCEPTION_EARLY err=$e');
    }
    /// _EarlyDecisionResult: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    return _EarlyDecisionResult(targetRoute: targetRoute, autoResumed: autoResumed, mapArgs: mapArgs);
  }

  /// _lateInit: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Future<void> _lateInit({required int t0}) async {
    /// now: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    final int start = DateTime.now().millisecondsSinceEpoch;
    /// print: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    print('GW_BOOT_LATE_START');
    // Steps executed in parallel with individual timeouts to avoid indefinite stall
    /// _guard: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    Future<void> _guard(String name, Future<void> Function() action) async {
      /// now: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      final int s = DateTime.now().millisecondsSinceEpoch;
      try {
        /// action: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        await action().timeout(const Duration(seconds: 5));
        /// now: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        final int e = DateTime.now().millisecondsSinceEpoch;
        /// print: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        print('GW_BOOT_STEP_${name}_OK dtMs=${e-s}');
      } on TimeoutException {
        /// print: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        print('GW_BOOT_STEP_${name}_TIMEOUT');
      /// catch: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      } catch (e) {
        /// print: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        print('GW_BOOT_STEP_${name}_FAIL err=$e');
      }
    }
    /// wait: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    await Future.wait([
      /// _guard: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      _guard('HIVE', () async { await Hive.initFlutter(); }),
      /// _guard: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      _guard('API', () async { await ApiClient.instance.initialize(); }),
      /// _guard: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      _guard('NOTIF', () async { await NotificationService().initialize(); }),
      /// _guard: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      _guard('TRACKING_INIT', () async { await TrackingService().initializeService(); }),
      /// _guard: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      _guard('RESTORE_PROGRESS', () async { await NotificationService().restoreJourneyProgressIfNeeded(); }),
      /// _guard: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      _guard('RECOVERY', () async { await _attemptLateRecovery(); }),
    ]);
    /// now: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    final int end = DateTime.now().millisecondsSinceEpoch;
    /// print: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    print('GW_BOOT_LATE_DONE totalMs=${end-start} sinceAppStart=${end-t0}');
  }

  /// _attemptLateRecovery: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Future<void> _attemptLateRecovery() async {
    // If we attached early without session file but bg service running, attempt recovery event now.
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (!TrackingService.autoResumed) return; // only relevant if autoResumed & missing args already handled
    // Heuristic: if UI already has map args we skip (mapTrackingArgs != null)
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (_state.mapTrackingArgs != null) return;
    /// print: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    print('GW_ARES_LATE_RECOVERY_START');
    try {
      final service = FlutterBackgroundService();
      /// isRunning: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      final isRunning = await service.isRunning();
      /// if: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      if (!isRunning) { print('GW_ARES_LATE_RECOVERY_SKIP notRunning'); return; }
      Map<String, dynamic>? recovered;
      final completer = Completer<void>();
      /// [Brief description of this field]
      late StreamSubscription sub;
      /// on: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      try { sub = service.on('sessionInfo').listen((data) { if (data == null) return; recovered = Map<String,dynamic>.from(data); print('GW_ARES_RECOVER_INFO_LATE event=$data'); completer.complete(); }); } catch (e) { print('GW_ARES_RECOVER_LISTEN_FAIL_LATE err=$e'); }
      /// invoke: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      try { service.invoke('requestSessionInfo'); } catch (e) { print('GW_ARES_RECOVER_INVOKE_FAIL_LATE err=$e'); }
      /// timeout: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      try { await completer.future.timeout(const Duration(milliseconds: 1500)); } catch (_) { print('GW_ARES_RECOVER_TIMEOUT_LATE'); }
      /// cancel: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      try { await sub.cancel(); } catch (_) {}
      /// if: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      if (recovered != null && recovered!['empty'] != true && recovered!['error'] != true) {
        /// toDouble: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        final lat = (recovered!['destinationLat'] as num?)?.toDouble();
        /// toDouble: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        final lng = (recovered!['destinationLng'] as num?)?.toDouble();
        /// if: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        if (lat != null && lng != null) {
          /// print: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          print('GW_ARES_RECOVER_SUCCESS_LATE lat=$lat lng=$lng');
          // Persist for next launch resilience
          /// save: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          try { await TrackingSessionStateFile.save({
            'destinationLat': lat,
            'destinationLng': lng,
            'destinationName': recovered!['destinationName'] ?? 'Destination',
            'alarmMode': recovered!['alarmMode'] ?? 'distance',
            /// toDouble: [Brief description of what this function does]
            /// 
            /// **Parameters**: [Describe parameters if any]
            /// **Returns**: [Describe return value]
            'alarmValue': (recovered!['alarmValue'] as num?)?.toDouble() ?? 1.0,
            /// now: [Brief description of what this function does]
            /// 
            /// **Parameters**: [Describe parameters if any]
            /// **Returns**: [Describe return value]
            'startedAt': DateTime.now().millisecondsSinceEpoch,
          /// catch: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          }); } catch (e) { print('GW_ARES_RECOVER_SAVE_FAIL_LATE err=$e'); }
          // If state still pointing to home (rare race), we could emit updated args (not changing phase)
          /// if: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          if (_state.targetRoute != '/mapTracking') {
            /// _emit: [Brief description of what this function does]
            /// 
            /// **Parameters**: [Describe parameters if any]
            /// **Returns**: [Describe return value]
            _emit(_state.copyWith(targetRoute: '/mapTracking', mapTrackingArgs: {
              'lat': lat,
              'lng': lng,
              'destination': recovered!['destinationName'] ?? 'Destination',
              'alarmMode': recovered!['alarmMode'],
              'alarmValue': recovered!['alarmValue'],
              'metroMode': recovered!['alarmMode'] == 'stops',
            }));
            /// print: [Brief description of what this function does]
            /// 
            /// **Parameters**: [Describe parameters if any]
            /// **Returns**: [Describe return value]
            print('GW_ARES_LATE_RECOVERY_EMIT');
          }
        } else {
          /// print: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          print('GW_ARES_RECOVER_FAIL_LATE missingLatLng');
        }
      } else {
        /// print: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        print('GW_ARES_RECOVER_FAIL_LATE noData');
      }
    /// catch: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    } catch (e) {
      /// print: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      print('GW_ARES_LATE_RECOVERY_EXCEPTION err=$e');
    }
  }
}
