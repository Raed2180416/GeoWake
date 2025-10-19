/// dev_route_sim_screen.dart: Source file from lib/lib/screens/dev_route_sim_screen.dart
/// 
/// This annotated version provides detailed documentation for all classes, methods, and fields.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/simulation/route_asset_loader.dart';
import '../services/simulation/route_simulator.dart';
import '../services/trackingservice.dart';

/// Dev-only screen to visualize a simulated route & control playback.
class DevRouteSimulationScreen extends StatefulWidget {
  const DevRouteSimulationScreen({super.key});
  @override
  /// createState: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  State<DevRouteSimulationScreen> createState() => _DevRouteSimulationScreenState();
}

/// _DevRouteSimulationScreenState: Class for [brief description]
/// 
/// **Purpose**: [What this class does]
/// 
/// **Usage**: [How to use this class]
class _DevRouteSimulationScreenState extends State<DevRouteSimulationScreen> {
  RouteSimulationController? _controller;
  GoogleMapController? _map;
  List<LatLng> _polyline = [];
  LatLng? _current;
  double _speedMultiplier = 1.0;
  bool _playing = false;
  StreamSubscription? _posSub;
  String? _routeName;
  String? _selectedAsset;
  /// [Brief description of this field]
  final List<Map<String, String>> _availableRoutes = const [
    {'label': 'Demo Downtown Sprint', 'asset': 'assets/routes/demo_route.json'},
    {'label': 'Suburban Commute', 'asset': 'assets/routes/suburban_route.json'},
    {'label': 'Metro Transfer Line', 'asset': 'assets/routes/metro_stops_route.json'},
  ];

  @override
  /// dispose: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  void dispose() {
    /// dispose: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    _controller?.dispose();
    /// cancel: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    _posSub?.cancel();
    /// dispose: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    super.dispose();
  }

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
    // Auto-load the first route so the screen is immediately useful
    /// addPostFrameCallback: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRoute());
  }

  /// _loadRoute: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Future<void> _loadRoute() async {
    try {
      /// [Brief description of this field]
      final target = _selectedAsset ?? _availableRoutes.first['asset']!;
      /// load: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      final asset = await RouteAssetLoader.load(target);
      /// setState: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      setState(() {
        _routeName = asset.name;
        _polyline = asset.points;
      });
      /// dispose: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      _controller?.dispose();
      _controller = RouteSimulationController(polyline: _polyline, baseSpeedMps: 14.0);
      /// listen: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      _posSub = _controller!.position$.listen((p) {
        /// setState: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        setState(() {
          _current = p;
        });
        /// if: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        if (_map != null) {
          /// animateCamera: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          _map!.animateCamera(CameraUpdate.newLatLng(p));
        }
      });
    /// catch: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    } catch (e) {
      /// if: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      if (mounted) {
        /// of: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load route: $e')));
      }
    }
  }

  /// _startTracking: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Future<void> _startTracking() async {
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (_controller == null) return;
    /// startTrackingWithSimulation: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    await _controller!.startTrackingWithSimulation(
      destinationName: _routeName ?? 'Sim Dest',
      alarmMode: 'distance',
      alarmValue: 800, // meters threshold example
    );
    /// start: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    _controller!.start();
    /// setState: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    setState(() { _playing = true; });
  }

  /// _togglePlay: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  void _togglePlay() {
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (_controller == null) return;
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (_playing) {
      /// pause: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      _controller!.pause();
      /// setState: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      setState(() { _playing = false; });
    } else {
      /// resume: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      _controller!.resume();
      /// setState: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      setState(() { _playing = true; });
    }
  }

  /// _fastForward: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  void _fastForward() {
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (_controller == null) return;
    // Cycle through preset multipliers for convenience
    /// [Brief description of this field]
    const presets = [1.0, 2.0, 4.0, 8.0, 16.0];
    /// indexOf: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    final idx = presets.indexOf(_speedMultiplier);
    final next = presets[(idx + 1) % presets.length];
    _speedMultiplier = next;
    /// setSpeedMultiplier: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    _controller!.setSpeedMultiplier(next);
    /// setState: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    setState(() {});
  }

  /// _seekHalf: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  void _seekHalf() => _controller?.seekToFraction(0.5);
  /// _seekEnd: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  void _seekEnd() => _controller?.seekToFraction(0.95);

  @override
  /// build: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Route Simulation (${_routeName ?? 'none'})')),
      body: Column(
        children: [
          Expanded(
            child: _polyline.isEmpty
                ? const Center(child: Text('Load a route asset to begin'))
                : GoogleMap(
                    initialCameraPosition: CameraPosition(target: _polyline.first, zoom: 14),
                    onMapCreated: (c) => _map = c,
                    polylines: {
                      Polyline(
                        polylineId: const PolylineId('sim'),
                        points: _polyline,
                        width: 4,
                        color: Colors.blueAccent,
                      )
                    },
                    markers: _current == null
                        ? {}
                        : {
                            Marker(
                              markerId: const MarkerId('simPos'),
                              position: _current!,
                              infoWindow: InfoWindow(title: 'Sim Pos', snippet: 'x${_speedMultiplier.toStringAsFixed(1)}'),
                            )
                          },
                  ),
          ),
          /// if: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          if (_controller != null) _buildStatusBar(),
          /// _buildControls: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          _buildControls(),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  /// _buildStatusBar: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Widget _buildStatusBar() {
    /// clamp: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    final frac = (_controller?.progressFraction ?? 0.0).clamp(0.0, 1.0);
    return Padding(
      /// symmetric: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        children: [
          LinearProgressIndicator(value: frac),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Progress ${(frac * 100).toStringAsFixed(1)}%'),
              Text('Speed x${_speedMultiplier.toStringAsFixed(1)}'),
            ],
          )
        ],
      ),
    );
  }

  /// _buildControls: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Widget _buildControls() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            DropdownButton<String>(
              value: _selectedAsset ?? _availableRoutes.first['asset'],
              items: _availableRoutes
                  /// map: [Brief description of what this function does]
                  /// 
                  /// **Parameters**: [Describe parameters if any]
                  /// **Returns**: [Describe return value]
                  .map((e) => DropdownMenuItem<String>(
                        value: e['asset'],
                        child: Text(e['label'] ?? 'Route'),
                      ))
                  /// toList: [Brief description of what this function does]
                  /// 
                  /// **Parameters**: [Describe parameters if any]
                  /// **Returns**: [Describe return value]
                  .toList(),
              /// setState: [Brief description of what this function does]
              /// 
              /// **Parameters**: [Describe parameters if any]
              /// **Returns**: [Describe return value]
              onChanged: (v) => setState(() => _selectedAsset = v),
            ),
            ElevatedButton(onPressed: _loadRoute, child: const Text('Load')),
          ],
        ),
        ElevatedButton(onPressed: _controller == null ? null : _startTracking, child: const Text('Start Tracking')),
        ElevatedButton(onPressed: _controller == null ? null : _togglePlay, child: Text(_playing ? 'Pause' : 'Play')),
        ElevatedButton(onPressed: _controller == null ? null : _fastForward, child: const Text('Speed++')),
        ElevatedButton(onPressed: _controller == null ? null : _seekHalf, child: const Text('Seek 50%')),
        ElevatedButton(onPressed: _controller == null ? null : _seekEnd, child: const Text('Seek 95%')),
        ElevatedButton(
          onPressed: () {
            TrackingService().stopTracking();
            /// stop: [Brief description of what this function does]
            /// 
            /// **Parameters**: [Describe parameters if any]
            /// **Returns**: [Describe return value]
            _controller?.stop();
            /// setState: [Brief description of what this function does]
            /// 
            /// **Parameters**: [Describe parameters if any]
            /// **Returns**: [Describe return value]
            setState(() { _playing = false; });
          },
          child: const Text('Stop All'),
        ),
      ],
    );
  }
}
