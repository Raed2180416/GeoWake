import 'dart:async';
// no math imports needed currently
import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'package:geolocator/geolocator.dart';
import 'package:geowake2/services/route_registry.dart';
import 'package:geowake2/services/snap_to_route.dart';
import 'package:geowake2/services/event_bus.dart';

class RouteSwitchEvent {
  final String fromKey;
  final String toKey;
  final DateTime at;
  RouteSwitchEvent({required this.fromKey, required this.toKey, DateTime? at}) : at = at ?? DateTime.now();
}

class ActiveRouteState {
  final String activeKey;
  final LatLng snapped;
  final double offsetMeters;
  final double progressMeters;
  final double remainingMeters;
  final String? pendingSwitchToKey;
  final double? pendingSwitchInSeconds;
  const ActiveRouteState({
    required this.activeKey,
    required this.snapped,
    required this.offsetMeters,
    required this.progressMeters,
    required this.remainingMeters,
    this.pendingSwitchToKey,
    this.pendingSwitchInSeconds,
  });
}

class ActiveRouteManager {
  final RouteRegistry registry;
  final Duration sustainDuration;
  final double switchMarginMeters; // candidate must be this much better in offset
  final Duration postSwitchBlackout;

  String? _activeKey;
  // removed: wall-clock based candidate since
  String? _candidateKey;
  // removed: wall-clock based last switch time

  // Track last observed progress per route to validate forward motion for candidates
  final Map<String, double> _lastProgressByRoute = <String, double>{};
  // Rolling bearing samples per route (if caller feeds external bearing later)
  final Map<String, List<double>> _bearingSamples = <String, List<double>>{};
  int bearingWindow = 5;

  // Use monotonic timers to avoid wall-clock jumps affecting countdowns
  Stopwatch? _candidateTimer;
  Stopwatch? _blackoutTimer;

  final _stateCtrl = StreamController<ActiveRouteState>.broadcast();
  final _switchCtrl = StreamController<RouteSwitchEvent>.broadcast();

  Stream<ActiveRouteState> get stateStream => _stateCtrl.stream;
  Stream<RouteSwitchEvent> get switchStream => _switchCtrl.stream;

  ActiveRouteManager({
    required this.registry,
    this.sustainDuration = const Duration(seconds: 6),
    this.switchMarginMeters = 50,
    this.postSwitchBlackout = const Duration(seconds: 5),
  });

  void setActive(String key) {
    _activeKey = key;
    _candidateKey = null;
    // reset timers
    _candidateTimer?.stop();
    _candidateTimer = null;
    _blackoutTimer = Stopwatch()..start(); // start blackout immediately on activation
  }

  void ingestPosition(LatLng rawPosition) {
    if (_activeKey == null) return;
    final active = registry.entries.firstWhere((e) => e.key == _activeKey, orElse: () => registry.entries.isNotEmpty ? registry.entries.first : throw StateError('No routes'));

    // Snap to active route first
  final snapActive = _snapTo(active, rawPosition);
    // Record progress trend for the active route to inform future agreement checks
    _lastProgressByRoute[active.key] = snapActive.progressMeters;
    registry.updateSessionState(active.key, lastSnapIndex: snapActive.segmentIndex, lastProgressMeters: snapActive.progressMeters);

    // Candidate search near current location
    final candidates = registry.candidatesNear(rawPosition, radiusMeters: 1200, maxCandidates: 3);
  String bestKey = active.key;
  double bestOffset = snapActive.lateralOffsetMeters;

    for (final c in candidates) {
      final s = c.key == active.key ? snapActive : _snapTo(c, rawPosition);
      // Update last progress memory for this candidate for subsequent agreement checks
      _lastProgressByRoute[c.key] = s.progressMeters;
      if (s.lateralOffsetMeters + switchMarginMeters < bestOffset) {
        // Heading and progress consistency check (lightweight)
        final agree = _headingAgreement(c, s);
        if (agree > 0.3) { // require minimal agreement
          bestOffset = s.lateralOffsetMeters;
          bestKey = c.key;
        }
      }
    }

    // Handle candidate selection with sustain and blackout
    final now = DateTime.now();
  final inBlackout = _blackoutTimer != null && _blackoutTimer!.isRunning && _blackoutTimer!.elapsed < postSwitchBlackout;
    bool didSwitch = false;
    if (bestKey != active.key && !inBlackout) {
      if (_candidateKey != bestKey) {
        _candidateKey = bestKey;
        _candidateTimer?.stop();
        _candidateTimer = Stopwatch()..start();
      } else {
        final elapsedOk = _candidateTimer != null && _candidateTimer!.elapsed >= sustainDuration;
        if (elapsedOk) {
          // Switch routes
          final fromKey = active.key;
          _activeKey = bestKey;
          _candidateKey = null;
          _candidateTimer?.stop();
          _candidateTimer = null;
          _blackoutTimer = Stopwatch()..start();
          _switchCtrl.add(RouteSwitchEvent(fromKey: fromKey, toKey: bestKey, at: now));
          EventBus().emit(RouteSwitchedEvent(fromKey, bestKey));
          didSwitch = true;
        }
      }
    } else {
      _candidateKey = null;
      _candidateTimer?.stop();
      _candidateTimer = null;
    }

  // Retrieve the active entry again if a switch occurred; guard against race conditions where
  // the registry might have been mutated (tests can clear or replace entries rapidly).
  RouteEntry activeEntry;
  if (didSwitch) {
    if (registry.entries.isEmpty) {
      // Nothing to emit; active key no longer valid.
      return;
    }
    try {
      activeEntry = registry.entries.firstWhere((e) => e.key == _activeKey);
    } catch (_) {
      // Fallback: adopt first entry to keep manager alive instead of throwing.
      _activeKey = registry.entries.first.key;
      activeEntry = registry.entries.first;
    }
  } else {
    // We already have the active route in variable `active`.
    activeEntry = active;
  }
  // Emit state based on the correct active route. If a switch occurred in this call,
  // recompute snapping for the new active to avoid mixing progress from the previous route.
  final SnapResult snapForState = didSwitch ? _snapTo(activeEntry, rawPosition) : snapActive;
  if (didSwitch) {
    _lastProgressByRoute[activeEntry.key] = snapForState.progressMeters;
    registry.updateSessionState(activeEntry.key, lastSnapIndex: snapForState.segmentIndex, lastProgressMeters: snapForState.progressMeters);
  }
  final progress = snapForState.progressMeters;
  final remaining = (activeEntry.lengthMeters - progress).clamp(0.0, double.infinity);
    double? pendingSecs;
    String? pendingKey;
    final inBlackout2 = _blackoutTimer != null && _blackoutTimer!.isRunning && _blackoutTimer!.elapsed < postSwitchBlackout;
    if (_candidateKey != null && _candidateTimer != null && !inBlackout2) {
      final elapsed = _candidateTimer!.elapsed;
      final left = sustainDuration - elapsed;
      if (left > Duration.zero) {
        // Clamp to sustainDuration to avoid spikes from any anomalies
        final leftMs = left.inMilliseconds.clamp(0, sustainDuration.inMilliseconds);
        pendingSecs = leftMs / 1000.0;
        pendingKey = _candidateKey;
      }
    }
    _stateCtrl.add(ActiveRouteState(
      activeKey: _activeKey!,
  snapped: snapForState.snappedPoint,
      offsetMeters: snapForState.lateralOffsetMeters,
      progressMeters: progress,
      remainingMeters: remaining,
      pendingSwitchToKey: pendingKey,
      pendingSwitchInSeconds: pendingSecs,
    ));
  }

  SnapResult _snapTo(RouteEntry entry, LatLng p) {
    final lastProg = entry.lastProgressMeters;
    final snap = SnapToRouteEngine.snap(
        point: p,
        polyline: entry.points,
        precomputedCumMeters: entry.cumMeters,
        hintIndex: entry.lastSnapIndex,
        searchWindow: 30,
        lastProgress: lastProg);
    // Loop / hairpin guard: we now rely on snap.backtrackClamped to indicate a prevented backward jump.
    // Future: accumulate metrics or emit domain event if snap.backtrackClamped is true multiple times consecutively.
    return snap;
  }

  double _headingAgreement(RouteEntry entry, SnapResult s) {
    // Minimal forward-progress gate using per-route memory. Avoid selecting candidates that go backwards.
    final last = _lastProgressByRoute[entry.key] ?? s.progressMeters;
    final delta = s.progressMeters - last;
    if (delta < -10) return 0.0; // strong regression: disagree
    // Nominal agreement when not regressing; can be enhanced with segment heading vs movement vector later
    // Placeholder: If bearing samples exist, we could compute variance and reduce agreement if highly volatile.
    final samples = _bearingSamples[entry.key];
    if (samples != null && samples.length >= 3) {
      final avg = samples.reduce((a,b)=>a+b)/samples.length;
      // simplistic variance check
      final variance = samples.map((v)=> (v-avg)*(v-avg)).reduce((a,b)=>a+b)/samples.length;
      if (variance > 800) { // very noisy
        return 0.45; // lower confidence
      }
    }
    return 0.6;
  }

  void dispose() {
    _stateCtrl.close();
    _switchCtrl.close();
  }
}
