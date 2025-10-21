import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:geowake2/services/refactor/alarm_orchestrator_impl.dart';
import 'package:geowake2/services/refactor/interfaces.dart';
import 'package:geowake2/services/refactor/location_types.dart';
import 'package:geowake2/services/transfer_utils.dart';

void main() {
  test('EVENT_ALARM TTL suppression prevents rapid duplicates then allows after expiry', () async {
    final orch = AlarmOrchestratorImpl(requiredPasses: 1, minDwell: const Duration(milliseconds: 5));
    orch.emitTTL = const Duration(milliseconds: 300);
    // No distance/time/stops triggering to isolate event alarms
    orch.configure(const AlarmConfig(
      distanceThresholdMeters: 0,
      timeETALimitSeconds: 0,
      minEtaSamples: 0,
      stopsThreshold: 0,
    ));
    orch.registerDestination(const DestinationSpec(lat: 0, lng: 0, name: 'D'));
    orch.setProximityGatingEnabled(false);
    orch.setEventTriggerWindowMeters(20);
    orch.setRouteEvents([RouteEventBoundary(meters: 100, type: 'transfer', label: 'S')]);

    final eventTypes = <String>[];
    final sub = orch.events$.listen((e) { if (e.type == 'EVENT_ALARM') eventTypes.add(e.type); });

    LocationSample sample(double progMeters) => LocationSample(lat: 0, lng: 0, speedMps: 8, timestamp: DateTime.now());
    SnappedPosition snapped(double progMeters) => SnappedPosition(
      lat: 0, lng: 0, routeId: 'r', progressMeters: progMeters, lateralOffsetMeters: 0, segmentIndex: 0,
    );

    // Repeatedly feed progress at/beyond boundary within TTL window
    for (int i=0;i<4;i++) {
      orch.update(sample: sample(100), snapped: snapped(100));
      await Future.delayed(const Duration(milliseconds: 70));
    }
    expect(eventTypes.length, 1, reason: 'Only first EVENT_ALARM should emit within TTL');

    // After TTL expiry another should emit
  await Future.delayed(const Duration(milliseconds: 350));
  // Re-feed same boundary; orchestrator increments index after first event so reconfigure to simulate recurring boundary
  orch.setRouteEvents([RouteEventBoundary(meters: 100, type: 'transfer', label: 'S')]);
  orch.update(sample: sample(100), snapped: snapped(100));
    await Future.delayed(const Duration(milliseconds: 20));
    expect(eventTypes.length, 2, reason: 'Second EVENT_ALARM after TTL expiry');

    await sub.cancel();
  });
}
