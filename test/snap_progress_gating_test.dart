import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geowake2/services/snap_to_route.dart';

void main() {
  group('SnapToRoute forward progress gating', () {
    test('Large regression is clamped', () {
      final poly = <LatLng>[
        const LatLng(37.0, -122.0),
        const LatLng(37.0, -121.99),
        const LatLng(37.0, -121.98),
      ];
      // Simulate last progress near end
      final lastProgress = 1800.0; // meters
      // Point snaps earlier artificially (simulate hairpin/backtrack)
      final point = const LatLng(37.0, -121.9955); // near middle
      final r = SnapToRouteEngine.snap(point: point, polyline: poly, lastProgress: lastProgress);
      expect(r.progressMeters >= lastProgress - 1, isTrue, reason: 'Progress should not regress more than tolerance');
    });
  });
}
