import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geowake2/services/trackingservice.dart';
import 'package:geowake2/services/notification_service.dart';
import 'mock_location_provider.dart';
import 'package:geowake2/services/metrics/metrics.dart';

/// Rapid-fire location update stress test.
/// Feeds a large burst of GPS samples in tight timing to surface race conditions
/// in the tracking pipeline (snapping, deviation, orchestrator metrics updates).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TrackingService.isTestMode = true;
    NotificationService.isTestMode = true;
    NotificationService.clearTestRecordedAlarms();
  });

  tearDown(() async {
    // No explicit reset API; recreate counters by referencing snapshot (ensures test isolation via process scope)
    TrackingService.isTestMode = false;
    NotificationService.isTestMode = false;
    NotificationService.clearTestRecordedAlarms();
  });

  test('High frequency 200 location bursts processed without loss (bounded by mock delay)', () async {
    final mock = MockLocationProvider();
    testGpsStream = mock.positionStream;
    final tracking = TrackingService();

    // Simple straight line route ~1km eastward
    final start = LatLng(12.9600, 77.5850);
    final routePoints = List.generate(50, (i) => LatLng(start.latitude, start.longitude + i * 0.0002));
    tracking.registerRoute(
      key: 'R1',
      mode: 'driving',
      destinationName: 'Dest',
      points: routePoints,
    );

    await tracking.startTracking(
      destination: routePoints.last,
      destinationName: 'Dest',
      alarmMode: 'distance',
      alarmValue: 0.4,
    );

    // Generate 200 samples (mock provider currently has fixed 50ms pacing -> ~10/s)
    final samples = <LatLng>[];
    for (int i = 0; i < 200; i++) {
      final frac = (i / 199.0);
      final baseLon = start.longitude + frac * (routePoints.last.longitude - start.longitude);
      final jitterLat = start.latitude + ((i % 5) - 2) * 0.00001; // small lateral jitter
      samples.add(LatLng(jitterLat, baseLon));
    }

    // Play route (provider fixed 50ms delay)
    await mock.playRoute(samples);

    // Allow pipeline microtasks to drain
    await Future.delayed(const Duration(milliseconds: 300));

    final snapCounter = MetricsRegistry.I.counter('location.updates');
    final snapCount = snapCounter.value;

    // Expect all samples processed exactly once
    expect(snapCount, samples.length, reason: 'All location updates should be processed without loss');

    // No unexpected alarms should fire under distance threshold this early
    final fired = NotificationService.testRecordedAlarms;
    expect(fired.where((a) => a['title']?.toString().toLowerCase().contains('wake') ?? false).length <= 1, isTrue);

    await tracking.stopTracking();
    mock.dispose();
  }, timeout: const Timeout(Duration(seconds: 30)));
}
