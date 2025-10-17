import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../services/simulation/metro_route_scenario.dart';
import '../services/trackingservice.dart';
import '../services/notification_service.dart';

typedef HarnessTestRunner = Future<HarnessTestResult> Function(HarnessTestContext context);

class HarnessTestDefinition {
  const HarnessTestDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.runner,
  });

  final String id;
  final String title;
  final String description;
  final HarnessTestRunner runner;
}

class HarnessTestResult {
  const HarnessTestResult({
    required this.success,
    required this.duration,
    required this.logs,
    this.extras = const <String, dynamic>{},
    this.error,
  });

  factory HarnessTestResult.success({
    required Duration duration,
    required List<String> logs,
    Map<String, dynamic>? extras,
  }) {
    return HarnessTestResult(
      success: true,
      duration: duration,
      logs: List.unmodifiable(logs),
      extras: extras ?? const <String, dynamic>{},
    );
  }

  factory HarnessTestResult.failure({
    required Duration duration,
    required List<String> logs,
    required String error,
    Map<String, dynamic>? extras,
  }) {
    return HarnessTestResult(
      success: false,
      duration: duration,
      logs: List.unmodifiable(logs),
      extras: extras ?? const <String, dynamic>{},
      error: error,
    );
  }

  final bool success;
  final Duration duration;
  final List<String> logs;
  final Map<String, dynamic> extras;
  final String? error;

  HarnessTestResult copyWithLogs(List<String> logs) {
    return HarnessTestResult(
      success: success,
      duration: duration,
      logs: List.unmodifiable(logs),
      extras: extras,
      error: error,
    );
  }
}

class HarnessTestContext {
  HarnessTestContext({required void Function(String line) onLog})
      : _onLog = onLog,
        service = FlutterBackgroundService();

  final FlutterBackgroundService service;
  final void Function(String) _onLog;
  final List<String> _logs = <String>[];
  final List<StreamSubscription<dynamic>> _subscriptions = <StreamSubscription<dynamic>>[];

  List<String> get logs => List.unmodifiable(_logs);

  void log(String message) {
    final line = '[${DateTime.now().toIso8601String()}] $message';
    _logs.add(line);
    _onLog(line);
  }

  StreamSubscription<dynamic> listenService(String event, void Function(dynamic data) handler) {
    final sub = service.on(event).listen(handler);
    _subscriptions.add(sub);
    return sub;
  }

  Future<Map<String, dynamic>?> requestSessionInfo({Duration timeout = const Duration(seconds: 3)}) async {
    final completer = Completer<Map<String, dynamic>?>();
    late StreamSubscription<dynamic> sub;
    sub = service.on('sessionInfo').listen((event) {
      try {
        completer.complete((event as Map?)?.cast<String, dynamic>());
      } finally {
        sub.cancel();
      }
    });
    try {
      service.invoke('requestSessionInfo');
    } catch (_) {}
    try {
      return await completer.future.timeout(timeout);
    } on TimeoutException {
      await sub.cancel();
      return null;
    }
  }

  Future<void> dispose() async {
    for (final sub in _subscriptions) {
      try {
        await sub.cancel();
      } catch (_) {}
    }
    _subscriptions.clear();
  }
}

class HarnessTestFailure implements Exception {
  HarnessTestFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

class _MetroHarnessWorkbench extends StatefulWidget {
  const _MetroHarnessWorkbench();

  @override
  State<_MetroHarnessWorkbench> createState() => _MetroHarnessWorkbenchState();
}

class _MetroHarnessWorkbenchState extends State<_MetroHarnessWorkbench> {
  final MetroRouteScenarioRunner _runner = MetroRouteScenarioRunner();
  final FlutterBackgroundService _service = FlutterBackgroundService();
  final TextEditingController _distanceKmCtrl = TextEditingController(text: '0.12');
  final TextEditingController _stopsCtrl = TextEditingController(text: '3');
  final TextEditingController _timeCtrl = TextEditingController(text: '5');
  final TextEditingController _eventWindowCtrl = TextEditingController(text: '120');
  final TextEditingController _speedCtrl = TextEditingController(text: '18');

  MetroAlarmMode _mode = MetroAlarmMode.distance;
  bool _running = false;
  bool _backgroundRunning = false;
  MetroScenarioSnapshot? _snapshot;
  Map<String, dynamic>? _sessionInfo;
  Map<String, dynamic>? _progressPayload;
  double? _progressFraction;
  final List<String> _logs = <String>[];
  final List<StreamSubscription<dynamic>> _subs = <StreamSubscription<dynamic>>[];
  StreamSubscription<double?>? _progressSub;
  Timer? _pollTimer;
  // Map state
  GoogleMapController? _mapController;
  // Last lat/lng tracked from background for map marker
  // ignore: unused_field
  LatLng? _lastLatLng; // kept for future use
  Marker? _meMarker;
  Marker? _destMarker;
  final CameraPosition _initialCam = const CameraPosition(target: LatLng(12.9716, 77.5946), zoom: 10);

  @override
  void initState() {
    super.initState();
    _initTelemetry();
    _progressSub = TrackingService.progressStream.listen((value) {
      setState(() {
        _progressFraction = value;
      });
    });
  }

  void _initTelemetry() {
    _backgroundRunning = false;
    Future.wait<dynamic>([
      _service.isRunning(),
      Future.value(NotificationService().lastProgressPayload),
    ]).then((values) {
      if (!mounted) return;
      setState(() {
        _backgroundRunning = values[0] as bool? ?? false;
        _progressPayload = values[1] as Map<String, dynamic>?;
      });
    }).catchError((_) {});
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      try {
        final running = await _service.isRunning();
        final payload = NotificationService().lastProgressPayload;
        if (!mounted) return;
        setState(() {
          _backgroundRunning = running;
          _progressPayload = payload;
        });
      } catch (_) {}
    });
    // Listen for live position updates for map
    try {
      final sub = _service.on('positionUpdate').listen((event) {
        if (!mounted || event == null) return;
        final lat = _safeDouble(event['lat']);
        final lng = _safeDouble(event['lng']);
        if (lat == null || lng == null) return;
        final p = LatLng(lat, lng);
        _lastLatLng = p;
        if (_mapController != null) {
          _mapController!.animateCamera(CameraUpdate.newLatLng(p));
        }
        setState(() {
          _meMarker = Marker(markerId: const MarkerId('me'), position: p, icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure));
        });
      });
      _subs.add(sub);
    } catch (_) {}

    // Proactively fetch session info to populate destination marker
    try { _service.invoke('requestSessionInfo'); } catch (_) {}

    // Update destination marker from sessionInfo events
    try {
      final sub2 = _service.on('sessionInfo').listen((event) {
        if (!mounted || event == null) return;
        try {
          final map = (event as Map).cast<String, dynamic>();
          final dLat = _safeDouble(map['destinationLat']);
          final dLng = _safeDouble(map['destinationLng']);
          final dName = map['destinationName'] as String?;
          if (dLat != null && dLng != null) {
            final dest = LatLng(dLat, dLng);
            setState(() {
              _destMarker = Marker(
                markerId: const MarkerId('dest'),
                position: dest,
                infoWindow: dName != null ? InfoWindow(title: dName) : const InfoWindow(),
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
              );
            });
          }
        } catch (_) {}
      });
      _subs.add(sub2);
    } catch (_) {}
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      try { sub.cancel(); } catch (_) {}
    }
    _subs.clear();
    try { _progressSub?.cancel(); } catch (_) {}
    _pollTimer?.cancel();
    _distanceKmCtrl.dispose();
    _stopsCtrl.dispose();
    _timeCtrl.dispose();
    _eventWindowCtrl.dispose();
    _speedCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Metro field harness', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              'Run the Nagasandra → Whitefield scenario with custom thresholds. This drives the real background service so you can watch physical notifications, alarms, and logs on the device.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            _buildControls(context),
            const SizedBox(height: 12),
            _buildStatusRow(theme),
            const SizedBox(height: 12),
            _buildMiniMap(theme),
            const SizedBox(height: 12),
            _buildSnapshotBanner(theme),
            const SizedBox(height: 12),
            _buildLogsView(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniMap(ThemeData theme) {
    return SizedBox(
      height: 200,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: GoogleMap(
          initialCameraPosition: _initialCam,
          onMapCreated: (c) { _mapController = c; },
          myLocationEnabled: false,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          markers: {
            if (_meMarker != null) _meMarker!,
            if (_destMarker != null) _destMarker!,
          },
        ),
      ),
    );
  }

  Widget _buildControls(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildModeSelector(),
            SizedBox(
              width: 150,
              child: _buildNumberField(_distanceKmCtrl, label: 'Distance km', enabled: _mode == MetroAlarmMode.distance),
            ),
            SizedBox(
              width: 130,
              child: _buildNumberField(_stopsCtrl, label: 'Stops', enabled: _mode == MetroAlarmMode.stops),
            ),
            SizedBox(
              width: 140,
              child: _buildNumberField(_timeCtrl, label: 'Time min', enabled: _mode == MetroAlarmMode.time),
            ),
            SizedBox(
              width: 140,
              child: _buildNumberField(_eventWindowCtrl, label: 'Event window (m)'),
            ),
            SizedBox(
              width: 140,
              child: _buildNumberField(_speedCtrl, label: 'Speed ×'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            ElevatedButton.icon(
              onPressed: _running ? null : _startScenario,
              icon: const Icon(Icons.play_arrow),
              label: Text(_running ? 'Running…' : 'Start simulation'),
            ),
            OutlinedButton.icon(
              onPressed: _running ? _stopScenario : null,
              icon: const Icon(Icons.stop),
              label: const Text('Stop simulation'),
            ),
            OutlinedButton.icon(
              onPressed: _requestSessionInfo,
              icon: const Icon(Icons.query_stats),
              label: const Text('Snapshot session info'),
            ),
            OutlinedButton.icon(
              onPressed: _logs.isEmpty ? null : _clearLogs,
              icon: const Icon(Icons.cleaning_services),
              label: const Text('Clear logs'),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                await TrackingService().stopTracking();
                _log('stopTracking() invoked manually.');
              },
              icon: const Icon(Icons.power_settings_new),
              label: const Text('Force stop tracking'),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                await NotificationService().restoreJourneyProgressIfNeeded();
                _log('Requested progress notification restore.');
              },
              icon: const Icon(Icons.notifications_active),
              label: const Text('Repost progress notification'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildModeSelector() {
    return DropdownButton<MetroAlarmMode>(
      value: _mode,
      onChanged: (mode) {
        if (mode == null) return;
        setState(() {
          _mode = mode;
        });
      },
      items: MetroAlarmMode.values
          .map((m) => DropdownMenuItem(
                value: m,
                child: Text(m.name.toUpperCase()),
              ))
          .toList(growable: false),
    );
  }

  Widget _buildNumberField(TextEditingController controller, {required String label, bool enabled = true}) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _buildStatusRow(ThemeData theme) {
    String trackingStatus = TrackingService.trackingActive ? 'Active' : 'Idle';
    final progressPct = _progressFraction != null && _progressFraction!.isFinite
        ? '${(_progressFraction!.clamp(0.0, 1.0) * 100).toStringAsFixed(1)}%'
        : '—';
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _statusChip('Tracking', trackingStatus, TrackingService.trackingActive, theme),
        _statusChip('Background service', _backgroundRunning ? 'Running' : 'Stopped', _backgroundRunning, theme),
        _statusChip('Notif suppressed', TrackingService.suppressProgressNotifications ? 'Yes' : 'No', !TrackingService.suppressProgressNotifications, theme, invert: true),
        _statusChip('Progress', progressPct, _progressFraction != null && _progressFraction!.isFinite, theme),
        if (_progressPayload != null)
          Text(
            'Last notif: ${(_safeDouble(_progressPayload?['progress']) ?? 0).toStringAsFixed(2)} · ${(_progressPayload?['ts'] as String?) ?? ''}',
            style: theme.textTheme.bodySmall,
          ),
        if (_sessionInfo != null && _sessionInfo!['state'] != null)
          _statusChip('Session state', '${_sessionInfo!['state']}', true, theme),
      ],
    );
  }

  Widget _statusChip(String label, String value, bool positive, ThemeData theme, {bool invert = false}) {
    final bool ok = invert ? !positive : positive;
    final Color color = ok ? const Color(0xFFE6F4EA) : const Color(0xFFFFE6E6);
    final Color textColor = ok ? Colors.green.shade700 : Colors.red.shade700;
    return Chip(
      label: Text('$label: $value', style: theme.textTheme.bodySmall?.copyWith(color: textColor, fontWeight: FontWeight.w600)),
      backgroundColor: color,
    );
  }

  Widget _buildSnapshotBanner(ThemeData theme) {
    final snap = _snapshot ?? _runner.lastSnapshot;
    if (snap == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blueGrey.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text('Start a run to capture milestone metadata and ETA summaries.', style: theme.textTheme.bodySmall),
      );
    }
    final buffer = StringBuffer()
      ..write('${snap.totalMeters.toStringAsFixed(0)} m · ')
      ..write('${snap.totalStops.toStringAsFixed(0)} stops · ')
      ..write('${(snap.totalSeconds / 60).toStringAsFixed(1)} min total · ')
      ..write('Mode: ${snap.run.mode.name}');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(buffer.toString(), style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: snap.milestones
                  .map((m) => Chip(
                        label: Text('${m.type}:${m.label} (${(m.metersFromStart / 1000).toStringAsFixed(1)} km)'),
                      ))
                  .toList(growable: false),
            ),
          ],
        ),
    );
  }

  Widget _buildLogsView(ThemeData theme) {
    if (_logs.isEmpty) {
      return Text('Logs will stream here while the harness runs.', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600, fontStyle: FontStyle.italic));
    }
    return Container(
      constraints: const BoxConstraints(maxHeight: 220),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Scrollbar(
        child: ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: _logs.length,
          itemBuilder: (_, i) => Text(
            _logs[i],
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
      ),
    );
  }

  Future<void> _startScenario() async {
    final distanceMeters = (_parseOrFallback(_distanceKmCtrl, 0.12) * 1000).clamp(10.0, 20000.0);
    final stopsThreshold = _parseOrFallback(_stopsCtrl, 3.0).clamp(1.0, 30.0);
    final timeMinutes = _parseOrFallback(_timeCtrl, 5.0).clamp(1.0, 120.0);
    final eventWindow = _parseOrFallback(_eventWindowCtrl, 120.0).clamp(20.0, 500.0);
    final speed = _parseOrFallback(_speedCtrl, 18.0).clamp(1.0, 40.0);

    final options = MetroScenarioRunOptions.defaults(_runner.config).copyWith(
      mode: _mode,
      distanceMeters: distanceMeters,
      stopsThreshold: stopsThreshold,
      timeMinutes: timeMinutes,
      eventTriggerWindowMeters: eventWindow,
      speedMultiplier: speed,
    );
    try {
      await _runner.start(options: options);
      _snapshot = _runner.lastSnapshot;
      // Update destination marker on map if we can infer destination from session info later
      // Destination position is not directly stored in snapshot; fallback to no marker here.
      _attachServiceListeners();
      setState(() {
        _running = true;
      });
      _log('Started metro scenario with mode=${options.mode.name}, distance=${options.distanceMeters.toStringAsFixed(0)}m, '
          'stops=${options.stopsThreshold.toStringAsFixed(1)}, time=${options.timeMinutes.toStringAsFixed(1)} min, window=${options.eventTriggerWindowMeters}m, speed×${options.speedMultiplier}.');
      if (_snapshot != null) {
        _log('Snapshot totals → ${_snapshot!.totalMeters.toStringAsFixed(0)} m · ${_snapshot!.totalStops.toStringAsFixed(0)} stops · ${( _snapshot!.totalSeconds / 60).toStringAsFixed(1)} min.');
      }
      _requestSessionInfo();
    } catch (e) {
      _log('Failed to start scenario: $e');
    }
  }

  Future<void> _stopScenario() async {
    try {
      await _runner.stop();
      await TrackingService().stopTracking();
    } catch (e) {
      _log('Error during stop: $e');
    } finally {
      setState(() {
        _running = false;
      });
    }
  }

  void _attachServiceListeners() {
    for (final sub in _subs) {
      try { sub.cancel(); } catch (_) {}
    }
    _subs.clear();
    _subs.add(_service.on('scenarioOverridesApplied').listen((event) {
      _log('Scenario overrides acknowledged by background isolate.');
    }));
    _subs.add(_service.on('orchestratorEvent').listen((event) {
      if (event is Map) {
        final map = Map<String, dynamic>.from(event as Map);
        final type = map['eventType'] ?? 'unknown';
        final label = map['label'] ?? '';
        final meters = _safeDouble(map['metersFromStart']);
        final km = ((meters ?? 0) / 1000).toStringAsFixed(2);
        _log('Orchestrator event → $type:$label at $km km');
      }
    }));
    _subs.add(_service.on('fireAlarm').listen((event) {
      _log('Destination alarm emitted: $event');
    }));
    _subs.add(_service.on('sessionInfo').listen((event) {
      if (!mounted) return;
      setState(() {
        _sessionInfo = (event as Map?)?.cast<String, dynamic>();
      });
      _log('Session info update → $_sessionInfo');
    }));
  }

  void _requestSessionInfo() {
    try {
      _service.invoke('requestSessionInfo');
    } catch (_) {}
  }

  void _clearLogs() {
    setState(() {
      _logs.clear();
    });
  }

  void _log(String message) {
    final line = '[${DateTime.now().toIso8601String()}] $message';
    if (!mounted) return;
    setState(() { _logs.add(line); });
  }

  double _parseOrFallback(TextEditingController controller, double fallback) {
    final parsed = double.tryParse(controller.text.trim());
    if (parsed == null) {
      controller.text = fallback.toString();
      return fallback;
    }
    return parsed;
  }
}

double? _safeDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

class DeviceHarnessPanel extends StatefulWidget {
  const DeviceHarnessPanel({super.key});

  @override
  State<DeviceHarnessPanel> createState() => _DeviceHarnessPanelState();
}

class _HarnessTestState {
  bool running = false;
  List<String> logs = <String>[];
  HarnessTestResult? result;
}

class _DeviceHarnessPanelState extends State<DeviceHarnessPanel> {
  late final List<HarnessTestDefinition> _tests = <HarnessTestDefinition>[
    HarnessTestDefinition(
      id: 'metro_multi_stage',
      title: 'Metro multi-stage alarm',
      description: 'Simulates Nagasandra → Majestic → Whitefield metro legs and validates transfer alerts and final wake-up.',
      runner: _runMetroMultiStageScenario,
    ),
    HarnessTestDefinition(
      id: 'notification_lifecycle',
      title: 'Notification lifecycle & stop action',
      description: 'Starts tracking with the metro scenario, confirms session info is populated, then verifies stopTracking clears it. Watch the persistent notification while this runs.',
      runner: _runNotificationLifecycleTest,
    ),
  ];

  late final Map<String, _HarnessTestState> _states = {
    for (final test in _tests) test.id: _HarnessTestState(),
  };

  Future<void> _runTest(HarnessTestDefinition def) async {
    final state = _states[def.id]!;
    if (state.running) return;
    setState(() {
      state.running = true;
      state.logs = <String>[];
      state.result = null;
    });

    HarnessTestResult? result;
    final startedAt = DateTime.now();
    final ctx = HarnessTestContext(onLog: (line) {
      if (!mounted) return;
      setState(() {
        state.logs = List<String>.from(state.logs)..add(line);
      });
    });

    try {
      final runResult = await def.runner(ctx);
      result = runResult.copyWithLogs(ctx.logs);
    } catch (e) {
      ctx.log('Unhandled exception: $e');
      result = HarnessTestResult.failure(
        duration: DateTime.now().difference(startedAt),
        logs: ctx.logs,
        error: e.toString(),
      );
    } finally {
      await ctx.dispose();
      try {
        await TrackingService().stopTracking();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        state.running = false;
        if (result != null) {
          state.result = result;
          state.logs = result.logs;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _MetroHarnessWorkbench(),
        ..._tests.map((def) {
          final state = _states[def.id]!;
          return _buildTestCard(def, state);
        }),
      ],
    );
  }

  Widget _buildTestCard(HarnessTestDefinition def, _HarnessTestState state) {
    final statusChip = _statusChip(state);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ExpansionTile(
        key: PageStorageKey<String>(def.id),
        title: Text(def.title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(def.description),
        trailing: statusChip,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: state.running ? null : () => _runTest(def),
                      child: Text(state.running ? 'Running…' : 'Run test'),
                    ),
                    const SizedBox(width: 12),
                    if (state.result != null)
                      Text(
                        state.result!.success
                            ? 'Pass in ${_formatDuration(state.result!.duration)}'
                            : 'Fail after ${_formatDuration(state.result!.duration)}',
                        style: TextStyle(
                          color: state.result!.success ? Colors.green.shade700 : Colors.red.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
                if (state.result?.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      state.result!.error!,
                      style: TextStyle(color: Colors.red.shade600, fontFamily: 'monospace'),
                    ),
                  ),
                if (state.result?.extras.isNotEmpty ?? false)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: _extrasView(state.result!.extras),
                  ),
                if (state.logs.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 12.0),
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    constraints: const BoxConstraints(maxHeight: 180),
                    child: Scrollbar(
                      child: ListView.builder(
                        itemCount: state.logs.length,
                        itemBuilder: (_, index) => Text(
                          state.logs[index],
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                        ),
                      ),
                    ),
                  ),
                if (!state.running && (state.logs.isEmpty))
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: Text(
                      'Logs will appear here while the test runs.',
                      style: TextStyle(color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(_HarnessTestState state) {
    if (state.running) {
      return const Chip(label: Text('Running'), backgroundColor: Color(0xFFFFF3CD));
    }
    final result = state.result;
    if (result == null) {
      return const Chip(label: Text('Idle'));
    }
    return Chip(
      label: Text(result.success ? 'Pass' : 'Fail'),
      backgroundColor: result.success ? const Color(0xFFE6F4EA) : const Color(0xFFFFE6E6),
    );
  }

  Widget _extrasView(Map<String, dynamic> extras) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: extras.entries.map((entry) {
        final value = entry.value;
        if (value is List) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${entry.key}:', style: const TextStyle(fontWeight: FontWeight.w600)),
              ...value.map((v) => Text('- $v', style: const TextStyle(fontFamily: 'monospace', fontSize: 12))).toList(growable: false),
            ],
          );
        }
        return Text(
          '${entry.key}: $value',
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        );
      }).toList(growable: false),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    final millis = d.inMilliseconds % 1000;
    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    }
    if (seconds > 0) {
      return '${seconds}.${(millis / 100).round()}s';
    }
    return '${millis}ms';
  }
}

Future<HarnessTestResult> _runMetroMultiStageScenario(HarnessTestContext ctx) async {
  final runner = MetroRouteScenarioRunner();
  final started = DateTime.now();
  final expectedMilestones = <String>{
    'mode_change:Board metro at Nagasandra',
    'transfer:Change line at Majestic interchange',
    'transfer:Prepare to exit at Whitefield metro',
  };
  final observedMilestones = <String>{};
  final eventsSummary = <String>[];
  ctx.log('Preparing metro multi-stage scenario…');
  final overridesAck = Completer<void>();
  ctx.listenService('scenarioOverridesApplied', (event) {
    ctx.log('Background acknowledged scenario overrides.');
    if (!overridesAck.isCompleted) {
      overridesAck.complete();
    }
  });
  final milestoneCompleter = Completer<void>();
  ctx.listenService('orchestratorEvent', (event) {
    final map = (event as Map?)?.cast<String, dynamic>();
    if (map == null) return;
    final type = map['eventType'] as String? ?? 'unknown';
    final label = map['label'] as String? ?? '';
  final meters = _safeDouble(map['metersFromStart']);
  final key = '$type:$label';
  final metersLabel = meters?.toStringAsFixed(1) ?? '?';
  eventsSummary.add('$key@${metersLabel}m');
  ctx.log('Event → $key at ${metersLabel} m');
    if (expectedMilestones.contains(key)) {
      observedMilestones.add(key);
      if (!milestoneCompleter.isCompleted && expectedMilestones.difference(observedMilestones).isEmpty) {
        milestoneCompleter.complete();
      }
    }
  });
  final destinationCompleter = Completer<void>();
  ctx.listenService('fireAlarm', (event) {
    ctx.log('Destination alarm bridge received.');
    if (!destinationCompleter.isCompleted) {
      destinationCompleter.complete();
    }
  });

  try {
    final runOptions = MetroScenarioRunOptions.defaults(runner.config).copyWith(
      mode: MetroAlarmMode.stops,
      stopsThreshold: 6.0,
      eventTriggerWindowMeters: 120.0,
      speedMultiplier: 1.0,
    );
    await runner.start(options: runOptions);
    final snapshot = runner.lastSnapshot;
    if (snapshot != null) {
      ctx.log(
        'Metro route snapshot → ${snapshot.totalMeters.toStringAsFixed(0)} m, '
        '${snapshot.totalStops.toStringAsFixed(0)} stops, '
        '${(snapshot.totalSeconds / 60).toStringAsFixed(1)} min.',
      );
      ctx.log('Milestones: ${snapshot.milestones.map((m) => '${m.type}:${m.label}').join(', ')}');
    }
    try {
      await overridesAck.future.timeout(const Duration(seconds: 8));
    } on TimeoutException {
      throw HarnessTestFailure('Background service did not acknowledge scenario overrides.');
    }
    runner.setSpeedMultiplier(18.0);
    ctx.log('Simulation started at 18× speed; watch the device for alarm popups.');
    try {
      await milestoneCompleter.future.timeout(const Duration(seconds: 45));
    } on TimeoutException {
      throw HarnessTestFailure('Metro milestone alerts did not all fire within 45 seconds.');
    }
    ctx.log('All metro milestone alerts observed.');
    try {
      await destinationCompleter.future.timeout(const Duration(seconds: 45));
    } on TimeoutException {
      throw HarnessTestFailure('Destination alarm did not fire after milestones completed.');
    }
    ctx.log('Destination alarm fired; tap the full-screen sheet on device to confirm.');
    return HarnessTestResult.success(
      duration: DateTime.now().difference(started),
      logs: ctx.logs,
      extras: <String, dynamic>{'events': eventsSummary},
    );
  } on HarnessTestFailure catch (e) {
    ctx.log('Harness failure: ${e.message}');
    return HarnessTestResult.failure(
      duration: DateTime.now().difference(started),
      logs: ctx.logs,
      error: e.message,
      extras: <String, dynamic>{'events': eventsSummary},
    );
  } catch (e) {
    ctx.log('Unhandled error: $e');
    return HarnessTestResult.failure(
      duration: DateTime.now().difference(started),
      logs: ctx.logs,
      error: e.toString(),
      extras: <String, dynamic>{'events': eventsSummary},
    );
  } finally {
    await runner.stop();
    try {
      await TrackingService().stopTracking();
    } catch (_) {}
  }
}

Future<HarnessTestResult> _runNotificationLifecycleTest(HarnessTestContext ctx) async {
  final runner = MetroRouteScenarioRunner();
  final started = DateTime.now();
  ctx.log('Starting metro scenario to verify notification lifecycle…');
  try {
    final runOptions = MetroScenarioRunOptions.defaults(runner.config).copyWith(
      mode: MetroAlarmMode.distance,
      distanceMeters: 180.0,
      eventTriggerWindowMeters: 90.0,
      speedMultiplier: 1.0,
    );
    await runner.start(options: runOptions);
    final snapshot = runner.lastSnapshot;
    if (snapshot != null) {
      ctx.log(
        'Notification scenario snapshot → ${snapshot.totalMeters.toStringAsFixed(0)} m, '
        '${snapshot.totalStops.toStringAsFixed(0)} stops, '
        'ETA ${(snapshot.totalSeconds / 60).toStringAsFixed(1)} min.',
      );
    }
    runner.setSpeedMultiplier(12.0);
    ctx.log('Waiting for background session info…');
    await Future.delayed(const Duration(seconds: 4));
    final sessionBefore = await ctx.requestSessionInfo(timeout: const Duration(seconds: 4));
    if (sessionBefore == null || sessionBefore['empty'] == true) {
      throw HarnessTestFailure('Session info remained empty after starting tracking.');
    }
    ctx.log('Session info populated: $sessionBefore');
    ctx.log('Requesting stopTracking (simulate pressing End Tracking).');
    await TrackingService().stopTracking();
    await Future.delayed(const Duration(seconds: 3));
    final sessionAfter = await ctx.requestSessionInfo(timeout: const Duration(seconds: 4));
    if (sessionAfter != null && sessionAfter['empty'] != true) {
      throw HarnessTestFailure('Session info still populated after stopTracking: $sessionAfter');
    }
    ctx.log('Session info cleared. Confirm the persistent notification vanished on device.');
    return HarnessTestResult.success(
      duration: DateTime.now().difference(started),
      logs: ctx.logs,
      extras: <String, dynamic>{'sessionBefore': sessionBefore},
    );
  } on HarnessTestFailure catch (e) {
    ctx.log('Harness failure: ${e.message}');
    return HarnessTestResult.failure(
      duration: DateTime.now().difference(started),
      logs: ctx.logs,
      error: e.message,
    );
  } catch (e) {
    ctx.log('Unhandled error: $e');
    return HarnessTestResult.failure(
      duration: DateTime.now().difference(started),
      logs: ctx.logs,
      error: e.toString(),
    );
  } finally {
    await runner.stop();
    try {
      await TrackingService().stopTracking();
    } catch (_) {}
  }
}
