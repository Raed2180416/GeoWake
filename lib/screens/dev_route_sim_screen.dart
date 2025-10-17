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
  State<DevRouteSimulationScreen> createState() => _DevRouteSimulationScreenState();
}

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
  final List<Map<String, String>> _availableRoutes = const [
    {'label': 'Demo Downtown Sprint', 'asset': 'assets/routes/demo_route.json'},
    {'label': 'Suburban Commute', 'asset': 'assets/routes/suburban_route.json'},
    {'label': 'Metro Transfer Line', 'asset': 'assets/routes/metro_stops_route.json'},
  ];

  @override
  void dispose() {
    _controller?.dispose();
    _posSub?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Auto-load the first route so the screen is immediately useful
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRoute());
  }

  Future<void> _loadRoute() async {
    try {
      final target = _selectedAsset ?? _availableRoutes.first['asset']!;
      final asset = await RouteAssetLoader.load(target);
      setState(() {
        _routeName = asset.name;
        _polyline = asset.points;
      });
      _controller?.dispose();
      _controller = RouteSimulationController(polyline: _polyline, baseSpeedMps: 14.0);
      _posSub = _controller!.position$.listen((p) {
        setState(() {
          _current = p;
        });
        if (_map != null) {
          _map!.animateCamera(CameraUpdate.newLatLng(p));
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load route: $e')));
      }
    }
  }

  Future<void> _startTracking() async {
    if (_controller == null) return;
    await _controller!.startTrackingWithSimulation(
      destinationName: _routeName ?? 'Sim Dest',
      alarmMode: 'distance',
      alarmValue: 800, // meters threshold example
    );
    _controller!.start();
    setState(() { _playing = true; });
  }

  void _togglePlay() {
    if (_controller == null) return;
    if (_playing) {
      _controller!.pause();
      setState(() { _playing = false; });
    } else {
      _controller!.resume();
      setState(() { _playing = true; });
    }
  }

  void _fastForward() {
    if (_controller == null) return;
    // Cycle through preset multipliers for convenience
    const presets = [1.0, 2.0, 4.0, 8.0, 16.0];
    final idx = presets.indexOf(_speedMultiplier);
    final next = presets[(idx + 1) % presets.length];
    _speedMultiplier = next;
    _controller!.setSpeedMultiplier(next);
    setState(() {});
  }

  void _seekHalf() => _controller?.seekToFraction(0.5);
  void _seekEnd() => _controller?.seekToFraction(0.95);

  @override
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
          if (_controller != null) _buildStatusBar(),
          _buildControls(),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    final frac = (_controller?.progressFraction ?? 0.0).clamp(0.0, 1.0);
    return Padding(
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
                  .map((e) => DropdownMenuItem<String>(
                        value: e['asset'],
                        child: Text(e['label'] ?? 'Route'),
                      ))
                  .toList(),
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
            _controller?.stop();
            setState(() { _playing = false; });
          },
          child: const Text('Stop All'),
        ),
      ],
    );
  }
}
