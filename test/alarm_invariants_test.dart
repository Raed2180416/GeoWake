import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geowake2/services/trackingservice.dart';
import 'package:geowake2/services/notification_service.dart';
import 'package:geowake2/services/api_client.dart';

// Helpers
Position p(double lat, double lng, {double speed = 8.0}) => Position(
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
  group('Alarm invariants', () {
    late TrackingService svc;
    late StreamController<Position> gps;

    setUp(() {
      TrackingService.isTestMode = true;
      TrackingService.testForceProximityGating = true; // enforce gating logic inside tests
      ApiClient.testMode = true;
      NotificationService.isTestMode = true;
      NotificationService.clearTestRecordedAlarms();
      // Disable sensor fusion by ensuring no accelerometer stream
      testAccelerometerStream = Stream.empty();
      gps = StreamController<Position>();
      testGpsStream = gps.stream;
      svc = TrackingService();
    });

    tearDown(() async {
      await gps.close();
      testGpsStream = null;
      await svc.stopTracking();
      NotificationService.clearTestRecordedAlarms();
      TrackingService.testForceProximityGating = false;
    });

    test('Distance alarm requires proximity stability (no fire on unstable passes)', () async {
      // Use a smaller threshold (50m) to create clear inside/outside transitions.
      // 50m ≈ 0.00045 degrees latitude.
      final dest = LatLng(0.00300, 0.0);
      await svc.startTracking(destination: dest, destinationName: 'Stop', alarmMode: 'distance', alarmValue: 0.05);
      // Inside (≈3m away)
      gps.add(p(0.00297, 0.0));
      await Future.delayed(const Duration(milliseconds: 500));
      // Outside (>100m away)
      gps.add(p(0.00410, 0.0));
      await Future.delayed(const Duration(milliseconds: 600));
      // Re-enter (inside again)
      gps.add(p(0.00298, 0.0));
      await Future.delayed(const Duration(milliseconds: 500));
      // Outside again
      gps.add(p(0.00420, 0.0));
      await Future.delayed(const Duration(seconds: 2));
      expect(NotificationService.testRecordedAlarms.isEmpty, true, reason: 'Alarm should not fire due to broken consecutive inside passes and lack of dwell');
    });

    test('Distance alarm fires after consecutive passes + dwell', () async {
      NotificationService.clearTestRecordedAlarms();
      await svc.startTracking(destination: LatLng(0.0010, 0.0), destinationName: 'Stop', alarmMode: 'distance', alarmValue: 0.05); // 50m
      // Inside-threshold positions (~20-30m from dest)
      gps.add(p(0.00078, 0.0));
      await Future.delayed(const Duration(seconds: 1));
      gps.add(p(0.00079, 0.0));
      await Future.delayed(const Duration(seconds: 1));
      gps.add(p(0.00080, 0.0));
      await Future.delayed(const Duration(seconds: 2));
      // Extra updates to ensure dwell >4s
      gps.add(p(0.00081, 0.0));
      await Future.delayed(const Duration(seconds: 1));
      gps.add(p(0.00082, 0.0));
      // Debug output
      // ignore: avoid_print
      print('TEST DEBUG: recorded alarms count = ${NotificationService.testRecordedAlarms.length}');
      expect(NotificationService.testRecordedAlarms.isNotEmpty, true, reason: 'Alarm should fire after stability criteria met');
    });

    test('GPS jump overshoot near destination does not suppress already eligible alarm', () async {
      NotificationService.clearTestRecordedAlarms();
      await svc.startTracking(destination: LatLng(0.003, 0.0), destinationName: 'Dest', alarmMode: 'distance', alarmValue: 0.3);
      // Enter threshold stably
      gps.add(p(0.00271, 0.0));
      await Future.delayed(const Duration(milliseconds: 900));
      gps.add(p(0.00272, 0.0));
      await Future.delayed(const Duration(milliseconds: 900));
      gps.add(p(0.00273, 0.0));
      await Future.delayed(const Duration(milliseconds: 2500)); // ensure dwell satisfied
      final firedBeforeJump = NotificationService.testRecordedAlarms.isNotEmpty;
      // Sudden jump beyond destination (overshoot)
      gps.add(p(0.0035, 0.0, speed: 20));
      await Future.delayed(const Duration(milliseconds: 500));
      // Alarm should have fired (or remain fired) despite overshoot
      expect(firedBeforeJump || NotificationService.testRecordedAlarms.isNotEmpty, true);
    });

    test('Time-based alarm not eligible until movement + samples accumulated', () async {
      NotificationService.clearTestRecordedAlarms();
      // Set a very small time alarm (1 minute) but remain stationary so eligibility gating blocks
      await svc.startTracking(destination: LatLng(0.01, 0.0), destinationName: 'TimeDest', alarmMode: 'time', alarmValue: 1.0);
      // Feed stationary positions inside origin area
      for (int i = 0; i < 5; i++) {
        gps.add(p(0.0, 0.0, speed: 0.0));
        await Future.delayed(const Duration(milliseconds: 300));
      }
      expect(NotificationService.testRecordedAlarms.isEmpty, true, reason: 'Time alarm should not fire before eligibility');
    });

    test('Time-based alarm fires after eligibility conditions met', () async {
      NotificationService.clearTestRecordedAlarms();
      // Accelerate gating conditions
      TrackingService.timeAlarmMinSinceStart = const Duration(seconds: 2);
      TrackingService.testTimeAlarmMinDistanceMeters = 5.0;
      TrackingService.testTimeAlarmMinSamples = 2;
  TrackingService.testBypassProximityForTime = true;
  await svc.startTracking(destination: LatLng(0.0003, 0.0), destinationName: 'TimeDest', alarmMode: 'time', alarmValue: 1.0); // 1 minute threshold
      // Provide moving samples to build distance and ETA samples
  gps.add(p(0.00000, 0.0, speed: 12.0));
      await Future.delayed(const Duration(milliseconds: 600));
  gps.add(p(0.00008, 0.0, speed: 12.0)); // ~8.8m
      await Future.delayed(const Duration(milliseconds: 700));
  gps.add(p(0.00015, 0.0, speed: 12.0)); // ~16.5m
  await Future.delayed(const Duration(milliseconds: 800));
  gps.add(p(0.00022, 0.0, speed: 12.0)); // ~24.2m
  await Future.delayed(const Duration(seconds: 3));
      expect(NotificationService.testRecordedAlarms.isNotEmpty, true, reason: 'Time alarm should fire after eligibility + ETA within threshold');
      // Reset overrides
      TrackingService.testTimeAlarmMinDistanceMeters = null;
      TrackingService.testTimeAlarmMinSamples = null;
      TrackingService.testBypassProximityForTime = false;
      TrackingService.timeAlarmMinSinceStart = const Duration(seconds: 30);
    });
  });
}
