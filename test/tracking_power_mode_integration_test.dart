import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geowake2/services/trackingservice.dart';
import 'package:geowake2/services/idle_power_scaler.dart';

Position p(double lat, double lng, {double speed = 0.3}) => Position(
  latitude: lat,
  longitude: lng,
  timestamp: DateTime.now(),
  accuracy: 5,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: speed,
  speedAccuracy: 0,
);

void main() {
  group('TrackingService power mode integration', () {
    late StreamController<Position> gps;
    late TrackingService svc;

    setUp(() {
      TrackingService.isTestMode = true;
      gps = StreamController<Position>();
      testGpsStream = gps.stream;
      testAccelerometerStream = Stream.empty(); // disable fusion to avoid plugin
      TrackingService.testIdleScalerFactory = () => IdlePowerScaler(
        minSamples: 4,
        windowSize: 5,
        distanceSlackMeters: 6.0,
        speedThresholdMps: 0.6,
        wakeDistanceMeters: 8.0,
        wakeSpeedMps: 2.0,
        idleMinDuration: const Duration(seconds: 2),
      );
      svc = TrackingService();
    });

    tearDown(() async {
      await gps.close();
      testGpsStream = null;
      TrackingService.testIdleScalerFactory = null;
      await svc.stopTracking();
    });

    test('Transitions idle then wakes on movement spike', () async {
      await svc.startTracking(destination: const LatLng(0.01, 0.0), destinationName: 'Dest', alarmMode: 'distance', alarmValue: 0.5);
  // Feed low movement slow samples
      for (int i = 0; i < 6; i++) {
        gps.add(p(0.0, 0.00001 * i, speed: 0.3));
        await Future.delayed(const Duration(milliseconds: 400));
      }
  // Allow scaler idleMinDuration (2s) + buffer
  await Future.delayed(const Duration(seconds: 3));
  // Add one more low movement sample to ensure evaluation after duration
  gps.add(p(0.0, 0.00007, speed: 0.3));
  await Future.delayed(const Duration(milliseconds: 100));
  expect(TrackingService.latestPowerMode, 'idle', reason: 'Should enter idle after sustained low movement');
      // Movement spike
      gps.add(p(0.0, 0.00020, speed: 3.0));
      await Future.delayed(const Duration(milliseconds: 300));
      expect(TrackingService.latestPowerMode, 'active');
    });
  });
}