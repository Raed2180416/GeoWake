import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:geowake2/services/refactor/alarm_orchestrator_impl.dart';
import 'package:geowake2/services/refactor/interfaces.dart';
import 'package:geowake2/services/refactor/location_types.dart';
import 'package:geowake2/services/transfer_utils.dart';

void main() {
  test('Event alarms fire near boundary', () async {
    final orch = AlarmOrchestratorImpl(requiredPasses: 1, minDwell: const Duration(milliseconds: 10));
    orch.setProximityGatingEnabled(false);
    orch.configure(const AlarmConfig(
      distanceThresholdMeters: 0,
      timeETALimitSeconds: 0,
      minEtaSamples: 0,
      stopsThreshold: 0,
    ));
    orch.registerDestination(const DestinationSpec(lat: 0, lng: 0, name: 'Dest'));
    orch.setTotalRouteMeters(500);
    orch.setEventTriggerWindowMeters(25); // fire within 25m
    orch.setRouteEvents([
      RouteEventBoundary(meters: 120, type: 'transfer', label: 'Station A'),
      RouteEventBoundary(meters: 250, type: 'mode_change', label: 'Start walking'),
    ]);

    final received = <String>[];
    final sub = orch.events$.listen((e) {
      if (e.type == 'EVENT_ALARM') {
        received.add(e.data['eventType'] as String);
      }
    });

    for (int i = 0; i <= 260; i += 10) {
      final sample = LocationSample(lat: 0, lng: 0, speedMps: 5, timestamp: DateTime.now());
      final snapped = SnappedPosition(
        lat: 0,
        lng: 0,
        routeId: 'r',
        progressMeters: i.toDouble(),
        lateralOffsetMeters: 0,
        segmentIndex: 0,
      );
      orch.update(sample: sample, snapped: snapped);
      await Future.delayed(const Duration(milliseconds: 5));
    }

    expect(received.length, 2, reason: 'Both events should fire');
    expect(received, containsAll(['transfer', 'mode_change']));
    await sub.cancel();
  });
}
