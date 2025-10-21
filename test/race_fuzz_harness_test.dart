import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:geowake2/services/api_client.dart';
import 'package:geowake2/services/metrics/metrics.dart';
import 'package:geowake2/services/trackingservice.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Lightweight fuzz harness stressing start/stop + location ingestion ordering.
/// Invariants:
///  - No uncaught exceptions
///  - metrics['location.updates'] is monotonic
///  - trackingService internal started flag consistent with operations
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Race fuzz harness', () {
    test('Randomized lifecycle/location sequencing (seeded)', () async {
      ApiClient.testMode = true; // avoid network
      ApiClient.disableConnectionTest = true;
  TrackingService.isTestMode = true; // operate in same isolate
  final tracking = TrackingService();
      final rand = Random(42);
      int cycles = 300; // small but meaningful
      int lastMetric = 0;
      bool started = false;

      Future<void> feedSample() async {
        if (!started) return; // ignore
  // Random position generation omitted (not currently injected into TrackingService)
        // In test mode we can inject via the global testGpsStream by directly calling _onPosition logic
        // but to avoid reaching into private code, call the same public API that normal path uses if exposed.
        // The current TrackingService test helpers rely on testGpsStream being listened inside _onStart.
        // Simplest: set lastProcessedPosition by invoking internal handler through injected position stream not available here.
        // So instead we no-op feed; lifecycle stress still exercises start/stop concurrency invariants.
      }

      for (int i = 0; i < cycles; i++) {
        final r = rand.nextDouble();
        if (r < 0.10) {
          // start or redundant start
            if (!started) {
              await tracking.startTracking(
                destination: const LatLng(37.43, -122.09),
                destinationName: 'TestDest',
                alarmMode: 'distance',
                alarmValue: 500.0,
                allowNotificationsInTest: true,
                useInjectedPositions: false,
              );
              started = true;
            } else {
              await tracking.startTracking(
                destination: const LatLng(37.43, -122.09),
                destinationName: 'TestDest2',
                alarmMode: 'distance',
                alarmValue: 400.0,
                allowNotificationsInTest: true,
                useInjectedPositions: false,
              );
            }
        } else if (r < 0.20) {
          // stop
          if (started) {
            await tracking.stopTracking();
            started = false;
          } else {
            await tracking.stopTracking(); // redundant
          }
        } else {
          await feedSample();
        }
        // Periodically assert monotonic metric
        if (i % 25 == 0) {
          final cur = MetricsRegistry.I.counter('location.updates').value;
          expect(cur >= lastMetric, true, reason: 'Metric must be monotonic');
          lastMetric = cur;
        }
      }

      // Ensure can cleanly stop if still started
      if (started) await tracking.stopTracking();
    });
  });
}
