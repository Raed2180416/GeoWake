
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geowake2/services/polyline_simplifier.dart';

void main() {
  group('PolylineSimplifier', () {
    // A simple polyline forming a rough "L" shape.
    final List<LatLng> polyline = [
      LatLng(37.4219999, -122.0840575),
      LatLng(37.422, -122.084),
      LatLng(37.4221, -122.0839),
      LatLng(37.4222, -122.0838),
      LatLng(37.4223, -122.0837),
    ];

    test('simplifyPolyline reduces points when tolerance is low', () {
      // With a low tolerance, the algorithm should keep more points.
      List<LatLng> result = PolylineSimplifier.simplifyPolyline(polyline, 0.5);
      // Expect at least the first and last points.
      expect(result.first, polyline.first);
      expect(result.last, polyline.last);
      // With a very low tolerance, it might keep all points.
      expect(result.length, greaterThanOrEqualTo(2));
    });

    test('simplifyPolyline reduces points when tolerance is higher', () {
      // With a higher tolerance, the polyline should be simplified to just two points.
      List<LatLng> result = PolylineSimplifier.simplifyPolyline(polyline, 10);
      expect(result.length, equals(2));
      expect(result.first, polyline.first);
      expect(result.last, polyline.last);
    });

    test('compress and decompress polyline', () {
      List<LatLng> simplified = PolylineSimplifier.simplifyPolyline(polyline, 10);
      String compressed = PolylineSimplifier.compressPolyline(simplified);
      List<LatLng> decompressed = PolylineSimplifier.decompressPolyline(compressed);
      // The decompressed polyline should equal the simplified polyline.
      expect(decompressed.length, equals(simplified.length));
      for (int i = 0; i < decompressed.length; i++) {
        expect(decompressed[i].latitude, closeTo(simplified[i].latitude, 0.000001));
        expect(decompressed[i].longitude, closeTo(simplified[i].longitude, 0.000001));
      }
    });
  });
}
