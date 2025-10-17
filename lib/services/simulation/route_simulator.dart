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

class _SegmentSpec {
  final LatLng from;
  final LatLng to;
  final double lengthMeters;
  _SegmentSpec({required this.from, required this.to, required this.lengthMeters});
}

class RouteSimulationController {
  final List<LatLng> polyline;
  final double baseSpeedMps; // nominal pace, can be overridden per segment
  final Duration tickInterval; // logical time step granularity
  double _speedMultiplier = 1.0; // global multiplier (fast-forward / slow-mo)
  Timer? _timer;
  bool _running = false;
  int _currentSegmentIndex = 0;
  double _distanceIntoSegment = 0.0; // meters progressed within segment
  final _positionCtrl = StreamController<LatLng>.broadcast();
  List<_SegmentSpec> _segments = [];
  DateTime? _startedWallClock; // For diagnostics

  /// Broadcast stream of simulated positions (mirrors injections)
  Stream<LatLng> get position$ => _positionCtrl.stream;

  /// 0.0 -> 1.0 progress indicator
  double get progressFraction {
    final total = _totalLengthMeters;
    if (total == 0) return 0;
    final progressedBefore = _segments.take(_currentSegmentIndex).fold<double>(0.0, (a, s) => a + s.lengthMeters);
    return (progressedBefore + _distanceIntoSegment) / total;
  }

  RouteSimulationController({
    required this.polyline,
    this.baseSpeedMps = 12.0,
    this.tickInterval = const Duration(seconds: 1),
  }) : assert(polyline.length >= 2, 'Need at least two points to simulate') {
    _buildSegments();
  }

  double get _totalLengthMeters => _segments.fold(0.0, (a, s) => a + s.lengthMeters);

  void _buildSegments() {
    _segments = [];
    for (var i = 0; i < polyline.length - 1; i++) {
      final a = polyline[i];
      final b = polyline[i + 1];
      final len = Geolocator.distanceBetween(a.latitude, a.longitude, b.latitude, b.longitude);
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
    final start = polyline.first;
    final end = polyline.last;
    // Ensure tracking uses injected positions
    final service = TrackingService();
    // Adapt units: tracking service expects distance alarmValue in KM; simulation API takes meters for distance for convenience.
    final adjustedValue = alarmMode == 'distance' ? (alarmValue / 1000.0) : alarmValue;
    await service.startTracking(
      destination: end,
      destinationName: destinationName,
      alarmMode: alarmMode,
      alarmValue: adjustedValue,
      useInjectedPositions: true,
    );
    // Push an initial sample immediately so downstream UI has a position.
    _injectLatLng(start, speedMps: baseSpeedMps, headingDeg: 0);
  }

  void start() {
    if (_running) return;
    _running = true;
    _startedWallClock ??= DateTime.now();
    _timer = Timer.periodic(tickInterval, _onTick);
  }

  void pause() {
    _timer?.cancel();
    _timer = null;
    _running = false;
  }

  void resume() {
    if (_running) return;
    start();
  }

  void stop() {
    pause();
    _currentSegmentIndex = 0;
    _distanceIntoSegment = 0.0;
  }

  void dispose() {
    stop();
    _positionCtrl.close();
  }

  void setSpeedMultiplier(double m) {
    _speedMultiplier = m.clamp(0.1, 50.0);
  }

  void seekToFraction(double f) {
    f = f.clamp(0.0, 1.0);
    final targetMeters = _totalLengthMeters * f;
    var accum = 0.0;
    for (var i = 0; i < _segments.length; i++) {
      final seg = _segments[i];
      if (accum + seg.lengthMeters >= targetMeters) {
        _currentSegmentIndex = i;
        _distanceIntoSegment = targetMeters - accum;
        final latLng = _interpolate(seg, _distanceIntoSegment / (seg.lengthMeters == 0 ? 1 : seg.lengthMeters));
  _injectLatLng(latLng, speedMps: baseSpeedMps, headingDeg: _bearingDeg(seg.from, seg.to));
        return;
      }
      accum += seg.lengthMeters;
    }
    // If reached here, clamp to end
    final lastSeg = _segments.last;
    _currentSegmentIndex = _segments.length - 1;
    _distanceIntoSegment = lastSeg.lengthMeters;
  _injectLatLng(lastSeg.to, speedMps: baseSpeedMps, headingDeg: _bearingDeg(lastSeg.from, lastSeg.to));
  }

  void _onTick(Timer _) {
    if (_currentSegmentIndex >= _segments.length) {
      stop();
      return;
    }
    final seg = _segments[_currentSegmentIndex];
  final segSpeed = baseSpeedMps * _speedMultiplier;
    final advance = segSpeed * tickInterval.inMilliseconds / 1000.0;
    _distanceIntoSegment += advance;
    if (_distanceIntoSegment >= seg.lengthMeters && seg.lengthMeters > 0) {
      // Move to next segment; carry over excess
      var overflow = _distanceIntoSegment - seg.lengthMeters;
      _currentSegmentIndex++;
      _distanceIntoSegment = 0.0;
      if (_currentSegmentIndex >= _segments.length) {
        _injectLatLng(seg.to, speedMps: segSpeed, headingDeg: _bearingDeg(seg.from, seg.to));
        stop();
        return;
      }
      // Potential overflow: advance into next segment recursively (rare at huge multiplier)
      while (overflow > 0 && _currentSegmentIndex < _segments.length) {
        final nextSeg = _segments[_currentSegmentIndex];
        if (overflow >= nextSeg.lengthMeters) {
          overflow -= nextSeg.lengthMeters;
          _currentSegmentIndex++;
          _distanceIntoSegment = 0.0;
          if (_currentSegmentIndex >= _segments.length) {
            _injectLatLng(nextSeg.to, speedMps: segSpeed, headingDeg: _bearingDeg(nextSeg.from, nextSeg.to));
            stop();
            return;
          }
        } else {
          _distanceIntoSegment = overflow;
          overflow = 0;
        }
      }
    }
    if (_currentSegmentIndex >= _segments.length) {
      stop();
      return;
    }
    final activeSeg = _segments[_currentSegmentIndex];
    final frac = activeSeg.lengthMeters == 0 ? 1.0 : (_distanceIntoSegment / activeSeg.lengthMeters).clamp(0.0, 1.0);
    final latLng = _interpolate(activeSeg, frac);
    final headingDeg = _bearingDeg(activeSeg.from, activeSeg.to);
    _injectLatLng(latLng, speedMps: segSpeed, headingDeg: headingDeg);
  }

  LatLng _interpolate(_SegmentSpec seg, double t) {
    final lat = seg.from.latitude + (seg.to.latitude - seg.from.latitude) * t;
    final lng = seg.from.longitude + (seg.to.longitude - seg.from.longitude) * t;
    return LatLng(lat, lng);
  }

  double _bearingDeg(LatLng a, LatLng b) {
    final lat1 = _degToRad(a.latitude);
    final lat2 = _degToRad(b.latitude);
    final dLon = _degToRad(b.longitude - a.longitude);
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    final brng = math.atan2(y, x);
    return (brng * 180.0 / math.pi + 360.0) % 360.0;
  }

  double _degToRad(double d) => d * math.pi / 180.0;

  void _injectLatLng(LatLng p, {required double speedMps, required double headingDeg}) {
    _positionCtrl.add(p);
    // In VM tests or debug test mode, use direct injection hook to bypass plugins
    if (TrackingService.isTestMode && TrackingService.injectPositionForTests != null) {
      try {
        final pos = Position(
          latitude: p.latitude,
          longitude: p.longitude,
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
      } catch (e) {
        if (kDebugMode) {
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
    } catch (e) {
      if (kDebugMode) {
        print('RouteSimulationController service injection failed: $e');
      }
    }
  }
}
