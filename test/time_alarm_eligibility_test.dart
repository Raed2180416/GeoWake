import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geowake2/services/trackingservice.dart';
import 'package:geowake2/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Time-alarm eligibility and firing', () {
    setUp(() {
      TrackingService.isTestMode = true;
      NotificationService.isTestMode = true;
      NotificationService.clearTestRecordedAlarms();
    });

    test('Does not fire before eligible; fires once eligible under threshold', () async {
      final svc = TrackingService();
      TrackingService.timeAlarmMinSinceStart = const Duration(seconds: 2);
      final origin = const LatLng(12.9716, 77.5946);
      final destination = const LatLng(12.9816, 77.5946); // ~1km north

      // Prepare GPS stream
      final ctrl = StreamController<Position>();
      testGpsStream = ctrl.stream;

      // Start tracking in time mode: threshold 1 minute
      await svc.startTracking(
        destination: destination,
        destinationName: 'Dest',
        alarmMode: 'time',
        alarmValue: 1.0,
        allowNotificationsInTest: true,
        useInjectedPositions: false,
      );

      // 1) Feed a couple of stationary/slow samples: not enough movement or ETA samples
      Position mkPos(double lat, double lng, double speed) => Position(
        latitude: lat,
        longitude: lng,
        timestamp: DateTime.now(),
        accuracy: 5.0,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: speed,
        speedAccuracy: 1.0,
      );

      ctrl.add(mkPos(origin.latitude, origin.longitude, 0.1));
      await Future.delayed(const Duration(milliseconds: 80));
      ctrl.add(mkPos(origin.latitude + 0.0001, origin.longitude, 0.3));
      await Future.delayed(const Duration(milliseconds: 80));

      // Verify no alarm yet
      expect(NotificationService.testRecordedAlarms.where((e) => e['title'] == 'Wake Up! ').isNotEmpty, isFalse);

      // 2) Provide >=3 ETA samples with credible speed and move ~120m
      for (int i = 0; i < 3; i++) {
        ctrl.add(mkPos(origin.latitude + 0.001 + i * 0.0001, origin.longitude, 3.0));
        await Future.delayed(const Duration(milliseconds: 120));
      }

  // 3) Wait until >= configurable min since start (2s) to pass the final eligibility gate.
  // In the full test suite there is additional scheduling overhead, so we extend this
  // delay to be safely above 2s from first sample ingestion.
  await Future.delayed(const Duration(milliseconds: 1800));

      // Feed few more moving samples to allow periodic check to run
      for (int i = 0; i < 6; i++) {
        ctrl.add(mkPos(origin.latitude + 0.0015 + i * 0.00005, origin.longitude, 3.0));
        await Future.delayed(const Duration(milliseconds: 120));
      }

      // At this point, eligibility should be true. Now make ETA under threshold by being close.
  ctrl.add(mkPos(destination.latitude - 0.0002, destination.longitude, 10.0));
      await Future.delayed(const Duration(milliseconds: 250));

      final alarms = NotificationService.testRecordedAlarms.where((e) => e['title'] == 'Wake Up! ').toList();
      expect(alarms.isNotEmpty, isTrue);

      await svc.stopTracking();
      await ctrl.close();
    });
  });
}
