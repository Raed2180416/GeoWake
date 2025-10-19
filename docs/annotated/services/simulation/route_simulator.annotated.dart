/// route_simulator.dart: Source file from lib/lib/services/simulation/route_simulator.dart
/// 
/// This annotated version provides detailed documentation for all classes, methods, and fields.

// Route simulation utility for feeding synthetic GPS samples into TrackingService.
// Debug / development only. Does not persist state; intended for desktop/laptop
// or emulator usage where real movement is not feasible.
//
// Usage (foreground side):
//   final sim = RouteSimulationController(
//       polyline: myLatLngList,
//       baseSpeedMps: 13.0, // ~47 km/h default, tweak per segment if needed
//   );
//   await sim.startTrackingWithSimulation(
//       destinationName: 'Office',
//       alarmMode: 'distance', // 'time' | 'stops'
//       alarmValue: 1000, // meters or seconds or stops depending on mode
//   );
//   sim.start(); // begins injecting samples each tick
//   sim.setSpeedMultiplier(2.0); // fast-forward
//   sim.pause(); sim.resume(); sim.seekToFraction(0.5); // mid-route
//   sim.stop();
//
// Visually: Subscribe to sim.position$ to update a marker on the map.
// Alarm & adaptive ETA logic: uses same pipeline because samples are
// injected through the background service event 'injectPosition'.

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../trackingservice.dart';

/// _SegmentSpec: Class for [brief description]
/// 
/// **Purpose**: [What this class does]
/// 
/// **Usage**: [How to use this class]
class _SegmentSpec {
  /// [Brief description of this field]
  final LatLng from;
  /// [Brief description of this field]
  final LatLng to;
  /// [Brief description of this field]
  final double lengthMeters;
  /// _SegmentSpec: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  _SegmentSpec({required this.from, required this.to, required this.lengthMeters});
}

/// RouteSimulationController: Class for [brief description]
/// 
/// **Purpose**: [What this class does]
/// 
/// **Usage**: [How to use this class]
class RouteSimulationController {
  /// [Brief description of this field]
  final List<LatLng> polyline;
  /// [Brief description of this field]
  final double baseSpeedMps; // nominal pace, can be overridden per segment
  /// [Brief description of this field]
  final Duration tickInterval; // logical time step granularity
  /// multiplier: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  double _speedMultiplier = 1.0; // global multiplier (fast-forward / slow-mo)
  Timer? _timer;
  bool _running = false;
  int _currentSegmentIndex = 0;
  double _distanceIntoSegment = 0.0; // meters progressed within segment
  /// broadcast: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  final _positionCtrl = StreamController<LatLng>.broadcast();
  List<_SegmentSpec> _segments = [];
  DateTime? _startedWallClock; // For diagnostics

  /// Broadcast stream of simulated positions (mirrors injections)
  Stream<LatLng> get position$ => _positionCtrl.stream;

  /// 0.0 -> 1.0 progress indicator
  double get progressFraction {
    /// [Brief description of this field]
    final total = _totalLengthMeters;
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (total == 0) return 0;
    /// take: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    final progressedBefore = _segments.take(_currentSegmentIndex).fold<double>(0.0, (a, s) => a + s.lengthMeters);
    /// return: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    return (progressedBefore + _distanceIntoSegment) / total;
  }

  RouteSimulationController({
    required this.polyline,
    this.baseSpeedMps = 12.0,
    this.tickInterval = const Duration(seconds: 1),
  /// assert: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  }) : assert(polyline.length >= 2, 'Need at least two points to simulate') {
    /// _buildSegments: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    _buildSegments();
  }

  /// fold: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  double get _totalLengthMeters => _segments.fold(0.0, (a, s) => a + s.lengthMeters);

  /// _buildSegments: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  void _buildSegments() {
    _segments = [];
    /// for: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    for (var i = 0; i < polyline.length - 1; i++) {
      /// [Brief description of this field]
      final a = polyline[i];
      /// [Brief description of this field]
      final b = polyline[i + 1];
      /// distanceBetween: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      final len = Geolocator.distanceBetween(a.latitude, a.longitude, b.latitude, b.longitude);
      /// add: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      _segments.add(_SegmentSpec(from: a, to: b, lengthMeters: len));
    }
  }

  // Per-segment speed overrides removed for simplicity; add back if needed.

  /// Enable injection in TrackingService & begin position stream consumption
  Future<void> startTrackingWithSimulation({
    required String destinationName,
    required String alarmMode, // 'distance' | 'time' | 'stops'
    required double alarmValue,
  }) async {
    // Use first polyline point as starting position / last as destination.
    /// [Brief description of this field]
    final start = polyline.first;
    /// [Brief description of this field]
    final end = polyline.last;
    // Ensure tracking uses injected positions
    final service = TrackingService();
    // Adapt units: tracking service expects distance alarmValue in KM; simulation API takes meters for distance for convenience.
    final adjustedValue = alarmMode == 'distance' ? (alarmValue / 1000.0) : alarmValue;
    /// startTracking: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    await service.startTracking(
      destination: end,
      destinationName: destinationName,
      alarmMode: alarmMode,
      alarmValue: adjustedValue,
      useInjectedPositions: true,
    );
    // Push an initial sample immediately so downstream UI has a position.
    /// _injectLatLng: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    _injectLatLng(start, speedMps: baseSpeedMps, headingDeg: 0);
  }

  /// start: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  void start() {
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (_running) return;
    _running = true;
    /// now: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    _startedWallClock ??= DateTime.now();
    /// periodic: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    _timer = Timer.periodic(tickInterval, _onTick);
  }

  /// pause: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  void pause() {
    /// cancel: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    _timer?.cancel();
    _timer = null;
    _running = false;
  }

  /// resume: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  void resume() {
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (_running) return;
    /// start: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    start();
  }

  /// stop: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  void stop() {
    /// pause: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    pause();
    _currentSegmentIndex = 0;
    _distanceIntoSegment = 0.0;
  }

  /// dispose: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  void dispose() {
    /// stop: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    stop();
    /// close: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    _positionCtrl.close();
  }

  /// setSpeedMultiplier: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  void setSpeedMultiplier(double m) {
    /// clamp: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    _speedMultiplier = m.clamp(0.1, 50.0);
  }

  /// seekToFraction: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  void seekToFraction(double f) {
    /// clamp: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    f = f.clamp(0.0, 1.0);
    /// [Brief description of this field]
    final targetMeters = _totalLengthMeters * f;
    /// [Brief description of this field]
    var accum = 0.0;
    /// for: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    for (var i = 0; i < _segments.length; i++) {
      /// [Brief description of this field]
      final seg = _segments[i];
      /// if: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      if (accum + seg.lengthMeters >= targetMeters) {
        _currentSegmentIndex = i;
        _distanceIntoSegment = targetMeters - accum;
        /// _interpolate: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        final latLng = _interpolate(seg, _distanceIntoSegment / (seg.lengthMeters == 0 ? 1 : seg.lengthMeters));
  /// _injectLatLng: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  _injectLatLng(latLng, speedMps: baseSpeedMps, headingDeg: _bearingDeg(seg.from, seg.to));
        return;
      }
      accum += seg.lengthMeters;
    }
    // If reached here, clamp to end
    /// [Brief description of this field]
    final lastSeg = _segments.last;
    _currentSegmentIndex = _segments.length - 1;
    _distanceIntoSegment = lastSeg.lengthMeters;
  /// _injectLatLng: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  _injectLatLng(lastSeg.to, speedMps: baseSpeedMps, headingDeg: _bearingDeg(lastSeg.from, lastSeg.to));
  }

  /// _onTick: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  void _onTick(Timer _) {
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (_currentSegmentIndex >= _segments.length) {
      /// stop: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      stop();
      return;
    }
    /// [Brief description of this field]
    final seg = _segments[_currentSegmentIndex];
  /// [Brief description of this field]
  final segSpeed = baseSpeedMps * _speedMultiplier;
    /// [Brief description of this field]
    final advance = segSpeed * tickInterval.inMilliseconds / 1000.0;
    _distanceIntoSegment += advance;
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (_distanceIntoSegment >= seg.lengthMeters && seg.lengthMeters > 0) {
      // Move to next segment; carry over excess
      /// [Brief description of this field]
      var overflow = _distanceIntoSegment - seg.lengthMeters;
      _currentSegmentIndex++;
      _distanceIntoSegment = 0.0;
      /// if: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      if (_currentSegmentIndex >= _segments.length) {
        /// _injectLatLng: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        _injectLatLng(seg.to, speedMps: segSpeed, headingDeg: _bearingDeg(seg.from, seg.to));
        /// stop: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        stop();
        return;
      }
      // Potential overflow: advance into next segment recursively (rare at huge multiplier)
      /// while: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      while (overflow > 0 && _currentSegmentIndex < _segments.length) {
        /// [Brief description of this field]
        final nextSeg = _segments[_currentSegmentIndex];
        /// if: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        if (overflow >= nextSeg.lengthMeters) {
          overflow -= nextSeg.lengthMeters;
          _currentSegmentIndex++;
          _distanceIntoSegment = 0.0;
          /// if: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          if (_currentSegmentIndex >= _segments.length) {
            /// _injectLatLng: [Brief description of what this function does]
            /// 
            /// **Parameters**: [Describe parameters if any]
            /// **Returns**: [Describe return value]
            _injectLatLng(nextSeg.to, speedMps: segSpeed, headingDeg: _bearingDeg(nextSeg.from, nextSeg.to));
            /// stop: [Brief description of what this function does]
            /// 
            /// **Parameters**: [Describe parameters if any]
            /// **Returns**: [Describe return value]
            stop();
            return;
          }
        } else {
          _distanceIntoSegment = overflow;
          overflow = 0;
        }
      }
    }
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (_currentSegmentIndex >= _segments.length) {
      /// stop: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      stop();
      return;
    }
    /// [Brief description of this field]
    final activeSeg = _segments[_currentSegmentIndex];
    /// clamp: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    final frac = activeSeg.lengthMeters == 0 ? 1.0 : (_distanceIntoSegment / activeSeg.lengthMeters).clamp(0.0, 1.0);
    /// _interpolate: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    final latLng = _interpolate(activeSeg, frac);
    /// _bearingDeg: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    final headingDeg = _bearingDeg(activeSeg.from, activeSeg.to);
    /// _injectLatLng: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    _injectLatLng(latLng, speedMps: segSpeed, headingDeg: headingDeg);
  }

  /// _interpolate: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  LatLng _interpolate(_SegmentSpec seg, double t) {
    final lat = seg.from.latitude + (seg.to.latitude - seg.from.latitude) * t;
    final lng = seg.from.longitude + (seg.to.longitude - seg.from.longitude) * t;
    return LatLng(lat, lng);
  }

  /// _bearingDeg: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  double _bearingDeg(LatLng a, LatLng b) {
    /// _degToRad: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    final lat1 = _degToRad(a.latitude);
    /// _degToRad: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    final lat2 = _degToRad(b.latitude);
    /// _degToRad: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    final dLon = _degToRad(b.longitude - a.longitude);
    /// sin: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    final y = math.sin(dLon) * math.cos(lat2);
    /// cos: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    final x = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    /// atan2: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    final brng = math.atan2(y, x);
    /// return: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    return (brng * 180.0 / math.pi + 360.0) % 360.0;
  }

  /// _degToRad: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  double _degToRad(double d) => d * math.pi / 180.0;

  /// _injectLatLng: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  void _injectLatLng(LatLng p, {required double speedMps, required double headingDeg}) {
    /// add: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    _positionCtrl.add(p);
    // In VM tests or debug test mode, use direct injection hook to bypass plugins
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (TrackingService.isTestMode && TrackingService.injectPositionForTests != null) {
      try {
        final pos = Position(
          latitude: p.latitude,
          longitude: p.longitude,
          /// now: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          timestamp: DateTime.now(),
          accuracy: 5.0,
          altitude: 0.0,
          altitudeAccuracy: 0.0,
          heading: headingDeg,
          headingAccuracy: 5.0,
          speed: speedMps,
          speedAccuracy: 0.5,
        );
        TrackingService.injectPositionForTests!(pos);
        return;
      /// catch: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      } catch (e) {
        /// if: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        if (kDebugMode) {
          /// print: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          print('Direct test injection failed, falling back to service: $e');
        }
      }
    }
    // Fallback to background service event when available (device/emulator)
    try {
      FlutterBackgroundService().invoke('injectPosition', {
        'latitude': p.latitude,
        'longitude': p.longitude,
        'accuracy': 5.0,
        'altitude': 0.0,
        'altitudeAccuracy': 0.0,
        'heading': headingDeg,
        'headingAccuracy': 5.0,
        'speed': speedMps,
        'speedAccuracy': 0.5,
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
      if (kDebugMode) {
        /// print: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        print('RouteSimulationController service injection failed: $e');
      }
    }
  }
}
