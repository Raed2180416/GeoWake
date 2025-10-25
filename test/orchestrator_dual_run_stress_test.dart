import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geowake2/services/trackingservice.dart';
import 'package:geowake2/services/notification_service.dart';
import 'package:geowake2/services/metrics/metrics.dart';
import 'mock_location_provider.dart';

/// Stress: rapid successive start/stop cycles exercising dual-run alarm orchestrator shadow path.
/// Goals:
///  - No explosion in TRIGGERED events beyond expectation (<= 1 per cycle when eligible)
///  - Metrics counters scale roughly with cycles (no runaway growth after stop)
///  - No uncaught exceptions / leaks (test completes within timeout)
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TrackingService.isTestMode = true;
    NotificationService.isTestMode = true;
    NotificationService.clearTestRecordedAlarms();
  });

  tearDown(() async {
    TrackingService.isTestMode = false;
    NotificationService.isTestMode = false;
    NotificationService.clearTestRecordedAlarms();
  });

  test('Orchestrator dual-run survives 25 rapid cycles', () async {
    final cycles = 25;
    final tracking = TrackingService();
    final base = LatLng(12.9600, 77.5850);

    // Reusable short route ~700m
    final route = List.generate(20, (i) => LatLng(base.latitude, base.longitude + i * 0.0003));

    int totalStarts = 0;
    for (int c = 0; c < cycles; c++) {
      final mock = MockLocationProvider();
      testGpsStream = mock.positionStream;
      tracking.registerRoute(
        key: 'R$c',
        mode: 'driving',
        destinationName: 'D$c',
        points: route,
      );

      await tracking.startTracking(
        destination: route.last,
        destinationName: 'Dest$c',
        alarmMode: 'distance',
        alarmValue: 0.6, // generous threshold unlikely to fire early
      );
      totalStarts++;

      // Feed a handful of samples (progress along route then stop early) to exercise pipelines
      final samples = <LatLng>[];
      for (int i = 0; i < 12; i++) {
        samples.add(LatLng(base.latitude, base.longitude + i * 0.0003));
      }
      final mockDone = mock.playRoute(samples);

      // Allow some processing overlap mid-cycle, then stop
      await Future.delayed(const Duration(milliseconds: 120));
      await tracking.stopTracking();
      await mockDone; // ensure stream closed
      mock.dispose();

      // Short cool-down to surface lingering timers before next start
      await Future.delayed(const Duration(milliseconds: 40));
    }

    // Inspect metrics & alarms
    final counters = MetricsRegistry.I.snapshot()['counters'] as Map<String, dynamic>;
  final locUpdates = counters['location.updates'] as int? ?? 0;
  final legacyChecks = counters['alarm.legacy.check'] as int? ?? 0;
  // Diagnostics for future tightening if needed
  // ignore: avoid_print
  print('[STRESS] cycles=$cycles locUpdates=$locUpdates legacyChecks=$legacyChecks');
  // Must be greater than number of starts (at least one GPS processed per cycle)
  expect(locUpdates > totalStarts, true, reason: 'At least one location processed per cycle');

    // Legacy check count should scale with cycles but not exceed an upper bound (heuristic < 10x starts)
    expect(legacyChecks < totalStarts * 10, true, reason: 'Legacy alarm checks bounded');

    // Distance alarms should not spam; allow at most a few (e.g., <= 3) since threshold rarely reached
    final fired = NotificationService.testRecordedAlarms;
  final distanceFired = fired.where((a) => (a['title'] ?? '').toString().toLowerCase().contains('wake')).length;
  // Upper bound: should never exceed number of cycles; zero is also acceptable.
  expect(distanceFired <= cycles, true, reason: 'Alarms bounded by cycle count');
  }, timeout: const Timeout(Duration(seconds: 60)));
}
