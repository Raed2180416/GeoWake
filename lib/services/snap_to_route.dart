import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math' show cos;
import 'package:geowake2/services/event_bus.dart';

class SnapResult {
  final LatLng snappedPoint;
  final double lateralOffsetMeters;
  final double progressMeters;
  final int segmentIndex;
  // Indicates the raw geometric best projection implied a backward progress regression
  // beyond the allowed tolerance and was clamped (potential loop / hairpin condition).
  final bool backtrackClamped;
  // Indicates input point appears to be a large jump relative to last known snapped point / progress.
  final bool teleportDetected;
  // Debug: raw best progress before any regression clamp.
  final double rawBestProgressMeters;
  // Debug: whether regression condition evaluated true (and thus clamped).
  final bool regressionTriggered;
  const SnapResult({
    required this.snappedPoint,
    required this.lateralOffsetMeters,
    required this.progressMeters,
    required this.segmentIndex,
    this.backtrackClamped = false,
    this.teleportDetected = false,
    this.rawBestProgressMeters = 0.0,
    this.regressionTriggered = false,
  });
}

class SnapToRouteEngine {
  /// Snap a point to a polyline. Optionally provide a hint segment index to reduce search.
  static SnapResult snap({
    required LatLng point,
    required List<LatLng> polyline,
    List<double>? precomputedCumMeters,
    int? hintIndex,
    int searchWindow = 20,
    double? lastProgress,
    double maxRegressionMeters = 25.0,
    LatLng? lastSnappedPoint,
    double teleportDistanceMeters = 180.0,
  }) {
    if (polyline.length < 2) {
      return SnapResult(
        snappedPoint: point,
        lateralOffsetMeters: double.infinity,
        progressMeters: 0,
        segmentIndex: 0,
        backtrackClamped: false,
        teleportDetected: false,
        rawBestProgressMeters: 0.0,
        regressionTriggered: false,
      );
    }

    int start = 0;
    int end = polyline.length - 2;
    if (hintIndex != null) {
      start = (hintIndex - searchWindow).clamp(0, end);
      end = (hintIndex + searchWindow).clamp(0, end);
    }

    double bestDist = double.infinity;
    LatLng bestPoint = polyline[0];
    int bestIdx = 0;
    double bestProgress = 0.0;

    // Use provided cumulative distances if available; otherwise compute locally
    final cum = precomputedCumMeters ?? (() {
      final c = List<double>.filled(polyline.length, 0.0);
      for (int i = 1; i < polyline.length; i++) {
        c[i] = c[i - 1] + _dist(polyline[i - 1], polyline[i]);
      }
      return c;
    })();

    for (int i = start; i <= end; i++) {
      final A = polyline[i];
      final B = polyline[i + 1];
      final proj = _projectPointOnSegment(point, A, B);
      final d = _dist(point, proj);
      if (d < bestDist) {
        bestDist = d;
        bestPoint = proj;
        bestIdx = i;
        bestProgress = cum[i] + _dist(A, proj);
      }
    }

    // Adaptive fallback: if using a hint and result is far (>250m), perform one full scan.
    if (hintIndex != null && bestDist > 250) {
      for (int i = 0; i < polyline.length - 1; i++) {
        final A = polyline[i];
        final B = polyline[i + 1];
        final proj = _projectPointOnSegment(point, A, B);
        final d = _dist(point, proj);
        if (d < bestDist) {
          bestDist = d;
          bestPoint = proj;
          bestIdx = i;
          bestProgress = cum[i] + _dist(A, proj);
        }
      }
    }

    // Teleport / jump detection: if last snapped point provided and raw distance from it is huge relative
    // to progress delta expectation (or simply > threshold), mark teleport. We do not alter progress directly here;
    // higher layers may choose to damp or ignore one frame.
    bool teleport = false;
    if (lastSnappedPoint != null) {
      final jump = _dist(lastSnappedPoint, point);
      if (jump > teleportDistanceMeters) {
        teleport = true;
        EventBus().emit(TeleportDetectedEvent(jump));
        // If we teleported a large distance but the best lateral offset is also huge, expand search once if we had hint.
        if (hintIndex != null && bestDist > 120) {
          // Perform exhaustive rescan (already done above for >250 case, but here lower threshold when teleporting).
          for (int i = 0; i < polyline.length - 1; i++) {
            final A = polyline[i];
            final B = polyline[i + 1];
            final proj = _projectPointOnSegment(point, A, B);
            final d = _dist(point, proj);
            if (d < bestDist) {
              bestDist = d;
              bestPoint = proj;
              bestIdx = i;
              bestProgress = cum[i] + _dist(A, proj);
            }
          }
        }
      }
    }

    // Forward progress gating: if previous progress provided and regression exceeds tolerance, clamp.
    var finalProgress = bestProgress;
    bool clamped = false;
    bool regression = false;
    if (lastProgress != null && finalProgress + maxRegressionMeters < lastProgress) {
      // Large regression: potential loop/hairpin or GPS jump across folded polyline.
      finalProgress = lastProgress; // do not allow large backward jump
      clamped = true;
      regression = true;
      EventBus().emit(BacktrackClampedEvent(lastProgress - bestProgress));
    }
    return SnapResult(
      snappedPoint: bestPoint,
      lateralOffsetMeters: bestDist,
      progressMeters: finalProgress,
      segmentIndex: bestIdx,
      backtrackClamped: clamped,
      teleportDetected: teleport,
      rawBestProgressMeters: bestProgress,
      regressionTriggered: regression,
    );
  }

  static double _dist(LatLng a, LatLng b) =>
      Geolocator.distanceBetween(a.latitude, a.longitude, b.latitude, b.longitude);

  /// Project point P onto segment AB, clamped to the segment endpoints.
  static LatLng _projectPointOnSegment(LatLng p, LatLng a, LatLng b) {
    // Convert to approximate meters using simple equirectangular projection around segment latitude.
    final latRad = ((a.latitude + b.latitude) * 0.5) * (3.141592653589793 / 180.0);
    final kx = 111320.0 * cos(latRad);
    const ky = 110540.0; // average meters per degree latitude

    final ax = a.longitude * kx;
    final ay = a.latitude * ky;
    final bx = b.longitude * kx;
    final by = b.latitude * ky;
    final px = p.longitude * kx;
    final py = p.latitude * ky;

    final vx = bx - ax;
    final vy = by - ay;
    final wx = px - ax;
    final wy = py - ay;
    final vv = vx * vx + vy * vy;
    double t = vv > 0 ? (wx * vx + wy * vy) / vv : 0.0;
    if (t < 0) t = 0; else if (t > 1) t = 1;

    final sx = ax + t * vx;
    final sy = ay + t * vy;
    final slon = sx / kx;
    final slat = sy / ky;
    return LatLng(slat, slon);
  }
}
