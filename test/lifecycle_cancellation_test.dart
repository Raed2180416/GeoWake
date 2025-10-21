import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geowake2/services/trackingservice.dart';
import 'package:geowake2/services/metrics/metrics.dart';
import 'log_helper.dart';

Position _pos(double lat, double lng, {double speed = 10}) => Position(
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
  group('Lifecycle cancellation', () {
    late StreamController<Position> gps;
    late TrackingService svc;

    setUp(() {
      TrackingService.isTestMode = true;
      gps = StreamController<Position>();
      testGpsStream = gps.stream;
      svc = TrackingService();
    });

    tearDown(() async {
      await svc.stopTracking();
      await gps.close();
      testGpsStream = null;
    });

    test('No further location pipeline increments after stopTracking()', () async {
      logSection('Lifecycle cancellation');
      // Start tracking with small route (implicit) to destination
      await svc.startTracking(
        destination: const LatLng(0.01, 0.01),
        destinationName: 'Dest',
        alarmMode: 'distance',
        alarmValue: 5.0,
      );

      // Feed a few initial positions
      for (int i = 0; i < 5; i++) {
        gps.add(_pos(0.0001 * i, 0.0001 * i));
        await Future.delayed(const Duration(milliseconds: 40));
      }

      final before = MetricsRegistry.I.counter('location.updates').value;
      logInfo('location.updates before stop=$before');

      await svc.stopTracking();
      final afterStop = MetricsRegistry.I.counter('location.updates').value;
      expect(afterStop, before, reason: 'Stop should not itself increment location.updates');

      // Push more synthetic positions after stop - they should be ignored because subscription cancelled
      for (int i = 0; i < 5; i++) {
        gps.add(_pos(0.001 + 0.0001 * i, 0.001));
        await Future.delayed(const Duration(milliseconds: 30));
      }

      final afterIgnored = MetricsRegistry.I.counter('location.updates').value;
      logInfo('location.updates after ignored feed=$afterIgnored');
      expect(afterIgnored, before, reason: 'No new updates should be processed after stopTracking');
    }, timeout: const Timeout(Duration(seconds: 20)));
  });
}
