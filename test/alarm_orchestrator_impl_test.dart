import 'dart:async';
import 'package:flutter_test/flutter_test.dart';

import 'package:geowake2/services/refactor/interfaces.dart';
import 'package:geowake2/services/refactor/location_types.dart';
import 'package:geowake2/services/refactor/alarm_orchestrator_impl.dart';

void main() {
  group('AlarmOrchestratorImpl distance mode', () {
    test('fires after consecutive passes and dwell', () async {
      final orch = AlarmOrchestratorImpl(requiredPasses: 3, minDwell: const Duration(milliseconds: 150));
      orch.configure(const AlarmConfig(
        distanceThresholdMeters: 60, // 60m radius
        timeETALimitSeconds: 0,
        minEtaSamples: 3,
        stopsThreshold: 0,
      ));
      orch.registerDestination(const DestinationSpec(lat: 10.0, lng: 10.0, name: 'Target'));

      final events = <AlarmEvent>[];
      final sub = orch.events$.listen(events.add);

      DateTime t = DateTime.now();
      LocationSample sample(double lat, double lng) => LocationSample(
            lat: lat,
            lng: lng,
            speedMps: 5,
            timestamp: t = t.add(const Duration(milliseconds: 100)),
          );

      // Far outside threshold
      orch.update(sample: sample(10.0008, 10.0008), snapped: null); // ~125m
      await Future.delayed(const Duration(milliseconds: 20));
      expect(events.where((e) => e.type == 'TRIGGERED'), isEmpty);

      // Enter threshold region - need 3 passes + dwell 150ms
      orch.update(sample: sample(10.0003, 10.0003), snapped: null); // pass 1 (~47m)
      await Future.delayed(const Duration(milliseconds: 60));
      orch.update(sample: sample(10.00031, 10.00031), snapped: null); // pass 2
      await Future.delayed(const Duration(milliseconds: 60));
      orch.update(sample: sample(10.000305, 10.000305), snapped: null); // pass 3 completes passes
      await Future.delayed(const Duration(milliseconds: 80)); // ensure dwell >=150ms total since first pass

      // Still need one more update inside to evaluate firing after dwell
      orch.update(sample: sample(10.000304, 10.000304), snapped: null);
      await Future.delayed(const Duration(milliseconds: 20));

      expect(events.where((e) => e.type == 'TRIGGERED').length, 1, reason: 'Alarm should have fired once');

      // Additional updates should not refire
      orch.update(sample: sample(10.000303, 10.000303), snapped: null);
      await Future.delayed(const Duration(milliseconds: 20));
      expect(events.where((e) => e.type == 'TRIGGERED').length, 1, reason: 'Alarm must be single-fire');

      await sub.cancel();
    });
  });
}
