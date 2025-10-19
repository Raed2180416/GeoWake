/// diagnostics_screen.dart: Source file from lib/lib/screens/diagnostics_screen.dart
/// 
/// This annotated version provides detailed documentation for all classes, methods, and fields.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/trackingservice.dart';
import '../services/simulation/route_asset_loader.dart';
import '../services/simulation/route_simulator.dart';
import '../widgets/device_harness_panel.dart';

/// Lightweight diagnostics panel to trigger on-device tests and inspect state.
class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});
  @override
  /// createState: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

/// _DiagnosticsScreenState: Class for [brief description]
/// 
/// **Purpose**: [What this class does]
/// 
/// **Usage**: [How to use this class]
class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  String _lastAlarmEval = '—';
  String _status = '';
  final TextEditingController _stopsCtl = TextEditingController(text: '1,2,3,4,5');
  StreamSubscription? _sessionSub;
  StreamSubscription? _logTailSub;
  StreamSubscription? _alarmFireSub;
  Map<String, dynamic>? _sessionInfo;
  String? _selfTestResult;
  bool _runningHappyPath = false;
  // Live log tail buffer (recent ~200 lines)
  /// [Brief description of this field]
  final List<String> _logTail = <String>[];
  bool _showAlarmLogs = true;
  bool _showSessionLogs = true;

  @override
  /// initState: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  void initState() {
    /// initState: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    super.initState();
    /// _refreshLastEval: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    _refreshLastEval();
    /// _querySessionInfo: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    _querySessionInfo();
    /// _subscribeLogTail: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    _subscribeLogTail();
  }

  /// _runSelfTests: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Future<void> _runSelfTests() async {
    /// [Brief description of this field]
    final logs = <String>[];
    /// ok: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    String ok(String name) => '✓ $name';
    /// fail: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    String fail(String name, Object e) => '✗ $name: $e';
    try {
      // Test 1: Route asset loads
      try {
        // Reuse loader
        // ignore: import_of_legacy_library_into_null_safe
        // We'll call through a closure to avoid tight coupling
        // Using static call directly as it's lightweight
        /// load: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        final asset = await RouteAssetLoader.load('assets/routes/demo_route.json');
        /// if: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        if (asset.points.length >= 2) {
          /// add: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          logs.add(ok('Route asset loads'));
        } else {
          /// add: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          logs.add(fail('Route asset loads', 'too few points'));
        }
      /// catch: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      } catch (e) { logs.add(fail('Route asset loads', e)); }

      // Test 2: Background service responds to sessionInfo when idle
      try {
        final svc = FlutterBackgroundService();
        final c = Completer<void>();
        /// on: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        final sub = svc.on('sessionInfo').listen((event) { c.complete(); });
        /// invoke: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        svc.invoke('requestSessionInfo');
        /// timeout: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        await c.future.timeout(const Duration(seconds: 2));
        /// cancel: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        await sub.cancel();
        // Accept either empty or valid map; not throwing indicates channel is alive
        /// add: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        logs.add(ok('sessionInfo channel alive'));
      /// catch: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      } catch (e) { logs.add(fail('sessionInfo channel alive', e)); }

      // Test 3: stopTracking clears flags (foreground path)
      try {
        await TrackingService().stopTracking();
        /// getInstance: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        final prefs = await SharedPreferences.getInstance();
        /// getBool: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        final fast = prefs.getBool('tracking_active_v1') ?? false;
        /// getBool: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        final resume = prefs.getBool(TrackingService.resumePendingFlagKey) ?? false;
        /// if: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        if (!fast && !resume) {
          /// add: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          logs.add(ok('stopTracking clears flags'));
        } else {
          /// add: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          logs.add(fail('stopTracking clears flags', 'fast=$fast resume=$resume'));
        }
      /// catch: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      } catch (e) { logs.add(fail('stopTracking clears flags', e)); }

      /// setState: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      setState(() { _selfTestResult = logs.join('\n'); });
    /// catch: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    } catch (e) {
      /// setState: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      setState(() { _selfTestResult = 'Self-tests failed to run: $e'; });
    }
  }

  /// _runHappyPath: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Future<void> _runHappyPath() async {
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (_runningHappyPath) return;
    /// setState: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    setState(() { _runningHappyPath = true; _status = 'Running happy path…'; _selfTestResult = null; });
    /// [Brief description of this field]
    final logs = <String>[];
    /// ok: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    String ok(String name) => '✓ $name';
    /// fail: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    String fail(String name, Object e) => '✗ $name: $e';
    try {
      /// load: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      final asset = await RouteAssetLoader.load('assets/routes/demo_route.json');
      final sim = RouteSimulationController(polyline: asset.points, baseSpeedMps: 14.0);
      // Start tracking in distance mode with 300m threshold so it won’t trigger immediately
      /// startTrackingWithSimulation: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      await sim.startTrackingWithSimulation(destinationName: asset.name, alarmMode: 'distance', alarmValue: 300);
      /// setSpeedMultiplier: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      sim.setSpeedMultiplier(4.0);
      /// start: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      sim.start();
      // Wait a few ticks to ensure positions are injected and notifications update
      /// delayed: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      await Future.delayed(const Duration(seconds: 5));
      /// add: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      logs.add(ok('Simulation started and positions injected'));
      // Pause and stop cleanly
      /// stop: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      sim.stop();
      await TrackingService().stopTracking();
      /// add: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      logs.add(ok('Tracking stopped cleanly'));
      /// setState: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      setState(() { _selfTestResult = logs.join('\n'); _status = 'Happy path finished'; });
    /// catch: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    } catch (e) {
      /// setState: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      setState(() { _selfTestResult = fail('Happy path', e); _status = 'Happy path failed'; });
    } finally {
      /// setState: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      setState(() { _runningHappyPath = false; });
    }
  }

  /// _runAlarmShouldFire: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Future<void> _runAlarmShouldFire() async {
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (_runningHappyPath) return;
    /// setState: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    setState(() { _runningHappyPath = true; _status = 'Running alarm-fire test…'; _selfTestResult = null; });
    /// [Brief description of this field]
    final logs = <String>[];
    /// ok: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    String ok(String name) => '✓ $name';
    /// fail: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    String fail(String name, Object e) => '✗ $name: $e';
    RouteSimulationController? sim;
    StreamSubscription? fireSub;
    try {
      /// load: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      final asset = await RouteAssetLoader.load('assets/routes/demo_route.json');
      sim = RouteSimulationController(polyline: asset.points, baseSpeedMps: 14.0);
      // Expect alarm within a short distance
      /// startTrackingWithSimulation: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      await sim.startTrackingWithSimulation(destinationName: asset.name, alarmMode: 'distance', alarmValue: 40);
      // Listen for background fireAlarm bridge
      final svc = FlutterBackgroundService();
      final completer = Completer<void>();
      /// on: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      fireSub = svc.on('fireAlarm').listen((event) {
        /// complete: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        completer.complete();
      });
      /// setSpeedMultiplier: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      sim.setSpeedMultiplier(8.0);
      /// start: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      sim.start();
      // Wait for up to 25s for the alarm
      /// timeout: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      await completer.future.timeout(const Duration(seconds: 25));
      /// add: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      logs.add(ok('Alarm fired and notification shown'));
    /// catch: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    } catch (e) {
      /// add: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      logs.add(fail('Alarm fired within window', e));
    } finally {
      /// cancel: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      try { await fireSub?.cancel(); } catch (_) {}
      /// stop: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      try { sim?.stop(); } catch (_) {}
      try { await TrackingService().stopTracking(); } catch (_) {}
      /// setState: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      setState(() { _selfTestResult = logs.join('\n'); _status = 'Alarm-fire test finished'; _runningHappyPath = false; });
    }
  }

  /// _querySessionInfo: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Future<void> _querySessionInfo() async {
    try {
      final svc = FlutterBackgroundService();
      /// on: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      _sessionSub = svc.on('sessionInfo').listen((event) {
        /// setState: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        setState(() { _sessionInfo = (event as Map?)?.cast<String, dynamic>(); });
      });
      /// invoke: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      svc.invoke('requestSessionInfo');
    /// catch: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    } catch (_) {}
  }

  /// _subscribeLogTail: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  void _subscribeLogTail() {
    try {
      final svc = FlutterBackgroundService();
      /// on: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      _logTailSub = svc.on('logTail').listen((event) {
        /// if: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        if (!mounted) return;
        try {
          final domain = (event?['domain'] as String?) ?? '';
          final level = (event?['level'] as String?) ?? '';
          final msg = (event?['message'] as String?) ?? '';
          String ctx = '';
          /// [Brief description of this field]
          final rawCtx = event?['context'];
          /// if: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          if (rawCtx != null) {
            /// withIndent: [Brief description of what this function does]
            /// 
            /// **Parameters**: [Describe parameters if any]
            /// **Returns**: [Describe return value]
            ctx = ' ' + const JsonEncoder.withIndent(' ').convert(rawCtx);
          }
          /// now: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          final line = '[${DateTime.now().toIso8601String()}][$level][$domain] $msg$ctx';
          /// add: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          _logTail.add(line);
          /// if: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          if (_logTail.length > 200) {
            /// removeRange: [Brief description of what this function does]
            /// 
            /// **Parameters**: [Describe parameters if any]
            /// **Returns**: [Describe return value]
            _logTail.removeRange(0, _logTail.length - 200);
          }
          /// setState: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          setState(() {});
        /// catch: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        } catch (_) {}
      });
    /// catch: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    } catch (_) {}
  }

  /// _refreshLastEval: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Future<void> _refreshLastEval() async {
    /// loadLastAlarmEval: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    final json = await TrackingService.loadLastAlarmEval();
    /// setState: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    setState(() {
      /// withIndent: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      _lastAlarmEval = json != null ? const JsonEncoder.withIndent('  ').convert(json) : 'No snapshot yet';
    });
  }

  /// _clearLastEval: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Future<void> _clearLastEval() async {
    try {
      /// getInstance: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      final prefs = await SharedPreferences.getInstance();
      /// remove: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      await prefs.remove('last_alarm_eval_v1');
      /// setState: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      setState(() { _lastAlarmEval = 'Cleared'; });
    /// catch: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    } catch (e) {
      /// setState: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      setState(() { _status = 'Failed to clear: $e'; });
    }
  }

  /// _injectStops: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Future<void> _injectStops() async {
    try {
      /// split: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      final parts = _stopsCtl.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      /// map: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      final vals = parts.map((p) => double.tryParse(p)).whereType<double>().toList();
      /// if: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      if (vals.isEmpty) {
        /// setState: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        setState(() { _status = 'Provide comma-separated numbers, e.g., 1,2,3.5'; });
        return;
      }
      // Tell background isolate to inject synthetic stops
      FlutterBackgroundService().invoke('injectSyntheticStops', {
        'stops': vals,
      });
      /// setState: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      setState(() { _status = 'Injected ${vals.length} stops points'; });
    /// catch: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    } catch (e) {
      /// setState: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      setState(() { _status = 'Inject failed: $e'; });
    }
  }

  @override
  /// dispose: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  void dispose() {
    /// cancel: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    _sessionSub?.cancel();
    /// cancel: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    _logTailSub?.cancel();
    /// cancel: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    _alarmFireSub?.cancel();
    /// dispose: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    _stopsCtl.dispose();
    /// dispose: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    super.dispose();
  }

  @override
  /// build: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Diagnostics')),
      body: Padding(
        /// all: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        padding: const EdgeInsets.all(12.0),
        child: ListView(
          children: [
            const Text('Session', style: TextStyle(fontWeight: FontWeight.bold)),
            // Allow wide key/value maps to scroll horizontally to avoid overflow
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Text(_sessionInfo?.toString() ?? 'No active session'),
            ),
            const SizedBox(height: 12),
            const Text('Stops simulation', style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(
              controller: _stopsCtl,
              decoration: const InputDecoration(
                /// stops: [Brief description of what this function does]
                /// 
                /// **Parameters**: [Describe parameters if any]
                /// **Returns**: [Describe return value]
                labelText: 'Cumulative stops (comma-separated)',
                hintText: 'e.g., 1,2,2.5,3,3.5',
              ),
            ),
            const SizedBox(height: 8),
            // Use Wrap so buttons flow on small screens and avoid overflow
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                ElevatedButton(onPressed: _injectStops, child: const Text('Inject stops')),
                ElevatedButton(onPressed: _refreshLastEval, child: const Text('Refresh eval')),
                ElevatedButton(onPressed: _clearLastEval, child: const Text('Clear eval')),
              ],
            ),
            /// if: [Brief description of what this function does]
            /// 
            /// **Parameters**: [Describe parameters if any]
            /// **Returns**: [Describe return value]
            if (_status.isNotEmpty) Padding(
              /// symmetric: [Brief description of what this function does]
              /// 
              /// **Parameters**: [Describe parameters if any]
              /// **Returns**: [Describe return value]
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(_status, style: const TextStyle(color: Colors.blueGrey)),
            ),
            const Divider(height: 24),
            const Text('Last Alarm Evaluation Snapshot', style: TextStyle(fontWeight: FontWeight.bold)),
            // Constrain height to avoid overflow on small screens
            Container(
              constraints: const BoxConstraints(maxHeight: 180),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SelectableText(_lastAlarmEval, style: const TextStyle(fontFamily: 'monospace')),
              ),
            ),
            const Divider(height: 24),
            const Text('Quick self-tests', style: TextStyle(fontWeight: FontWeight.bold)),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                ElevatedButton(onPressed: _runSelfTests, child: const Text('Run self-tests')),
                ElevatedButton(onPressed: _runningHappyPath ? null : _runHappyPath, child: const Text('Run happy path')),
                ElevatedButton(onPressed: _runningHappyPath ? null : _runAlarmShouldFire, child: const Text('Alarm should fire')),
              ],
            ),
            /// if: [Brief description of what this function does]
            /// 
            /// **Parameters**: [Describe parameters if any]
            /// **Returns**: [Describe return value]
            if (_selfTestResult != null)
              Padding(
                /// only: [Brief description of what this function does]
                /// 
                /// **Parameters**: [Describe parameters if any]
                /// **Returns**: [Describe return value]
                padding: const EdgeInsets.only(top: 8.0),
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 140),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      _selfTestResult!,
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ),
                ),
              ),
            const Divider(height: 24),
            const Text('Device harness 2.0', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const DeviceHarnessPanel(),
            const Divider(height: 24),
            const Text('Live log tail (alarm/session)', style: TextStyle(fontWeight: FontWeight.bold)),
            Wrap(
              spacing: 12,
              children: [
                FilterChip(
                  label: const Text('alarm'),
                  selected: _showAlarmLogs,
                  /// setState: [Brief description of what this function does]
                  /// 
                  /// **Parameters**: [Describe parameters if any]
                  /// **Returns**: [Describe return value]
                  onSelected: (v) => setState(() => _showAlarmLogs = v),
                ),
                FilterChip(
                  label: const Text('session'),
                  selected: _showSessionLogs,
                  /// setState: [Brief description of what this function does]
                  /// 
                  /// **Parameters**: [Describe parameters if any]
                  /// **Returns**: [Describe return value]
                  onSelected: (v) => setState(() => _showSessionLogs = v),
                ),
                TextButton(
                  /// setState: [Brief description of what this function does]
                  /// 
                  /// **Parameters**: [Describe parameters if any]
                  /// **Returns**: [Describe return value]
                  onPressed: () => setState(() => _logTail.clear()),
                  child: const Text('Clear'),
                ),
              ],
            ),
            Container(
              height: 180,
              decoration: BoxDecoration(
                /// withOpacity: [Brief description of what this function does]
                /// 
                /// **Parameters**: [Describe parameters if any]
                /// **Returns**: [Describe return value]
                color: Colors.black.withOpacity(0.05),
                /// circular: [Brief description of what this function does]
                /// 
                /// **Parameters**: [Describe parameters if any]
                /// **Returns**: [Describe return value]
                borderRadius: BorderRadius.circular(6),
              ),
              /// builder: [Brief description of what this function does]
              /// 
              /// **Parameters**: [Describe parameters if any]
              /// **Returns**: [Describe return value]
              child: ListView.builder(
                itemCount: _filteredLogs.length,
                itemBuilder: (_, i) => Text(
                  _filteredLogs[i],
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<String> get _filteredLogs {
    /// where: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    return _logTail.where((line) {
      /// contains: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      final hasAlarm = line.contains('[alarm]') || line.contains('ALARM_');
      /// contains: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      final hasSession = line.contains('[session]') || line.contains('SESSION_');
      /// return: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      return (hasAlarm && _showAlarmLogs) || (hasSession && _showSessionLogs);
    /// toList: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    }).toList(growable: false);
  }
}
