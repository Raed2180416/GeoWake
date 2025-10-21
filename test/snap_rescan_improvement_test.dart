import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geowake2/services/snap_to_route.dart';

// This test ensures adaptive full rescan reduces offset when hint window misses true nearest segment.
void main() {
  test('Adaptive rescan improves large offset', () {
    // Polyline shaped so that segment far from hint is actually closest.
    final poly = <LatLng>[
      const LatLng(37.0, -122.0), // 0
      const LatLng(37.0, -121.99), // 1
      const LatLng(37.01, -121.99), // 2 vertical up far east
      const LatLng(37.01, -122.0), // 3 back west forming a rectangle
    ];

    final outsidePoint = const LatLng(37.0095, -122.0002); // near segment (3->2) but hint will bias early

    // Run with incorrect hint restricting search to early segments only (simulate narrow searchWindow effect)
    final rHint = SnapToRouteEngine.snap(point: outsidePoint, polyline: poly, hintIndex: 0, searchWindow: 1);
    // Force scenario: if offset is large, engine should trigger full scan (due to >250m) and improve result.
    final rFull = SnapToRouteEngine.snap(point: outsidePoint, polyline: poly, hintIndex: 0, searchWindow: 1);

    // Because logic rescans in-place, both calls should yield improved (small) offset; assert it's reasonably small.
    expect(rFull.lateralOffsetMeters, lessThan(300));
    // Ensure we didn't get stuck with an infinite/huge offset
    expect(rFull.lateralOffsetMeters.isFinite, isTrue);
    // Validate segment index likely in later rectangle (2 or 3)
    expect(rFull.segmentIndex, anyOf(2, 3));

    // Sanity: ensure original hinted pass had recognized improvement (not huge > 500m)
    expect(rHint.lateralOffsetMeters, lessThan(500));
  });
}
