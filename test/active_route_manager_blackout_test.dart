import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geowake2/services/route_registry.dart';
import 'package:geowake2/services/active_route_manager.dart';

void main() {
  group('ActiveRouteManager blackout behavior', () {
    test('No pending countdown during post-switch blackout', () async {
      final reg = RouteRegistry(capacity: 5);
      final a = RouteEntry(
        key: 'A', mode: 'driving', destinationName: 'A',
        points: const [LatLng(0, 0), LatLng(0, 0.01)],
      );
      final b = RouteEntry(
        key: 'B', mode: 'driving', destinationName: 'B',
        points: const [LatLng(-0.005, 0.005), LatLng(0.005, 0.005)],
      );
      reg.upsert(a);
      reg.upsert(b);

      final mgr = ActiveRouteManager(
        registry: reg,
        sustainDuration: const Duration(milliseconds: 120),
        switchMarginMeters: 5,
        postSwitchBlackout: const Duration(milliseconds: 300),
      );

      mgr.setActive('A');
  // Wait for initial blackout to expire so a switch can occur
  await Future<void>.delayed(const Duration(milliseconds: 380));

  // Sustain near B to trigger a switch (this will start a new blackout)
      final sw = Completer<void>();
      final switchSub = mgr.switchStream.listen((e) {
        if (e.fromKey == 'A' && e.toKey == 'B' && !sw.isCompleted) sw.complete();
      });
      // Move toward B and hold
  mgr.ingestPosition(const LatLng(0.002, 0.005));
  await Future<void>.delayed(const Duration(milliseconds: 140));
  mgr.ingestPosition(const LatLng(0.002, 0.005));
  // One more ingest to ensure evaluation triggers after sustain
  await Future<void>.delayed(const Duration(milliseconds: 80));
  mgr.ingestPosition(const LatLng(0.002, 0.005));
  await sw.future.timeout(const Duration(seconds: 3));

      // Immediately after switch, still within blackout, state should not advertise pending switch
      final states = <ActiveRouteState>[];
      final sub = mgr.stateStream.listen(states.add);
      mgr.ingestPosition(const LatLng(0.002, 0.005));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(states.last.pendingSwitchToKey, isNull);
      expect(states.last.pendingSwitchInSeconds, isNull);

      await sub.cancel();
      await switchSub.cancel();
      mgr.dispose();
    });
  });
}
