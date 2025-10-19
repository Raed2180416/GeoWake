/// device_harness_panel.dart: Source file from lib/lib/widgets/device_harness_panel.dart
/// 
/// This annotated version provides detailed documentation for all classes, methods, and fields.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../services/simulation/metro_route_scenario.dart';
import '../services/trackingservice.dart';
import '../services/notification_service.dart';

typedef HarnessTestRunner = Future<HarnessTestResult> Function(HarnessTestContext context);

/// HarnessTestDefinition: Class for [brief description]
/// 
/// **Purpose**: [What this class does]
/// 
/// **Usage**: [How to use this class]
class HarnessTestDefinition {
  const HarnessTestDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.runner,
  });

  /// [Brief description of this field]
  final String id;
  /// [Brief description of this field]
  final String title;
  /// [Brief description of this field]
  final String description;
  /// [Brief description of this field]
  final HarnessTestRunner runner;
}

/// HarnessTestResult: Class for [brief description]
/// 
/// **Purpose**: [What this class does]
/// 
/// **Usage**: [How to use this class]
class HarnessTestResult {
  const HarnessTestResult({
    required this.success,
    required this.duration,
    required this.logs,
    this.extras = const <String, dynamic>{},
    this.error,
  });

  /// success: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  factory HarnessTestResult.success({
    required Duration duration,
    required List<String> logs,
    Map<String, dynamic>? extras,
  }) {
    return HarnessTestResult(
      success: true,
      duration: duration,
      /// unmodifiable: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      logs: List.unmodifiable(logs),
      extras: extras ?? const <String, dynamic>{},
    );
  }

  /// failure: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  factory HarnessTestResult.failure({
    required Duration duration,
    required List<String> logs,
    required String error,
    Map<String, dynamic>? extras,
  }) {
    return HarnessTestResult(
      success: false,
      duration: duration,
      /// unmodifiable: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      logs: List.unmodifiable(logs),
      extras: extras ?? const <String, dynamic>{},
      error: error,
    );
  }

  /// [Brief description of this field]
  final bool success;
  /// [Brief description of this field]
  final Duration duration;
  /// [Brief description of this field]
  final List<String> logs;
  /// [Brief description of this field]
  final Map<String, dynamic> extras;
  /// [Brief description of this field]
  final String? error;

  /// copyWithLogs: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  HarnessTestResult copyWithLogs(List<String> logs) {
    return HarnessTestResult(
      success: success,
      duration: duration,
      /// unmodifiable: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      logs: List.unmodifiable(logs),
      extras: extras,
      error: error,
    );
  }
}

/// HarnessTestContext: Class for [brief description]
/// 
/// **Purpose**: [What this class does]
/// 
/// **Usage**: [How to use this class]
class HarnessTestContext {
  HarnessTestContext({required void Function(String line) onLog})
      : _onLog = onLog,
        service = FlutterBackgroundService();

  /// [Brief description of this field]
  final FlutterBackgroundService service;
  final void Function(String) _onLog;
  /// [Brief description of this field]
  final List<String> _logs = <String>[];
  /// [Brief description of this field]
  final List<StreamSubscription<dynamic>> _subscriptions = <StreamSubscription<dynamic>>[];

  /// unmodifiable: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  List<String> get logs => List.unmodifiable(_logs);

  /// log: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  void log(String message) {
    /// now: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    final line = '[${DateTime.now().toIso8601String()}] $message';
    /// add: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    _logs.add(line);
    /// _onLog: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    _onLog(line);
  }

  /// listenService: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  StreamSubscription<dynamic> listenService(String event, void Function(dynamic data) handler) {
    /// on: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    final sub = service.on(event).listen(handler);
    /// add: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    _subscriptions.add(sub);
    return sub;
  }

  /// requestSessionInfo: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Future<Map<String, dynamic>?> requestSessionInfo({Duration timeout = const Duration(seconds: 3)}) async {
    final completer = Completer<Map<String, dynamic>?>();
    /// [Brief description of this field]
    late StreamSubscription<dynamic> sub;
    /// on: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    sub = service.on('sessionInfo').listen((event) {
      try {
        /// complete: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        completer.complete((event as Map?)?.cast<String, dynamic>());
      } finally {
        /// cancel: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        sub.cancel();
      }
    });
    try {
      /// invoke: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      service.invoke('requestSessionInfo');
    /// catch: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    } catch (_) {}
    try {
      /// timeout: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      return await completer.future.timeout(timeout);
    } on TimeoutException {
      /// cancel: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      await sub.cancel();
      return null;
    }
  }

  /// dispose: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Future<void> dispose() async {
    /// for: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    for (final sub in _subscriptions) {
      try {
        /// cancel: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        await sub.cancel();
      /// catch: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      } catch (_) {}
    }
    /// clear: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    _subscriptions.clear();
  }
}

/// HarnessTestFailure: Class for [brief description]
/// 
/// **Purpose**: [What this class does]
/// 
/// **Usage**: [How to use this class]
class HarnessTestFailure implements Exception {
  HarnessTestFailure(this.message);
  /// [Brief description of this field]
  final String message;
  @override
  /// toString: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  String toString() => message;
}

/// _MetroHarnessWorkbench: Class for [brief description]
/// 
/// **Purpose**: [What this class does]
/// 
/// **Usage**: [How to use this class]
class _MetroHarnessWorkbench extends StatefulWidget {
  /// _MetroHarnessWorkbench: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  const _MetroHarnessWorkbench();

  @override
  /// createState: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  State<_MetroHarnessWorkbench> createState() => _MetroHarnessWorkbenchState();
}

/// _MetroHarnessWorkbenchState: Class for [brief description]
/// 
/// **Purpose**: [What this class does]
/// 
/// **Usage**: [How to use this class]
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
  /// [Brief description of this field]
  final List<String> _logs = <String>[];
  /// [Brief description of this field]
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
    /// _initTelemetry: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    _initTelemetry();
    /// listen: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    _progressSub = TrackingService.progressStream.listen((value) {
      /// setState: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      setState(() {
        _progressFraction = value;
      });
    });
  }

  /// _initTelemetry: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  void _initTelemetry() {
    _backgroundRunning = false;
    Future.wait<dynamic>([
      /// isRunning: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      _service.isRunning(),
      /// value: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      Future.value(NotificationService().lastProgressPayload),
    /// then: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    ]).then((values) {
      /// if: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      if (!mounted) return;
      /// setState: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      setState(() {
        _backgroundRunning = values[0] as bool? ?? false;
        _progressPayload = values[1] as Map<String, dynamic>?;
      });
    /// catchError: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    }).catchError((_) {});
    /// periodic: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      try {
        /// isRunning: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        final running = await _service.isRunning();
        final payload = NotificationService().lastProgressPayload;
        /// if: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        if (!mounted) return;
        /// setState: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        setState(() {
          _backgroundRunning = running;
          _progressPayload = payload;
        });
      /// catch: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      } catch (_) {}
    });
    // Listen for live position updates for map
    try {
      /// on: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      final sub = _service.on('positionUpdate').listen((event) {
        /// if: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        if (!mounted || event == null) return;
        /// _safeDouble: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        final lat = _safeDouble(event['lat']);
        /// _safeDouble: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        final lng = _safeDouble(event['lng']);
        /// if: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        if (lat == null || lng == null) return;
        final p = LatLng(lat, lng);
        _lastLatLng = p;
        /// if: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        if (_mapController != null) {
          /// animateCamera: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          _mapController!.animateCamera(CameraUpdate.newLatLng(p));
        }
        /// setState: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        setState(() {
          _meMarker = Marker(markerId: const MarkerId('me'), position: p, icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure));
        });
      });
      /// add: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      _subs.add(sub);
    /// catch: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    } catch (_) {}

    // Proactively fetch session info to populate destination marker
    /// invoke: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    try { _service.invoke('requestSessionInfo'); } catch (_) {}

    // Update destination marker from sessionInfo events
    try {
      /// on: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      final sub2 = _service.on('sessionInfo').listen((event) {
        /// if: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        if (!mounted || event == null) return;
        try {
          final map = (event as Map).cast<String, dynamic>();
          /// _safeDouble: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          final dLat = _safeDouble(map['destinationLat']);
          /// _safeDouble: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          final dLng = _safeDouble(map['destinationLng']);
          /// [Brief description of this field]
          final dName = map['destinationName'] as String?;
          /// if: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          if (dLat != null && dLng != null) {
            final dest = LatLng(dLat, dLng);
            /// setState: [Brief description of what this function does]
            /// 
            /// **Parameters**: [Describe parameters if any]
            /// **Returns**: [Describe return value]
            setState(() {
              _destMarker = Marker(
                markerId: const MarkerId('dest'),
                position: dest,
                infoWindow: dName != null ? InfoWindow(title: dName) : const InfoWindow(),
                /// defaultMarkerWithHue: [Brief description of what this function does]
                /// 
                /// **Parameters**: [Describe parameters if any]
                /// **Returns**: [Describe return value]
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
              );
            });
          }
        /// catch: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        } catch (_) {}
      });
      /// add: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      _subs.add(sub2);
    /// catch: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    } catch (_) {}
  }

  @override
  /// dispose: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  void dispose() {
    /// for: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    for (final sub in _subs) {
      /// cancel: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      try { sub.cancel(); } catch (_) {}
    }
    /// clear: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    _subs.clear();
    /// cancel: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    try { _progressSub?.cancel(); } catch (_) {}
    /// cancel: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    _pollTimer?.cancel();
    /// dispose: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    _distanceKmCtrl.dispose();
    /// dispose: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    _stopsCtrl.dispose();
    /// dispose: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    _timeCtrl.dispose();
    /// dispose: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    _eventWindowCtrl.dispose();
    /// dispose: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    _speedCtrl.dispose();
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
    /// of: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    final theme = Theme.of(context);
    return Card(
      /// only: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        /// all: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
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
            /// _buildControls: [Brief description of what this function does]
            /// 
            /// **Parameters**: [Describe parameters if any]
            /// **Returns**: [Describe return value]
            _buildControls(context),
            const SizedBox(height: 12),
            /// _buildStatusRow: [Brief description of what this function does]
            /// 
            /// **Parameters**: [Describe parameters if any]
            /// **Returns**: [Describe return value]
            _buildStatusRow(theme),
            const SizedBox(height: 12),
            /// _buildMiniMap: [Brief description of what this function does]
            /// 
            /// **Parameters**: [Describe parameters if any]
            /// **Returns**: [Describe return value]
            _buildMiniMap(theme),
            const SizedBox(height: 12),
            /// _buildSnapshotBanner: [Brief description of what this function does]
            /// 
            /// **Parameters**: [Describe parameters if any]
            /// **Returns**: [Describe return value]
            _buildSnapshotBanner(theme),
            const SizedBox(height: 12),
            /// _buildLogsView: [Brief description of what this function does]
            /// 
            /// **Parameters**: [Describe parameters if any]
            /// **Returns**: [Describe return value]
            _buildLogsView(theme),
          ],
        ),
      ),
    );
  }

  /// _buildMiniMap: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Widget _buildMiniMap(ThemeData theme) {
    return SizedBox(
      height: 200,
      child: ClipRRect(
        /// circular: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        borderRadius: BorderRadius.circular(8),
        child: GoogleMap(
          initialCameraPosition: _initialCam,
          onMapCreated: (c) { _mapController = c; },
          myLocationEnabled: false,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          markers: {
            /// if: [Brief description of what this function does]
            /// 
            /// **Parameters**: [Describe parameters if any]
            /// **Returns**: [Describe return value]
            if (_meMarker != null) _meMarker!,
            /// if: [Brief description of what this function does]
            /// 
            /// **Parameters**: [Describe parameters if any]
            /// **Returns**: [Describe return value]
            if (_destMarker != null) _destMarker!,
          },
        ),
      ),
    );
  }

  /// _buildControls: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Widget _buildControls(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            /// _buildModeSelector: [Brief description of what this function does]
            /// 
            /// **Parameters**: [Describe parameters if any]
            /// **Returns**: [Describe return value]
            _buildModeSelector(),
            SizedBox(
              width: 150,
              /// _buildNumberField: [Brief description of what this function does]
              /// 
              /// **Parameters**: [Describe parameters if any]
              /// **Returns**: [Describe return value]
              child: _buildNumberField(_distanceKmCtrl, label: 'Distance km', enabled: _mode == MetroAlarmMode.distance),
            ),
            SizedBox(
              width: 130,
              /// _buildNumberField: [Brief description of what this function does]
              /// 
              /// **Parameters**: [Describe parameters if any]
              /// **Returns**: [Describe return value]
              child: _buildNumberField(_stopsCtrl, label: 'Stops', enabled: _mode == MetroAlarmMode.stops),
            ),
            SizedBox(
              width: 140,
              /// _buildNumberField: [Brief description of what this function does]
              /// 
              /// **Parameters**: [Describe parameters if any]
              /// **Returns**: [Describe return value]
              child: _buildNumberField(_timeCtrl, label: 'Time min', enabled: _mode == MetroAlarmMode.time),
            ),
            SizedBox(
              width: 140,
              /// _buildNumberField: [Brief description of what this function does]
              /// 
              /// **Parameters**: [Describe parameters if any]
              /// **Returns**: [Describe return value]
              child: _buildNumberField(_eventWindowCtrl, label: 'Event window (m)'),
            ),
            SizedBox(
              width: 140,
              /// _buildNumberField: [Brief description of what this function does]
              /// 
              /// **Parameters**: [Describe parameters if any]
              /// **Returns**: [Describe return value]
              child: _buildNumberField(_speedCtrl, label: 'Speed ×'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            /// icon: [Brief description of what this function does]
            /// 
            /// **Parameters**: [Describe parameters if any]
            /// **Returns**: [Describe return value]
            ElevatedButton.icon(
              onPressed: _running ? null : _startScenario,
              icon: const Icon(Icons.play_arrow),
              label: Text(_running ? 'Running…' : 'Start simulation'),
            ),
            /// icon: [Brief description of what this function does]
            /// 
            /// **Parameters**: [Describe parameters if any]
            /// **Returns**: [Describe return value]
            OutlinedButton.icon(
              onPressed: _running ? _stopScenario : null,
              icon: const Icon(Icons.stop),
              label: const Text('Stop simulation'),
            ),
            /// icon: [Brief description of what this function does]
            /// 
            /// **Parameters**: [Describe parameters if any]
            /// **Returns**: [Describe return value]
            OutlinedButton.icon(
              onPressed: _requestSessionInfo,
              icon: const Icon(Icons.query_stats),
              label: const Text('Snapshot session info'),
            ),
            /// icon: [Brief description of what this function does]
            /// 
            /// **Parameters**: [Describe parameters if any]
            /// **Returns**: [Describe return value]
            OutlinedButton.icon(
              onPressed: _logs.isEmpty ? null : _clearLogs,
              icon: const Icon(Icons.cleaning_services),
              label: const Text('Clear logs'),
            ),
            /// icon: [Brief description of what this function does]
            /// 
            /// **Parameters**: [Describe parameters if any]
            /// **Returns**: [Describe return value]
            OutlinedButton.icon(
              onPressed: () async {
                await TrackingService().stopTracking();
                /// _log: [Brief description of what this function does]
                /// 
                /// **Parameters**: [Describe parameters if any]
                /// **Returns**: [Describe return value]
                _log('stopTracking() invoked manually.');
              },
              icon: const Icon(Icons.power_settings_new),
              label: const Text('Force stop tracking'),
            ),
            /// icon: [Brief description of what this function does]
            /// 
            /// **Parameters**: [Describe parameters if any]
            /// **Returns**: [Describe return value]
            OutlinedButton.icon(
              onPressed: () async {
                await NotificationService().restoreJourneyProgressIfNeeded();
                /// _log: [Brief description of what this function does]
                /// 
                /// **Parameters**: [Describe parameters if any]
                /// **Returns**: [Describe return value]
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

  /// _buildModeSelector: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Widget _buildModeSelector() {
    return DropdownButton<MetroAlarmMode>(
      value: _mode,
      onChanged: (mode) {
        /// if: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        if (mode == null) return;
        /// setState: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        setState(() {
          _mode = mode;
        });
      },
      items: MetroAlarmMode.values
          /// map: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          .map((m) => DropdownMenuItem(
                value: m,
                child: Text(m.name.toUpperCase()),
              ))
          /// toList: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          .toList(growable: false),
    );
  }

  /// _buildNumberField: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Widget _buildNumberField(TextEditingController controller, {required String label, bool enabled = true}) {
    return TextField(
      controller: controller,
      enabled: enabled,
      /// numberWithOptions: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
    );
  }

  /// _buildStatusRow: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Widget _buildStatusRow(ThemeData theme) {
    String trackingStatus = TrackingService.trackingActive ? 'Active' : 'Idle';
    /// [Brief description of this field]
    final progressPct = _progressFraction != null && _progressFraction!.isFinite
        /// clamp: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        ? '${(_progressFraction!.clamp(0.0, 1.0) * 100).toStringAsFixed(1)}%'
        : '—';
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        /// _statusChip: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        _statusChip('Tracking', trackingStatus, TrackingService.trackingActive, theme),
        /// _statusChip: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        _statusChip('Background service', _backgroundRunning ? 'Running' : 'Stopped', _backgroundRunning, theme),
        /// _statusChip: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        _statusChip('Notif suppressed', TrackingService.suppressProgressNotifications ? 'Yes' : 'No', !TrackingService.suppressProgressNotifications, theme, invert: true),
        /// _statusChip: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        _statusChip('Progress', progressPct, _progressFraction != null && _progressFraction!.isFinite, theme),
        /// if: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        if (_progressPayload != null)
          Text(
            /// _safeDouble: [Brief description of what this function does]
            /// 
            /// **Parameters**: [Describe parameters if any]
            /// **Returns**: [Describe return value]
            'Last notif: ${(_safeDouble(_progressPayload?['progress']) ?? 0).toStringAsFixed(2)} · ${(_progressPayload?['ts'] as String?) ?? ''}',
            style: theme.textTheme.bodySmall,
          ),
        /// if: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        if (_sessionInfo != null && _sessionInfo!['state'] != null)
          /// _statusChip: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          _statusChip('Session state', '${_sessionInfo!['state']}', true, theme),
      ],
    );
  }

  /// _statusChip: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Widget _statusChip(String label, String value, bool positive, ThemeData theme, {bool invert = false}) {
    /// [Brief description of this field]
    final bool ok = invert ? !positive : positive;
    final Color color = ok ? const Color(0xFFE6F4EA) : const Color(0xFFFFE6E6);
    /// [Brief description of this field]
    final Color textColor = ok ? Colors.green.shade700 : Colors.red.shade700;
    return Chip(
      label: Text('$label: $value', style: theme.textTheme.bodySmall?.copyWith(color: textColor, fontWeight: FontWeight.w600)),
      backgroundColor: color,
    );
  }

  /// _buildSnapshotBanner: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Widget _buildSnapshotBanner(ThemeData theme) {
    /// [Brief description of this field]
    final snap = _snapshot ?? _runner.lastSnapshot;
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (snap == null) {
      return Container(
        /// all: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blueGrey.shade50,
          /// circular: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text('Start a run to capture milestone metadata and ETA summaries.', style: theme.textTheme.bodySmall),
      );
    }
    final buffer = StringBuffer()
      /// write: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      ..write('${snap.totalMeters.toStringAsFixed(0)} m · ')
      /// write: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      ..write('${snap.totalStops.toStringAsFixed(0)} stops · ')
      /// write: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      ..write('${(snap.totalSeconds / 60).toStringAsFixed(1)} min total · ')
      /// write: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      ..write('Mode: ${snap.run.mode.name}');
    return Container(
      /// all: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        /// circular: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
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
                  /// map: [Brief description of what this function does]
                  /// 
                  /// **Parameters**: [Describe parameters if any]
                  /// **Returns**: [Describe return value]
                  .map((m) => Chip(
                        label: Text('${m.type}:${m.label} (${(m.metersFromStart / 1000).toStringAsFixed(1)} km)'),
                      ))
                  /// toList: [Brief description of what this function does]
                  /// 
                  /// **Parameters**: [Describe parameters if any]
                  /// **Returns**: [Describe return value]
                  .toList(growable: false),
            ),
          ],
        ),
    );
  }

  /// _buildLogsView: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Widget _buildLogsView(ThemeData theme) {
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (_logs.isEmpty) {
      return Text('Logs will stream here while the harness runs.', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600, fontStyle: FontStyle.italic));
    }
    return Container(
      constraints: const BoxConstraints(maxHeight: 220),
      decoration: BoxDecoration(
        /// withOpacity: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        color: Colors.black.withOpacity(0.04),
        /// circular: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        borderRadius: BorderRadius.circular(8),
      ),
      child: Scrollbar(
        /// builder: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        child: ListView.builder(
          /// all: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
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

  /// _startScenario: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Future<void> _startScenario() async {
    /// _parseOrFallback: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    final distanceMeters = (_parseOrFallback(_distanceKmCtrl, 0.12) * 1000).clamp(10.0, 20000.0);
    /// _parseOrFallback: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    final stopsThreshold = _parseOrFallback(_stopsCtrl, 3.0).clamp(1.0, 30.0);
    /// _parseOrFallback: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    final timeMinutes = _parseOrFallback(_timeCtrl, 5.0).clamp(1.0, 120.0);
    /// _parseOrFallback: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    final eventWindow = _parseOrFallback(_eventWindowCtrl, 120.0).clamp(20.0, 500.0);
    /// _parseOrFallback: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    final speed = _parseOrFallback(_speedCtrl, 18.0).clamp(1.0, 40.0);

    /// defaults: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    final options = MetroScenarioRunOptions.defaults(_runner.config).copyWith(
      mode: _mode,
      distanceMeters: distanceMeters,
      stopsThreshold: stopsThreshold,
      timeMinutes: timeMinutes,
      eventTriggerWindowMeters: eventWindow,
      speedMultiplier: speed,
    );
    try {
      /// start: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      await _runner.start(options: options);
      _snapshot = _runner.lastSnapshot;
      // Update destination marker on map if we can infer destination from session info later
      // Destination position is not directly stored in snapshot; fallback to no marker here.
      /// _attachServiceListeners: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      _attachServiceListeners();
      /// setState: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      setState(() {
        _running = true;
      });
      /// _log: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      _log('Started metro scenario with mode=${options.mode.name}, distance=${options.distanceMeters.toStringAsFixed(0)}m, '
          /// toStringAsFixed: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          'stops=${options.stopsThreshold.toStringAsFixed(1)}, time=${options.timeMinutes.toStringAsFixed(1)} min, window=${options.eventTriggerWindowMeters}m, speed×${options.speedMultiplier}.');
      /// if: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      if (_snapshot != null) {
        /// _log: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        _log('Snapshot totals → ${_snapshot!.totalMeters.toStringAsFixed(0)} m · ${_snapshot!.totalStops.toStringAsFixed(0)} stops · ${( _snapshot!.totalSeconds / 60).toStringAsFixed(1)} min.');
      }
      /// _requestSessionInfo: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      _requestSessionInfo();
    /// catch: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    } catch (e) {
      /// _log: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      _log('Failed to start scenario: $e');
    }
  }

  /// _stopScenario: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Future<void> _stopScenario() async {
    try {
      /// stop: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      await _runner.stop();
      await TrackingService().stopTracking();
    /// catch: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    } catch (e) {
      /// _log: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      _log('Error during stop: $e');
    } finally {
      /// setState: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      setState(() {
        _running = false;
      });
    }
  }

  /// _attachServiceListeners: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  void _attachServiceListeners() {
    /// for: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    for (final sub in _subs) {
      /// cancel: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      try { sub.cancel(); } catch (_) {}
    }
    /// clear: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    _subs.clear();
    /// add: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    _subs.add(_service.on('scenarioOverridesApplied').listen((event) {
      /// _log: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      _log('Scenario overrides acknowledged by background isolate.');
    }));
    /// add: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    _subs.add(_service.on('orchestratorEvent').listen((event) {
      /// if: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      if (event is Map) {
        /// from: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        final map = Map<String, dynamic>.from(event as Map);
        /// [Brief description of this field]
        final type = map['eventType'] ?? 'unknown';
        /// [Brief description of this field]
        final label = map['label'] ?? '';
        /// _safeDouble: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        final meters = _safeDouble(map['metersFromStart']);
        /// toStringAsFixed: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        final km = ((meters ?? 0) / 1000).toStringAsFixed(2);
        /// _log: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        _log('Orchestrator event → $type:$label at $km km');
      }
    }));
    /// add: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    _subs.add(_service.on('fireAlarm').listen((event) {
      /// _log: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      _log('Destination alarm emitted: $event');
    }));
    /// add: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    _subs.add(_service.on('sessionInfo').listen((event) {
      /// if: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      if (!mounted) return;
      /// setState: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      setState(() {
        _sessionInfo = (event as Map?)?.cast<String, dynamic>();
      });
      /// _log: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      _log('Session info update → $_sessionInfo');
    }));
  }

  /// _requestSessionInfo: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  void _requestSessionInfo() {
    try {
      /// invoke: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      _service.invoke('requestSessionInfo');
    /// catch: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    } catch (_) {}
  }

  /// _clearLogs: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  void _clearLogs() {
    /// setState: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    setState(() {
      /// clear: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      _logs.clear();
    });
  }

  /// _log: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  void _log(String message) {
    /// now: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    final line = '[${DateTime.now().toIso8601String()}] $message';
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (!mounted) return;
    /// setState: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    setState(() { _logs.add(line); });
  }

  /// _parseOrFallback: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  double _parseOrFallback(TextEditingController controller, double fallback) {
    /// tryParse: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    final parsed = double.tryParse(controller.text.trim());
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (parsed == null) {
      /// toString: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      controller.text = fallback.toString();
      return fallback;
    }
    return parsed;
  }
}

/// _safeDouble: [Brief description of what this function does]
/// 
/// **Parameters**: [Describe parameters if any]
/// **Returns**: [Describe return value]
double? _safeDouble(dynamic value) {
  /// if: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  if (value is num) return value.toDouble();
  /// if: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  if (value is String) return double.tryParse(value);
  return null;
}

/// DeviceHarnessPanel: Class for [brief description]
/// 
/// **Purpose**: [What this class does]
/// 
/// **Usage**: [How to use this class]
class DeviceHarnessPanel extends StatefulWidget {
  const DeviceHarnessPanel({super.key});

  @override
  /// createState: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  State<DeviceHarnessPanel> createState() => _DeviceHarnessPanelState();
}

/// _HarnessTestState: Class for [brief description]
/// 
/// **Purpose**: [What this class does]
/// 
/// **Usage**: [How to use this class]
class _HarnessTestState {
  bool running = false;
  List<String> logs = <String>[];
  HarnessTestResult? result;
}

/// _DeviceHarnessPanelState: Class for [brief description]
/// 
/// **Purpose**: [What this class does]
/// 
/// **Usage**: [How to use this class]
class _DeviceHarnessPanelState extends State<DeviceHarnessPanel> {
  /// [Brief description of this field]
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

  /// [Brief description of this field]
  late final Map<String, _HarnessTestState> _states = {
    /// for: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    for (final test in _tests) test.id: _HarnessTestState(),
  };

  /// _runTest: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Future<void> _runTest(HarnessTestDefinition def) async {
    /// [Brief description of this field]
    final state = _states[def.id]!;
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (state.running) return;
    /// setState: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    setState(() {
      state.running = true;
      state.logs = <String>[];
      state.result = null;
    });

    HarnessTestResult? result;
    /// now: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    final startedAt = DateTime.now();
    final ctx = HarnessTestContext(onLog: (line) {
      /// if: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      if (!mounted) return;
      /// setState: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      setState(() {
        /// from: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        state.logs = List<String>.from(state.logs)..add(line);
      });
    });

    try {
      /// runner: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      final runResult = await def.runner(ctx);
      /// copyWithLogs: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      result = runResult.copyWithLogs(ctx.logs);
    /// catch: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    } catch (e) {
      /// log: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      ctx.log('Unhandled exception: $e');
      /// failure: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      result = HarnessTestResult.failure(
        /// now: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        duration: DateTime.now().difference(startedAt),
        logs: ctx.logs,
        /// toString: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        error: e.toString(),
      );
    } finally {
      /// dispose: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      await ctx.dispose();
      try {
        await TrackingService().stopTracking();
      /// catch: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      } catch (_) {}
      /// if: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      if (!mounted) return;
      /// setState: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      setState(() {
        state.running = false;
        /// if: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        if (result != null) {
          state.result = result;
          state.logs = result.logs;
        }
      });
    }
  }

  @override
  /// build: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        /// _MetroHarnessWorkbench: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        const _MetroHarnessWorkbench(),
        /// map: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        ..._tests.map((def) {
          /// [Brief description of this field]
          final state = _states[def.id]!;
          /// _buildTestCard: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          return _buildTestCard(def, state);
        }),
      ],
    );
  }

  /// _buildTestCard: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Widget _buildTestCard(HarnessTestDefinition def, _HarnessTestState state) {
    /// _statusChip: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    final statusChip = _statusChip(state);
    return Card(
      /// symmetric: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ExpansionTile(
        key: PageStorageKey<String>(def.id),
        title: Text(def.title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(def.description),
        trailing: statusChip,
        children: [
          Padding(
            /// symmetric: [Brief description of what this function does]
            /// 
            /// **Parameters**: [Describe parameters if any]
            /// **Returns**: [Describe return value]
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ElevatedButton(
                      /// _runTest: [Brief description of what this function does]
                      /// 
                      /// **Parameters**: [Describe parameters if any]
                      /// **Returns**: [Describe return value]
                      onPressed: state.running ? null : () => _runTest(def),
                      child: Text(state.running ? 'Running…' : 'Run test'),
                    ),
                    const SizedBox(width: 12),
                    /// if: [Brief description of what this function does]
                    /// 
                    /// **Parameters**: [Describe parameters if any]
                    /// **Returns**: [Describe return value]
                    if (state.result != null)
                      Text(
                        state.result!.success
                            /// _formatDuration: [Brief description of what this function does]
                            /// 
                            /// **Parameters**: [Describe parameters if any]
                            /// **Returns**: [Describe return value]
                            ? 'Pass in ${_formatDuration(state.result!.duration)}'
                            /// _formatDuration: [Brief description of what this function does]
                            /// 
                            /// **Parameters**: [Describe parameters if any]
                            /// **Returns**: [Describe return value]
                            : 'Fail after ${_formatDuration(state.result!.duration)}',
                        style: TextStyle(
                          color: state.result!.success ? Colors.green.shade700 : Colors.red.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
                /// if: [Brief description of what this function does]
                /// 
                /// **Parameters**: [Describe parameters if any]
                /// **Returns**: [Describe return value]
                if (state.result?.error != null)
                  Padding(
                    /// only: [Brief description of what this function does]
                    /// 
                    /// **Parameters**: [Describe parameters if any]
                    /// **Returns**: [Describe return value]
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      state.result!.error!,
                      style: TextStyle(color: Colors.red.shade600, fontFamily: 'monospace'),
                    ),
                  ),
                /// if: [Brief description of what this function does]
                /// 
                /// **Parameters**: [Describe parameters if any]
                /// **Returns**: [Describe return value]
                if (state.result?.extras.isNotEmpty ?? false)
                  Padding(
                    /// only: [Brief description of what this function does]
                    /// 
                    /// **Parameters**: [Describe parameters if any]
                    /// **Returns**: [Describe return value]
                    padding: const EdgeInsets.only(top: 8.0),
                    /// _extrasView: [Brief description of what this function does]
                    /// 
                    /// **Parameters**: [Describe parameters if any]
                    /// **Returns**: [Describe return value]
                    child: _extrasView(state.result!.extras),
                  ),
                /// if: [Brief description of what this function does]
                /// 
                /// **Parameters**: [Describe parameters if any]
                /// **Returns**: [Describe return value]
                if (state.logs.isNotEmpty)
                  Container(
                    /// only: [Brief description of what this function does]
                    /// 
                    /// **Parameters**: [Describe parameters if any]
                    /// **Returns**: [Describe return value]
                    margin: const EdgeInsets.only(top: 12.0),
                    /// all: [Brief description of what this function does]
                    /// 
                    /// **Parameters**: [Describe parameters if any]
                    /// **Returns**: [Describe return value]
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      /// withOpacity: [Brief description of what this function does]
                      /// 
                      /// **Parameters**: [Describe parameters if any]
                      /// **Returns**: [Describe return value]
                      color: Colors.black.withOpacity(0.04),
                      /// circular: [Brief description of what this function does]
                      /// 
                      /// **Parameters**: [Describe parameters if any]
                      /// **Returns**: [Describe return value]
                      borderRadius: BorderRadius.circular(6),
                    ),
                    constraints: const BoxConstraints(maxHeight: 180),
                    child: Scrollbar(
                      /// builder: [Brief description of what this function does]
                      /// 
                      /// **Parameters**: [Describe parameters if any]
                      /// **Returns**: [Describe return value]
                      child: ListView.builder(
                        itemCount: state.logs.length,
                        itemBuilder: (_, index) => Text(
                          state.logs[index],
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                        ),
                      ),
                    ),
                  ),
                /// if: [Brief description of what this function does]
                /// 
                /// **Parameters**: [Describe parameters if any]
                /// **Returns**: [Describe return value]
                if (!state.running && (state.logs.isEmpty))
                  Padding(
                    /// only: [Brief description of what this function does]
                    /// 
                    /// **Parameters**: [Describe parameters if any]
                    /// **Returns**: [Describe return value]
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

  /// _statusChip: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Widget _statusChip(_HarnessTestState state) {
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (state.running) {
      return const Chip(label: Text('Running'), backgroundColor: Color(0xFFFFF3CD));
    }
    /// [Brief description of this field]
    final result = state.result;
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (result == null) {
      return const Chip(label: Text('Idle'));
    }
    return Chip(
      label: Text(result.success ? 'Pass' : 'Fail'),
      backgroundColor: result.success ? const Color(0xFFE6F4EA) : const Color(0xFFFFE6E6),
    );
  }

  /// _extrasView: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Widget _extrasView(Map<String, dynamic> extras) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      /// map: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      children: extras.entries.map((entry) {
        /// [Brief description of this field]
        final value = entry.value;
        /// if: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        if (value is List) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${entry.key}:', style: const TextStyle(fontWeight: FontWeight.w600)),
              /// map: [Brief description of what this function does]
              /// 
              /// **Parameters**: [Describe parameters if any]
              /// **Returns**: [Describe return value]
              ...value.map((v) => Text('- $v', style: const TextStyle(fontFamily: 'monospace', fontSize: 12))).toList(growable: false),
            ],
          );
        }
        return Text(
          '${entry.key}: $value',
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        );
      /// toList: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      }).toList(growable: false),
    );
  }

  /// _formatDuration: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  String _formatDuration(Duration d) {
    /// [Brief description of this field]
    final minutes = d.inMinutes;
    /// [Brief description of this field]
    final seconds = d.inSeconds % 60;
    /// [Brief description of this field]
    final millis = d.inMilliseconds % 1000;
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    }
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (seconds > 0) {
      /// round: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      return '${seconds}.${(millis / 100).round()}s';
    }
    return '${millis}ms';
  }
}

/// _runMetroMultiStageScenario: [Brief description of what this function does]
/// 
/// **Parameters**: [Describe parameters if any]
/// **Returns**: [Describe return value]
Future<HarnessTestResult> _runMetroMultiStageScenario(HarnessTestContext ctx) async {
  final runner = MetroRouteScenarioRunner();
  /// now: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  final started = DateTime.now();
  final expectedMilestones = <String>{
    'mode_change:Board metro at Nagasandra',
    'transfer:Change line at Majestic interchange',
    'transfer:Prepare to exit at Whitefield metro',
  };
  final observedMilestones = <String>{};
  final eventsSummary = <String>[];
  /// log: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  ctx.log('Preparing metro multi-stage scenario…');
  final overridesAck = Completer<void>();
  /// listenService: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  ctx.listenService('scenarioOverridesApplied', (event) {
    /// log: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    ctx.log('Background acknowledged scenario overrides.');
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (!overridesAck.isCompleted) {
      /// complete: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      overridesAck.complete();
    }
  });
  final milestoneCompleter = Completer<void>();
  /// listenService: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  ctx.listenService('orchestratorEvent', (event) {
    final map = (event as Map?)?.cast<String, dynamic>();
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (map == null) return;
    final type = map['eventType'] as String? ?? 'unknown';
    final label = map['label'] as String? ?? '';
  /// _safeDouble: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  final meters = _safeDouble(map['metersFromStart']);
  final key = '$type:$label';
  /// toStringAsFixed: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  final metersLabel = meters?.toStringAsFixed(1) ?? '?';
  /// add: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  eventsSummary.add('$key@${metersLabel}m');
  /// log: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  ctx.log('Event → $key at ${metersLabel} m');
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (expectedMilestones.contains(key)) {
      /// add: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      observedMilestones.add(key);
      /// if: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      if (!milestoneCompleter.isCompleted && expectedMilestones.difference(observedMilestones).isEmpty) {
        /// complete: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        milestoneCompleter.complete();
      }
    }
  });
  final destinationCompleter = Completer<void>();
  /// listenService: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  ctx.listenService('fireAlarm', (event) {
    /// log: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    ctx.log('Destination alarm bridge received.');
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (!destinationCompleter.isCompleted) {
      /// complete: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      destinationCompleter.complete();
    }
  });

  try {
    /// defaults: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    final runOptions = MetroScenarioRunOptions.defaults(runner.config).copyWith(
      mode: MetroAlarmMode.stops,
      stopsThreshold: 6.0,
      eventTriggerWindowMeters: 120.0,
      speedMultiplier: 1.0,
    );
    /// start: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    await runner.start(options: runOptions);
    final snapshot = runner.lastSnapshot;
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (snapshot != null) {
      /// log: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      ctx.log(
        /// toStringAsFixed: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        'Metro route snapshot → ${snapshot.totalMeters.toStringAsFixed(0)} m, '
        /// toStringAsFixed: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        '${snapshot.totalStops.toStringAsFixed(0)} stops, '
        /// toStringAsFixed: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        '${(snapshot.totalSeconds / 60).toStringAsFixed(1)} min.',
      );
      /// log: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      ctx.log('Milestones: ${snapshot.milestones.map((m) => '${m.type}:${m.label}').join(', ')}');
    }
    try {
      /// timeout: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      await overridesAck.future.timeout(const Duration(seconds: 8));
    } on TimeoutException {
      throw HarnessTestFailure('Background service did not acknowledge scenario overrides.');
    }
    /// setSpeedMultiplier: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    runner.setSpeedMultiplier(18.0);
    /// log: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    ctx.log('Simulation started at 18× speed; watch the device for alarm popups.');
    try {
      /// timeout: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      await milestoneCompleter.future.timeout(const Duration(seconds: 45));
    } on TimeoutException {
      throw HarnessTestFailure('Metro milestone alerts did not all fire within 45 seconds.');
    }
    /// log: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    ctx.log('All metro milestone alerts observed.');
    try {
      /// timeout: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      await destinationCompleter.future.timeout(const Duration(seconds: 45));
    } on TimeoutException {
      throw HarnessTestFailure('Destination alarm did not fire after milestones completed.');
    }
    /// log: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    ctx.log('Destination alarm fired; tap the full-screen sheet on device to confirm.');
    /// success: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    return HarnessTestResult.success(
      /// now: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      duration: DateTime.now().difference(started),
      logs: ctx.logs,
      extras: <String, dynamic>{'events': eventsSummary},
    );
  /// catch: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  } on HarnessTestFailure catch (e) {
    /// log: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    ctx.log('Harness failure: ${e.message}');
    /// failure: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    return HarnessTestResult.failure(
      /// now: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      duration: DateTime.now().difference(started),
      logs: ctx.logs,
      error: e.message,
      extras: <String, dynamic>{'events': eventsSummary},
    );
  /// catch: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  } catch (e) {
    /// log: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    ctx.log('Unhandled error: $e');
    /// failure: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    return HarnessTestResult.failure(
      /// now: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      duration: DateTime.now().difference(started),
      logs: ctx.logs,
      /// toString: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      error: e.toString(),
      extras: <String, dynamic>{'events': eventsSummary},
    );
  } finally {
    /// stop: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    await runner.stop();
    try {
      await TrackingService().stopTracking();
    /// catch: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    } catch (_) {}
  }
}

/// _runNotificationLifecycleTest: [Brief description of what this function does]
/// 
/// **Parameters**: [Describe parameters if any]
/// **Returns**: [Describe return value]
Future<HarnessTestResult> _runNotificationLifecycleTest(HarnessTestContext ctx) async {
  final runner = MetroRouteScenarioRunner();
  /// now: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  final started = DateTime.now();
  /// log: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  ctx.log('Starting metro scenario to verify notification lifecycle…');
  try {
    /// defaults: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    final runOptions = MetroScenarioRunOptions.defaults(runner.config).copyWith(
      mode: MetroAlarmMode.distance,
      distanceMeters: 180.0,
      eventTriggerWindowMeters: 90.0,
      speedMultiplier: 1.0,
    );
    /// start: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    await runner.start(options: runOptions);
    final snapshot = runner.lastSnapshot;
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (snapshot != null) {
      /// log: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      ctx.log(
        /// toStringAsFixed: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        'Notification scenario snapshot → ${snapshot.totalMeters.toStringAsFixed(0)} m, '
        /// toStringAsFixed: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        '${snapshot.totalStops.toStringAsFixed(0)} stops, '
        /// toStringAsFixed: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        'ETA ${(snapshot.totalSeconds / 60).toStringAsFixed(1)} min.',
      );
    }
    /// setSpeedMultiplier: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    runner.setSpeedMultiplier(12.0);
    /// log: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    ctx.log('Waiting for background session info…');
    /// delayed: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    await Future.delayed(const Duration(seconds: 4));
    /// requestSessionInfo: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    final sessionBefore = await ctx.requestSessionInfo(timeout: const Duration(seconds: 4));
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (sessionBefore == null || sessionBefore['empty'] == true) {
      throw HarnessTestFailure('Session info remained empty after starting tracking.');
    }
    /// log: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    ctx.log('Session info populated: $sessionBefore');
    /// log: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    ctx.log('Requesting stopTracking (simulate pressing End Tracking).');
    await TrackingService().stopTracking();
    /// delayed: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    await Future.delayed(const Duration(seconds: 3));
    /// requestSessionInfo: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    final sessionAfter = await ctx.requestSessionInfo(timeout: const Duration(seconds: 4));
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (sessionAfter != null && sessionAfter['empty'] != true) {
      throw HarnessTestFailure('Session info still populated after stopTracking: $sessionAfter');
    }
    /// log: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    ctx.log('Session info cleared. Confirm the persistent notification vanished on device.');
    /// success: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    return HarnessTestResult.success(
      /// now: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      duration: DateTime.now().difference(started),
      logs: ctx.logs,
      extras: <String, dynamic>{'sessionBefore': sessionBefore},
    );
  /// catch: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  } on HarnessTestFailure catch (e) {
    /// log: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    ctx.log('Harness failure: ${e.message}');
    /// failure: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    return HarnessTestResult.failure(
      /// now: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      duration: DateTime.now().difference(started),
      logs: ctx.logs,
      error: e.message,
    );
  /// catch: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  } catch (e) {
    /// log: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    ctx.log('Unhandled error: $e');
    /// failure: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    return HarnessTestResult.failure(
      /// now: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      duration: DateTime.now().difference(started),
      logs: ctx.logs,
      /// toString: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      error: e.toString(),
    );
  } finally {
    /// stop: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    await runner.stop();
    try {
      await TrackingService().stopTracking();
    /// catch: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    } catch (_) {}
  }
}
