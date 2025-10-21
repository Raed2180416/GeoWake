import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geowake2/services/simulation/route_simulator.dart';
import 'package:geowake2/services/trackingservice.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('Simulation -> destination alarm', () {
    test('distance alarm fires on simulated route', () async {
      TrackingService.isTestMode = true;
      final polyline = <LatLng>[
        const LatLng(37.0, -122.0),
        const LatLng(37.0005, -122.0005),
        const LatLng(37.0010, -122.0010),
      ];
      final sim = RouteSimulationController(polyline: polyline, baseSpeedMps: 25.0, tickInterval: const Duration(milliseconds: 200));
      await sim.startTrackingWithSimulation(
        destinationName: 'TestDest',
        alarmMode: 'distance',
        alarmValue: 50, // meters
      );
      sim.start();
      // Poll until alarm fires or timeout
      final start = DateTime.now();
      bool fired = false;
      while (DateTime.now().difference(start) < const Duration(seconds: 8)) {
        await Future.delayed(const Duration(milliseconds: 200));
        if (TrackingService().alarmTriggered) {
          fired = true;
          break;
        }
      }
      sim.dispose();
      expect(fired, isTrue, reason: 'Alarm should fire within simulated journey');
    });
  });
}
