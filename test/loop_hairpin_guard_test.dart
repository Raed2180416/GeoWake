import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geowake2/services/snap_to_route.dart';

void main() {
  group('Loop / hairpin backtrack guard', () {
    test('Backtrack along folded polyline is clamped', () {
      // Construct a simple hairpin: forward east then slightly north then back west parallel.
      final poly = <LatLng>[
        const LatLng(37.0, -122.0),
        const LatLng(37.0, -121.99), // ~1.1km east
        const LatLng(37.0008, -121.9895), // small north deviation before turn
        const LatLng(37.0008, -122.0), // back west creating hairpin close to start longitude
      ];
      // Pretend we previously progressed near the far end (east before returning west)
      final lastProgress = 2100.0; // meters (approx across first two segments)
      // Current GPS lies on the returning west leg early, which geometrically would map to an earlier progress.
      final point = const LatLng(37.00075, -121.995); // on the return segment but before prior progress point in order
      final r = SnapToRouteEngine.snap(point: point, polyline: poly, lastProgress: lastProgress, maxRegressionMeters: 30);
      expect(r.backtrackClamped, isTrue, reason: 'Should flag backtrack clamp in hairpin');
      // Ensure progress not regressed beyond tolerance
      expect(r.progressMeters + 1 >= lastProgress - 30, isTrue);
      expect(r.progressMeters >= lastProgress - 1, isTrue, reason: 'Clamped to prevent large backward jump');
    });
  });
}
