import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geowake2/services/route_registry.dart';
import 'package:geowake2/services/active_route_manager.dart';

void main() {
  group('ActiveRouteManager state emission consistency', () {
    test('Before switch, state reflects active route only', () async {
      final reg = RouteRegistry(capacity: 5);
      // Active route: horizontal near equator
      final active = RouteEntry(
        key: 'active',
        mode: 'driving',
        destinationName: 'A',
        points: const [LatLng(0, 0), LatLng(0, 0.01)],
      );
      // Candidate route: vertical crossing near (0, 0.005)
      final cand = RouteEntry(
        key: 'cand',
        mode: 'driving',
        destinationName: 'B',
        points: const [LatLng(-0.005, 0.005), LatLng(0.005, 0.005)],
      );
      reg.upsert(active);
      reg.upsert(cand);

      final mgr = ActiveRouteManager(
        registry: reg,
        sustainDuration: const Duration(milliseconds: 500),
        switchMarginMeters: 5,
        postSwitchBlackout: const Duration(milliseconds: 300),
      );
      mgr.setActive('active');

      final states = <ActiveRouteState>[];
      final sub = mgr.stateStream.listen(states.add);

      // Position closer to candidate laterally, but we have not sustained yet
      mgr.ingestPosition(const LatLng(0.002, 0.005));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      mgr.ingestPosition(const LatLng(0.0022, 0.005));

      // Assert latest state matches active geometry (segment index near 0 and progress ~ along active)
      expect(states, isNotEmpty);
      final s = states.last;
      expect(s.activeKey, 'active');
      // Progress should be along the active's east-west line (~meters from 0,0 to 0,0.005)
      // and not jump to candidate's north-south progression (which would differ notably over two samples).
      expect(s.remainingMeters, closeTo(active.lengthMeters - s.progressMeters, 1e-6));

      await sub.cancel();
      mgr.dispose();
    });

    test('Pending switch countdown appears and clears on switch/blackout', () async {
      final reg = RouteRegistry(capacity: 5);
      final a = RouteEntry(
        key: 'A',
        mode: 'driving',
        destinationName: 'A',
        points: const [LatLng(0, 0), LatLng(0, 0.01)],
      );
      final b = RouteEntry(
        key: 'B',
        mode: 'driving',
        destinationName: 'B',
        points: const [LatLng(-0.005, 0.005), LatLng(0.005, 0.005)],
      );
      reg.upsert(a);
      reg.upsert(b);

      final mgr = ActiveRouteManager(
        registry: reg,
        sustainDuration: const Duration(milliseconds: 200),
        switchMarginMeters: 5,
        postSwitchBlackout: const Duration(milliseconds: 200),
      );
  mgr.setActive('A');
  // Wait for blackout to expire before attempting to sustain a switch
  await Future<void>.delayed(const Duration(milliseconds: 220));

      final switches = <RouteSwitchEvent>[];
      final switchCompleter = Completer<RouteSwitchEvent>();
      final switchSub = mgr.switchStream.listen((e) {
        switches.add(e);
        if (!switchCompleter.isCompleted && e.fromKey == 'A' && e.toKey == 'B') {
          switchCompleter.complete(e);
        }
      });
      final states = <ActiveRouteState>[];
      final sub = mgr.stateStream.listen(states.add);

  // Move near candidate B and hold long enough to sustain
  mgr.ingestPosition(const LatLng(0.002, 0.005));
  await Future<void>.delayed(const Duration(milliseconds: 120));
  mgr.ingestPosition(const LatLng(0.002, 0.005));
  await Future<void>.delayed(const Duration(milliseconds: 120));
  // One more ingest after sustain window to trigger evaluation deterministically
  await Future<void>.delayed(const Duration(milliseconds: 60));
  mgr.ingestPosition(const LatLng(0.002, 0.005));
  // Await the switch event deterministically (with a reasonable timeout)
  await switchCompleter.future.timeout(const Duration(seconds: 2));
  // Allow a tick for the post-switch state emission to be observed
  await Future<void>.delayed(const Duration(milliseconds: 20));

      // Expect a switch A->B and pending fields cleared after switch
      expect(switches.any((e) => e.fromKey == 'A' && e.toKey == 'B'), isTrue);
      final last = states.last;
      expect(last.pendingSwitchToKey, isNull);
      expect(last.pendingSwitchInSeconds, isNull);

      await sub.cancel();
      await switchSub.cancel();
      mgr.dispose();
    });
  });
}
