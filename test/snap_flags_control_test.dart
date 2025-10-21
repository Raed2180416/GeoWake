import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geowake2/services/snap_to_route.dart';

void main() {
  group('Snap flags control scenarios', () {
  test('Normal forward motion has no flags', () {
      final poly = [
        const LatLng(37.0, -122.0),
        const LatLng(37.0, -121.99),
        const LatLng(37.0, -121.98),
      ];
      final lastPoint = const LatLng(37.0, -122.0);
  // Use a modest forward movement (<180m teleport threshold)
  final nextPoint = const LatLng(37.0, -121.9984); // ~140m east
      // Establish a credible lastProgress using an initial snap (simulate forward movement start)
      final baseline = SnapToRouteEngine.snap(point: lastPoint, polyline: poly);
  final r2 = SnapToRouteEngine.snap(point: nextPoint, polyline: poly, lastProgress: baseline.progressMeters);
  // Debug log
  // ignore: avoid_print
  print('baselineProgress=${baseline.progressMeters} rawBest=${r2.rawBestProgressMeters} final=${r2.progressMeters} regressionTriggered=${r2.regressionTriggered} backtrack=${r2.backtrackClamped}');
      expect(r2.backtrackClamped, isFalse);
      expect(r2.teleportDetected, isFalse);
      expect(r2.regressionTriggered, isFalse, reason: 'Regression should not trigger for forward progress');
      expect(r2.progressMeters >= r2.rawBestProgressMeters - 0.1, isTrue);
    });

    test('Teleport without backtrack sets teleport flag only', () {
      final poly = [
        const LatLng(37.0, -122.0),
        const LatLng(37.0, -121.99),
        const LatLng(37.0, -121.98),
      ];
      final lastPoint = const LatLng(37.0, -122.0);
      final farPoint = const LatLng(37.0, -121.9815); // large jump forward
      final r = SnapToRouteEngine.snap(point: farPoint, polyline: poly, lastSnappedPoint: lastPoint, lastProgress: 50.0);
      expect(r.teleportDetected, isTrue);
      expect(r.backtrackClamped, isFalse);
    });

  test('Hairpin triggers backtrack but not teleport', () {
      final poly = [
        const LatLng(37.0, -122.0),
        const LatLng(37.0, -121.99),
        const LatLng(37.0008, -121.9895),
        const LatLng(37.0008, -122.0),
      ];
      final lastProgress = 2100.0;
      final pointOnReturn = const LatLng(37.00075, -121.995);
      // Provide lastSnappedPoint close to current point to avoid teleport flag while still forcing regression clamp.
      final r = SnapToRouteEngine.snap(point: pointOnReturn, polyline: poly, lastProgress: lastProgress, lastSnappedPoint: pointOnReturn);
      expect(r.backtrackClamped, isTrue);
      expect(r.teleportDetected, isFalse);
    });
  });
}
