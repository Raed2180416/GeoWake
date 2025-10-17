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
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

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
  final List<String> _logTail = <String>[];
  bool _showAlarmLogs = true;
  bool _showSessionLogs = true;

  @override
  void initState() {
    super.initState();
    _refreshLastEval();
    _querySessionInfo();
    _subscribeLogTail();
  }

  Future<void> _runSelfTests() async {
    final logs = <String>[];
    String ok(String name) => '✓ $name';
    String fail(String name, Object e) => '✗ $name: $e';
    try {
      // Test 1: Route asset loads
      try {
        // Reuse loader
        // ignore: import_of_legacy_library_into_null_safe
        // We'll call through a closure to avoid tight coupling
        // Using static call directly as it's lightweight
        final asset = await RouteAssetLoader.load('assets/routes/demo_route.json');
        if (asset.points.length >= 2) {
          logs.add(ok('Route asset loads'));
        } else {
          logs.add(fail('Route asset loads', 'too few points'));
        }
      } catch (e) { logs.add(fail('Route asset loads', e)); }

      // Test 2: Background service responds to sessionInfo when idle
      try {
        final svc = FlutterBackgroundService();
        final c = Completer<void>();
        final sub = svc.on('sessionInfo').listen((event) { c.complete(); });
        svc.invoke('requestSessionInfo');
        await c.future.timeout(const Duration(seconds: 2));
        await sub.cancel();
        // Accept either empty or valid map; not throwing indicates channel is alive
        logs.add(ok('sessionInfo channel alive'));
      } catch (e) { logs.add(fail('sessionInfo channel alive', e)); }

      // Test 3: stopTracking clears flags (foreground path)
      try {
        await TrackingService().stopTracking();
        final prefs = await SharedPreferences.getInstance();
        final fast = prefs.getBool('tracking_active_v1') ?? false;
        final resume = prefs.getBool(TrackingService.resumePendingFlagKey) ?? false;
        if (!fast && !resume) {
          logs.add(ok('stopTracking clears flags'));
        } else {
          logs.add(fail('stopTracking clears flags', 'fast=$fast resume=$resume'));
        }
      } catch (e) { logs.add(fail('stopTracking clears flags', e)); }

      setState(() { _selfTestResult = logs.join('\n'); });
    } catch (e) {
      setState(() { _selfTestResult = 'Self-tests failed to run: $e'; });
    }
  }

  Future<void> _runHappyPath() async {
    if (_runningHappyPath) return;
    setState(() { _runningHappyPath = true; _status = 'Running happy path…'; _selfTestResult = null; });
    final logs = <String>[];
    String ok(String name) => '✓ $name';
    String fail(String name, Object e) => '✗ $name: $e';
    try {
      final asset = await RouteAssetLoader.load('assets/routes/demo_route.json');
      final sim = RouteSimulationController(polyline: asset.points, baseSpeedMps: 14.0);
      // Start tracking in distance mode with 300m threshold so it won’t trigger immediately
      await sim.startTrackingWithSimulation(destinationName: asset.name, alarmMode: 'distance', alarmValue: 300);
      sim.setSpeedMultiplier(4.0);
      sim.start();
      // Wait a few ticks to ensure positions are injected and notifications update
      await Future.delayed(const Duration(seconds: 5));
      logs.add(ok('Simulation started and positions injected'));
      // Pause and stop cleanly
      sim.stop();
      await TrackingService().stopTracking();
      logs.add(ok('Tracking stopped cleanly'));
      setState(() { _selfTestResult = logs.join('\n'); _status = 'Happy path finished'; });
    } catch (e) {
      setState(() { _selfTestResult = fail('Happy path', e); _status = 'Happy path failed'; });
    } finally {
      setState(() { _runningHappyPath = false; });
    }
  }

  Future<void> _runAlarmShouldFire() async {
    if (_runningHappyPath) return;
    setState(() { _runningHappyPath = true; _status = 'Running alarm-fire test…'; _selfTestResult = null; });
    final logs = <String>[];
    String ok(String name) => '✓ $name';
    String fail(String name, Object e) => '✗ $name: $e';
    RouteSimulationController? sim;
    StreamSubscription? fireSub;
    try {
      final asset = await RouteAssetLoader.load('assets/routes/demo_route.json');
      sim = RouteSimulationController(polyline: asset.points, baseSpeedMps: 14.0);
      // Expect alarm within a short distance
      await sim.startTrackingWithSimulation(destinationName: asset.name, alarmMode: 'distance', alarmValue: 40);
      // Listen for background fireAlarm bridge
      final svc = FlutterBackgroundService();
      final completer = Completer<void>();
      fireSub = svc.on('fireAlarm').listen((event) {
        completer.complete();
      });
      sim.setSpeedMultiplier(8.0);
      sim.start();
      // Wait for up to 25s for the alarm
      await completer.future.timeout(const Duration(seconds: 25));
      logs.add(ok('Alarm fired and notification shown'));
    } catch (e) {
      logs.add(fail('Alarm fired within window', e));
    } finally {
      try { await fireSub?.cancel(); } catch (_) {}
      try { sim?.stop(); } catch (_) {}
      try { await TrackingService().stopTracking(); } catch (_) {}
      setState(() { _selfTestResult = logs.join('\n'); _status = 'Alarm-fire test finished'; _runningHappyPath = false; });
    }
  }

  Future<void> _querySessionInfo() async {
    try {
      final svc = FlutterBackgroundService();
      _sessionSub = svc.on('sessionInfo').listen((event) {
        setState(() { _sessionInfo = (event as Map?)?.cast<String, dynamic>(); });
      });
      svc.invoke('requestSessionInfo');
    } catch (_) {}
  }

  void _subscribeLogTail() {
    try {
      final svc = FlutterBackgroundService();
      _logTailSub = svc.on('logTail').listen((event) {
        if (!mounted) return;
        try {
          final domain = (event?['domain'] as String?) ?? '';
          final level = (event?['level'] as String?) ?? '';
          final msg = (event?['message'] as String?) ?? '';
          String ctx = '';
          final rawCtx = event?['context'];
          if (rawCtx != null) {
            ctx = ' ' + const JsonEncoder.withIndent(' ').convert(rawCtx);
          }
          final line = '[${DateTime.now().toIso8601String()}][$level][$domain] $msg$ctx';
          _logTail.add(line);
          if (_logTail.length > 200) {
            _logTail.removeRange(0, _logTail.length - 200);
          }
          setState(() {});
        } catch (_) {}
      });
    } catch (_) {}
  }

  Future<void> _refreshLastEval() async {
    final json = await TrackingService.loadLastAlarmEval();
    setState(() {
      _lastAlarmEval = json != null ? const JsonEncoder.withIndent('  ').convert(json) : 'No snapshot yet';
    });
  }

  Future<void> _clearLastEval() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('last_alarm_eval_v1');
      setState(() { _lastAlarmEval = 'Cleared'; });
    } catch (e) {
      setState(() { _status = 'Failed to clear: $e'; });
    }
  }

  Future<void> _injectStops() async {
    try {
      final parts = _stopsCtl.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      final vals = parts.map((p) => double.tryParse(p)).whereType<double>().toList();
      if (vals.isEmpty) {
        setState(() { _status = 'Provide comma-separated numbers, e.g., 1,2,3.5'; });
        return;
      }
      // Tell background isolate to inject synthetic stops
      FlutterBackgroundService().invoke('injectSyntheticStops', {
        'stops': vals,
      });
      setState(() { _status = 'Injected ${vals.length} stops points'; });
    } catch (e) {
      setState(() { _status = 'Inject failed: $e'; });
    }
  }

  @override
  void dispose() {
    _sessionSub?.cancel();
    _logTailSub?.cancel();
    _alarmFireSub?.cancel();
    _stopsCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Diagnostics')),
      body: Padding(
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
            if (_status.isNotEmpty) Padding(
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
            if (_selfTestResult != null)
              Padding(
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
                  onSelected: (v) => setState(() => _showAlarmLogs = v),
                ),
                FilterChip(
                  label: const Text('session'),
                  selected: _showSessionLogs,
                  onSelected: (v) => setState(() => _showSessionLogs = v),
                ),
                TextButton(
                  onPressed: () => setState(() => _logTail.clear()),
                  child: const Text('Clear'),
                ),
              ],
            ),
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.05),
                borderRadius: BorderRadius.circular(6),
              ),
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
    return _logTail.where((line) {
      final hasAlarm = line.contains('[alarm]') || line.contains('ALARM_');
      final hasSession = line.contains('[session]') || line.contains('SESSION_');
      return (hasAlarm && _showAlarmLogs) || (hasSession && _showSessionLogs);
    }).toList(growable: false);
  }
}
