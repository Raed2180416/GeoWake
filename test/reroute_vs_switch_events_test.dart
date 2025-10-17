import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geowake2/services/route_registry.dart';
import 'package:geowake2/services/active_route_manager.dart';
import 'package:geowake2/services/event_bus.dart';
import 'package:geowake2/services/reroute_policy.dart';

RouteEntry mk(String key, List<LatLng> pts) => RouteEntry(
  key: key,
  mode: 'driving',
  destinationName: key,
  points: pts,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Reroute vs Switch events', () {
    late List<DomainEvent> events;
    late StreamSubscription sub;

    setUp(() {
      events = [];
      sub = EventBus().stream.listen(events.add);
    });

    tearDown(() async { await sub.cancel(); });

    test('Pure switch emits RouteSwitchedEvent without reroute decision', () async {
      final r1 = mk('r1', [LatLng(0,0), LatLng(0,0.01)]);
      final r2 = mk('r2', [LatLng(0.0005,0), LatLng(0.0005,0.01)]);
      final registry = RouteRegistry();
      registry.upsert(r1);
      registry.upsert(r2);
      final mgr = ActiveRouteManager(
        registry: registry,
        sustainDuration: const Duration(milliseconds: 10),
        postSwitchBlackout: const Duration(milliseconds: 5),
        switchMarginMeters: 5, // small margin so offset difference triggers candidate
      );
      mgr.setActive('r1');
      // Move closer to r2 offset
      for (int i=0;i<5;i++) {
        mgr.ingestPosition(LatLng(0.0005, 0.002 + i*0.001));
        await Future.delayed(const Duration(milliseconds: 5));
      }
      await Future.delayed(const Duration(milliseconds: 30));
  expect(events.where((e)=> e is RouteSwitchedEvent).length, greaterThanOrEqualTo(1));
  expect(events.where((e)=> e is RerouteDecisionEvent && e.cause=='sustained_deviation').isEmpty, true);
    });

    test('Reroute decision emits RerouteDecisionEvent', () async {
      final policy = ReroutePolicy(cooldown: const Duration(milliseconds: 50));
      policy.onSustainedDeviation(at: DateTime.now());
      await Future.delayed(const Duration(milliseconds: 5));
  expect(events.where((e)=> e is RerouteDecisionEvent && e.cause=='sustained_deviation').length, 1);
    });

    test('Cooldown deviation emits cooldown-active cause', () async {
      final policy = ReroutePolicy(cooldown: const Duration(milliseconds: 200));
      policy.onSustainedDeviation(at: DateTime.now());
      policy.onSustainedDeviation(at: DateTime.now().add(const Duration(milliseconds: 50))); // within cooldown
      await Future.delayed(const Duration(milliseconds: 5));
  expect(events.where((e)=> e is RerouteDecisionEvent && e.cause=='cooldown_active').length, 1);
    });
  });
}
