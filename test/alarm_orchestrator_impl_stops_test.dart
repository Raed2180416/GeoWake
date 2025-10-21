import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:geowake2/services/refactor/alarm_orchestrator_impl.dart';
import 'package:geowake2/services/refactor/interfaces.dart';
import 'package:geowake2/services/refactor/location_types.dart';

void main() {
  group('AlarmOrchestratorImpl stops mode', () {
    test('fires when remaining stops <= threshold with stability gating', () async {
      final orch = AlarmOrchestratorImpl(requiredPasses: 2, minDwell: const Duration(milliseconds: 120));
      orch.configure(const AlarmConfig(
        distanceThresholdMeters: 0,
        timeETALimitSeconds: 0,
        minEtaSamples: 3,
        stopsThreshold: 2, // fire at <=2 remaining
      ));
      orch.registerDestination(const DestinationSpec(lat: 1, lng: 1, name: 'Dest'));
      orch.setTotalRouteMeters(1000); // synthetic
      orch.setTotalStops(10); // total stops

      final events = <AlarmEvent>[];
      final sub = orch.events$.listen(events.add);

      DateTime t = DateTime.now();
      LocationSample sample(double progMeters) => LocationSample(
            lat: 1.0,
            lng: 1.0,
            speedMps: 10,
            timestamp: t = t.add(const Duration(milliseconds: 80)),
          );
      SnappedPosition snap(double progMeters) => SnappedPosition(
            lat: 1.0,
            lng: 1.0,
            routeId: 'r',
            progressMeters: progMeters,
            lateralOffsetMeters: 0,
            segmentIndex: 0,
          );

      // Progress until remaining stops just above threshold (>2)
      // remaining = total - ratio*10 => need covered <8 stops => ratio <0.8 => progMeters <800
      orch.update(sample: sample(0), snapped: snap(700)); // remaining ~3
      await Future.delayed(const Duration(milliseconds: 50));
      expect(events.where((e) => e.type == 'TRIGGERED'), isEmpty);

      // Enter threshold zone (remaining <=2): need passes+dwell
      orch.update(sample: sample(0), snapped: snap(820)); // pass 1 (remaining 1.8)
      await Future.delayed(const Duration(milliseconds: 90));
      orch.update(sample: sample(0), snapped: snap(830)); // pass 2 (dwell >=120ms?) maybe not yet
      await Future.delayed(const Duration(milliseconds: 60));
      // One more inside after dwell
      orch.update(sample: sample(0), snapped: snap(840));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(events.where((e) => e.type == 'TRIGGERED').length, 1);

      await sub.cancel();
    });
  });
}
