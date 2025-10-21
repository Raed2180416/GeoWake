import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geowake2/services/geometry/segment_projection.dart';

void main(){
  test('segment projector performance (non-strict)', () {
    final rnd = Random(7);
    // Build a moderately long polyline (~200 segments)
    final pts=<LatLng>[];
    double lat=37.0; double lng=-122.0;
    pts.add(LatLng(lat,lng));
    for(int i=0;i<220;i++){
      lat += (rnd.nextDouble()-0.5)*0.005; // small jitter ~few hundred meters
      lng += (rnd.nextDouble()-0.5)*0.005;
      pts.add(LatLng(lat,lng));
    }
    final projector = SegmentProjector(pts);
    final totalLen = projector.totalLength;
    expect(totalLen>0,true);
    final queries = 8000;
    final start = DateTime.now();
    double checksum=0; // avoid optimizer skipping
    for(int i=0;i<queries;i++){
      final t = rnd.nextDouble();
      final idx = (t*(pts.length-2)).floor();
      final a=pts[idx]; final b=pts[idx+1];
      final localT = rnd.nextDouble();
      final p = LatLng(a.latitude + (b.latitude-a.latitude)*localT + (rnd.nextDouble()-0.5)*0.0001,
                       a.longitude + (b.longitude-a.longitude)*localT + (rnd.nextDouble()-0.5)*0.0001);
      final res = projector.project(p);
      checksum += res.progressMeters;
    }
    final elapsed = DateTime.now().difference(start);
    // Soft expectation: should be comfortably under 400ms on typical dev machine; allow slack in CI.
    final ms = elapsed.inMilliseconds;
    // Don't fail if slower; just ensure not absurd.
    expect(ms < 1500, true, reason: 'Projection perf degraded: ${ms}ms for $queries queries totalLen=$totalLen checksum=$checksum');
  });
}
