/// segment_projection.dart: Source file from lib/lib/services/geometry/segment_projection.dart
/// 
/// This annotated version provides detailed documentation for all classes, methods, and fields.

import 'dart:math';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as geo;

/// Result of projecting a point onto a polyline.
class ProjectionResult {
  /// Total progress along the polyline in meters (clamped to [0,totalLength]).
  final double progressMeters;
  /// Signed lateral offset in meters: positive means point is to the 'left' of the segment
  /// according to segment direction (using simple cross-product sign in lat/lng plane).
  final double lateralOffsetMeters;
  /// Index of segment chosen (segment is between polyline[i] and polyline[i+1]). -1 if empty polyline.
  final int segmentIndex;

  const ProjectionResult({required this.progressMeters, required this.lateralOffsetMeters, required this.segmentIndex});
}

/// Utility to pre-compute cumulative distances and project a location (LatLng) onto a polyline.
/// This is intentionally lightweight; we reuse Geolocator.distanceBetween for earth curvature handling.
class SegmentProjector {
  /// [Brief description of this field]
  final List<LatLng> polyline;
  /// i: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  final List<double> cumulative; // cumulative[i] = distance from start to point i (meters)
  /// [Brief description of this field]
  final double totalLength;

  /// _: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  SegmentProjector._(this.polyline, this.cumulative, this.totalLength);

  /// Build a projector. Accepts an empty or single-point polyline gracefully.
  factory SegmentProjector(List<LatLng> points) {
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (points.isEmpty) {
      /// _: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      return SegmentProjector._(const [], const [], 0);
    }
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (points.length == 1) {
      /// _: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      return SegmentProjector._(List.unmodifiable(points), const [0], 0);
    }
    /// [Brief description of this field]
    final cum = <double>[0];
    double running = 0;
    /// for: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    for (int i = 1; i < points.length; i++) {
      /// distanceBetween: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      running += geo.Geolocator.distanceBetween(
        points[i-1].latitude, points[i-1].longitude,
        points[i].latitude, points[i].longitude,
      );
      /// add: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      cum.add(running);
    }
    /// _: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    return SegmentProjector._(List.unmodifiable(points), List.unmodifiable(cum), running);
  }

  /// Expose an immutable view of cumulative distances for tests / diagnostics.
  List<double> get cumulativeDistances => cumulative;

  /// Project [p] onto the polyline, returning progress and lateral offset.
  ProjectionResult project(LatLng p) {
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (polyline.isEmpty) return const ProjectionResult(progressMeters: 0, lateralOffsetMeters: 0, segmentIndex: -1);
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (polyline.length == 1) {
      /// distanceBetween: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      final d = geo.Geolocator.distanceBetween(polyline[0].latitude, polyline[0].longitude, p.latitude, p.longitude);
      return ProjectionResult(progressMeters: 0, lateralOffsetMeters: d, segmentIndex: -1); // offset only informational here
    }

    double bestDist2 = double.infinity; // squared distance in pseudo-meters using local planar approximation
    double bestProgress = 0;
    double bestLateral = 0;
    int bestSeg = 0;

    // We'll approximate local planar coordinates by converting lat/lng deltas to meters using a scale at the segment.
    // For each segment AB, we:
    // 1. Convert to local (x,y) meters using equirectangular approximation.
    // 2. Project point P onto AB, clamp t.
    // 3. Compute perpendicular distance & signed cross for lateral sign.
    /// for: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    for (int i = 0; i < polyline.length - 1; i++) {
      /// [Brief description of this field]
      final a = polyline[i];
      /// [Brief description of this field]
      final b = polyline[i+1];
      /// [Brief description of this field]
      final latScale = _metersPerDegreeLat;
      /// _metersPerDegreeLon: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      final lonScale = _metersPerDegreeLon((a.latitude + b.latitude) * 0.5);

      double ax = a.longitude * lonScale;
      double ay = a.latitude * latScale;
      double bx = b.longitude * lonScale;
      double by = b.latitude * latScale;
      double px = p.longitude * lonScale;
      double py = p.latitude * latScale;

      double vx = bx - ax;
      double vy = by - ay;
      double wx = px - ax;
      double wy = py - ay;

      double segLen2 = vx*vx + vy*vy;
      /// if: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      if (segLen2 == 0) continue; // degenerate
      double t = (wx*vx + wy*vy) / segLen2;
      /// if: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      if (t < 0) t = 0; else if (t > 1) t = 1;

      double cx = ax + t*vx;
      double cy = ay + t*vy;
      double dx = px - cx;
      double dy = py - cy;
      double dist2 = dx*dx + dy*dy;
      /// if: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      if (dist2 < bestDist2) {
        bestDist2 = dist2;
        // progress = cumulative[i] + segmentLength * t
        /// distanceBetween: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        final segMeters = geo.Geolocator.distanceBetween(a.latitude, a.longitude, b.latitude, b.longitude);
        bestProgress = cumulative[i] + segMeters * t;
        // lateral sign via cross (v x w) using planar vectors; magnitude approximate meters via sqrt(dist2)
        double cross = vx*wy - vy*wx; // sign only
        /// sqrt: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        bestLateral = sqrt(dist2) * (cross >= 0 ? 1 : -1);
        bestSeg = i;
      }
    }

    // Clamp progress defensively
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (bestProgress < 0) bestProgress = 0; else if (bestProgress > totalLength) bestProgress = totalLength;
    return ProjectionResult(progressMeters: bestProgress, lateralOffsetMeters: bestLateral, segmentIndex: bestSeg);
  }

  /// [Brief description of this field]
  static const double _metersPerDegreeLat = 111320.0; // average
  /// _metersPerDegreeLon: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  static double _metersPerDegreeLon(double latDeg) {
    /// [Brief description of this field]
    final rad = latDeg * pi / 180.0;
    /// cos: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    return 111320.0 * cos(rad).abs();
  }
}
