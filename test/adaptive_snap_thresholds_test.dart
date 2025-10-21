import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geowake2/services/snap_to_route.dart';

void main() {
  group('Adaptive snap thresholds & teleport detection', () {
    test('Normal incremental movement does not flag teleport', () {
      final poly = <LatLng>[
        const LatLng(37.0, -122.0),
        const LatLng(37.0, -121.99),
        const LatLng(37.0, -121.98),
      ];
      final lastPoint = const LatLng(37.0, -121.995);
      final newPoint = const LatLng(37.0, -121.9945); // ~40-50m move
      final r = SnapToRouteEngine.snap(point: newPoint, polyline: poly, lastSnappedPoint: lastPoint);
      expect(r.teleportDetected, isFalse);
    });

    test('Large jump flags teleport and still returns a snap', () {
      final poly = <LatLng>[
        const LatLng(37.0, -122.0),
        const LatLng(37.0, -121.99),
        const LatLng(37.0, -121.98),
      ];
      final lastPoint = const LatLng(37.0, -122.0);
      // Simulate a big GPS jump far beyond typical per-update distance (>180m threshold)
      final newPoint = const LatLng(37.0, -121.982);
      final r = SnapToRouteEngine.snap(point: newPoint, polyline: poly, lastSnappedPoint: lastPoint, hintIndex: 0);
      expect(r.teleportDetected, isTrue, reason: 'Should mark teleport due to large jump');
      expect(r.lateralOffsetMeters, lessThan(300));
    });
  });
}
