import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geowake2/services/geometry/segment_projection.dart';

void main() {
  group('Geometry edge cases', () {
    test('high latitude projection stability', () {
      // ~70N small polyline
      final pts = [
        const LatLng(70.0, -50.0),
        const LatLng(70.001, -50.0),
        const LatLng(70.002, -49.999),
      ];
      final proj = SegmentProjector(pts);
      final p = const LatLng(70.0012, -49.9995);
      final r = proj.project(p);
      expect(r.progressMeters, greaterThan(0));
      expect(r.progressMeters, lessThan(proj.totalLength + 5));
    });

    test('very long single segment progress fractions', () {
      final pts = [
        const LatLng(0.0, 0.0),
        const LatLng(0.2, 0.0), // ~22km
      ];
      final proj = SegmentProjector(pts);
      final total = proj.totalLength;
      final q1 = proj.project(const LatLng(0.05, 0.0002));
      final q2 = proj.project(const LatLng(0.10, -0.0001));
      final q3 = proj.project(const LatLng(0.15, 0.0003));
      expect(q1.progressMeters, closeTo(total * 0.25, total * 0.05));
      expect(q2.progressMeters, closeTo(total * 0.50, total * 0.05));
      expect(q3.progressMeters, closeTo(total * 0.75, total * 0.05));
    });

    test('duplicate consecutive points ignored', () {
      final pts = [
        const LatLng(0,0),
        const LatLng(0,0),
        const LatLng(0.001, 0),
      ];
      final proj = SegmentProjector(pts);
      final r = proj.project(const LatLng(0.0005, 0));
      expect(r.progressMeters, greaterThan(0));
      expect(r.progressMeters, lessThan(proj.totalLength));
    });
  });
}
