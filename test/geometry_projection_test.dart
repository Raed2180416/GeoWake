import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geowake2/services/geometry/segment_projection.dart';

void main() {
  group('SegmentProjector basic projection', () {
    test('straight line northwards', () {
      final pts = [
        const LatLng(0.0, 0.0),
        const LatLng(0.01, 0.0), // ~1112 m north
      ];
      final proj = SegmentProjector(pts);
      final mid = const LatLng(0.005, 0.0002); // slightly east offset
      final r = proj.project(mid);
      expect(r.segmentIndex, 0);
      // Progress ~ half the total
      expect(r.progressMeters, closeTo(proj.totalLength / 2, 25)); // within 25m tolerance
      // Lateral offset ~ east ~ positive? depends on cross sign rule; verify magnitude only
      expect(r.lateralOffsetMeters.abs(), greaterThan(10));
      expect(r.lateralOffsetMeters.abs(), lessThan(40));
    });

    test('corner chooses nearer segment', () {
      final pts = [
        const LatLng(0.0, 0.0),
        const LatLng(0.01, 0.0), // north
        const LatLng(0.01, 0.01), // east
      ];
      final proj = SegmentProjector(pts);
      // Point near corner but slightly inside second segment direction
      final p = const LatLng(0.0102, 0.002);
      final r = proj.project(p);
      expect(r.segmentIndex, anyOf(0,1));
      // Progress should be >= first segment length (at corner) and < total
  expect(r.progressMeters, greaterThanOrEqualTo(proj.cumulativeDistances[1]));
      expect(r.progressMeters, lessThan(proj.totalLength));
    });

    test('beyond end clamps to total length', () {
      final pts = [
        const LatLng(0.0, 0.0),
        const LatLng(0.01, 0.0),
      ];
      final proj = SegmentProjector(pts);
      final p = const LatLng(0.02, 0.0); // beyond end north
      final r = proj.project(p);
      expect(r.progressMeters, closeTo(proj.totalLength, 1));
    });

    test('sharp turn chooses correct segment based on perpendicular distance', () {
      final pts = [
        const LatLng(0.0, 0.0),
        const LatLng(0.005, 0.0),
        const LatLng(0.005, 0.005),
        const LatLng(0.010, 0.005),
      ];
      final proj = SegmentProjector(pts);
      // Point near middle horizontal segment
      final p = const LatLng(0.0051, 0.003);
      final r = proj.project(p);
      // segment 1 is vertical (index 0), segment 2 is horizontal? Indices: 0:(0->1),1:(1->2),2:(2->3)
      expect(r.segmentIndex, anyOf(1,2));
  expect(r.progressMeters, greaterThan(proj.cumulativeDistances[1]));
    });

    test('single-point polyline', () {
      final pts = [const LatLng(1.0, 2.0)];
      final proj = SegmentProjector(pts);
      final r = proj.project(const LatLng(1.0005, 2.0005));
      expect(r.segmentIndex, -1);
      expect(r.progressMeters, 0);
      expect(r.lateralOffsetMeters, greaterThan(0));
    });

    test('empty polyline', () {
      final proj = SegmentProjector(const []);
      final r = proj.project(const LatLng(0,0));
      expect(r.segmentIndex, -1);
      expect(r.progressMeters, 0);
    });
  });

  group('Projection monotonicity / consistency', () {
    test('progress increases along path for sampled points', () {
      final pts = [
        const LatLng(0.0, 0.0),
        const LatLng(0.004, 0.0),
        const LatLng(0.004, 0.004),
        const LatLng(0.008, 0.004),
      ];
      final proj = SegmentProjector(pts);
      double last = -1;
      for (int i=0;i<20;i++) {
        // Interpolate along segments roughly
        double t = i / 19.0;
        // Map t to piecewise path: first half vertical, second half horizontal for simplicity
        LatLng p;
        if (t < 0.5) {
          double local = t / 0.5; // 0..1 along first two segments combined approximation
          p = LatLng(0.004*local, 0.0);
        } else {
          double local = (t-0.5)/0.5; // 0..1
          p = LatLng(0.004, 0.004*local);
        }
        final r = proj.project(p);
        expect(r.progressMeters, greaterThanOrEqualTo(last));
        last = r.progressMeters;
      }
    });
  });
}
