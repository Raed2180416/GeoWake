import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geowake2/services/geometry/segment_projection.dart';

// Legacy fraction compute using cumulative distances vs. projector-based project() progress.

double _legacyProgressFraction(List<LatLng> pts, LatLng p) {
  if (pts.length < 2) return 0.0;
  // Find nearest segment via simple linear scan using geodesic distance to endpoints midpoint heuristic.
  double bestDist = double.infinity; double bestProgress = 0.0; double totalLen = 0.0;
  final cum = List<double>.filled(pts.length, 0.0);
  for (int i=1;i<pts.length;i++) {
    totalLen += _dist(pts[i-1], pts[i]);
    cum[i] = totalLen;
  }
  for (int i=0;i<pts.length-1;i++) {
    final a=pts[i]; final b=pts[i+1];
    final proj = _projectOnSegment(p,a,b);
    final d = _dist(p, proj);
    if (d < bestDist) {
      bestDist = d;
      bestProgress = cum[i] + _dist(a, proj);
    }
  }
  if (totalLen <= 0) return 0.0;
  return (bestProgress/totalLen).clamp(0.0,1.0);
}

LatLng _projectOnSegment(LatLng p, LatLng a, LatLng b){
  const ky=110540.0; const toRad=3.141592653589793/180.0;
  final latRad=((a.latitude+b.latitude)*0.5)*toRad; final kx=111320.0* (cos(latRad)).abs();
  final ax=a.longitude*kx; final ay=a.latitude*ky; final bx=b.longitude*kx; final by=b.latitude*ky; final px=p.longitude*kx; final py=p.latitude*ky;
  final vx=bx-ax; final vy=by-ay; final wx=px-ax; final wy=py-ay; final vv=vx*vx+vy*vy; double t= vv>0? (wx*vx+wy*vy)/vv:0; if(t<0)t=0; else if(t>1)t=1; final sx=ax+t*vx; final sy=ay+t*vy; return LatLng(sy/ky, sx/kx);
}

double _dist(LatLng a, LatLng b){
  // simple equirectangular approx (sufficient for parity relative comparison)
  const ky=110540.0; const toRad=3.141592653589793/180.0; final latMid=((a.latitude+b.latitude)/2)*toRad; final kx=111320.0*(cos(latMid)).abs();
  final dx=(b.longitude-a.longitude)*kx; final dy=(b.latitude-a.latitude)*ky; return sqrt(dx*dx+dy*dy);
}

void main(){
  test('projection vs legacy progress parity random polylines', () {
    final rnd = Random(42);
    const routes=60; const samplesPerRoute=25; const lateralJitter=25.0; // meters
    int checked=0; int withinTolerance=0; double worstFracDelta=0; double worstMeterDelta=0; LatLng? worstP; double? worstLegacy; double? worstProj; double totalLenSum=0;
    for(int r=0;r<routes;r++){
      final segs = 10 + rnd.nextInt(25); // 10-34 segments
      // Build a wandering polyline around a seed lat/lng
      double lat = 40 + rnd.nextDouble()*0.2; double lng = -74 + rnd.nextDouble()*0.2;
      final pts=<LatLng>[]; pts.add(LatLng(lat,lng));
      for(int i=0;i<segs;i++){
        lat += (rnd.nextDouble()-0.5)*0.01; // ~ up to ~1km shifts
        lng += (rnd.nextDouble()-0.5)*0.01;
        pts.add(LatLng(lat,lng));
      }
      final projector = SegmentProjector(pts);
      final totalLen = projector.totalLength; totalLenSum += totalLen;
      if(totalLen<=0) continue;
      for(int s=0;s<samplesPerRoute;s++){
        // choose a param t along total length
        final target = rnd.nextDouble()*totalLen;
        // find segment by cumulative search
        int seg=0; while(seg<projector.cumulativeDistances.length-1 && projector.cumulativeDistances[seg+1] < target){ seg++; }
        final segStart = projector.cumulativeDistances[seg];
        final segLen = (seg+1<projector.cumulativeDistances.length)? (projector.cumulativeDistances[seg+1]-segStart):0;
        double localT = segLen>0? (target-segStart)/segLen : 0;
        // interpolate on geodesic approximated linearly in lat/lng
        final a=pts[seg]; final b=pts[seg+1];
        double baseLat = a.latitude + (b.latitude-a.latitude)*localT;
        double baseLng = a.longitude + (b.longitude-a.longitude)*localT;
        // jitter laterally by small bearing rotation: approximate east-west / north-south shift
        final jitterR = rnd.nextDouble();
        final jitterMeters = (jitterR - 0.5)*2 * lateralJitter; // [-lateralJitter, +lateralJitter]
        // Convert jitter to lat offset only (simplify) ~1 deg lat = 110540 m
        final latOffset = jitterMeters / 110540.0;
        baseLat += latOffset;
        final p = LatLng(baseLat, baseLng);
        final projRes = projector.project(p);
        final projFrac = (totalLen>0)? (projRes.progressMeters/totalLen).clamp(0.0,1.0):0.0;
        final legacyFrac = _legacyProgressFraction(pts, p);
        final fracDelta = (projFrac - legacyFrac).abs();
        final meterDelta = (projRes.progressMeters - legacyFrac*totalLen).abs();
        checked++;
        final allowedFrac = 0.01; // 1%
        final allowedMeters = 5.0; // or 5m
        if(fracDelta <= allowedFrac || meterDelta <= allowedMeters){ withinTolerance++; }
        if(fracDelta > worstFracDelta){ worstFracDelta = fracDelta; worstMeterDelta = meterDelta; worstP = p; worstLegacy = legacyFrac; worstProj = projFrac; }
      }
    }
    final pct = withinTolerance / checked * 100.0;
    expect(pct > 95.0, true, reason: 'Progress parity below expectation: within=$pct% worstFrac=$worstFracDelta worstMeter=$worstMeterDelta point=$worstP legacy=$worstLegacy proj=$worstProj');
    // Basic sanity: total length sum must be positive
    expect(totalLenSum>0, true);
  });
}
