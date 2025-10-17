import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_maps_flutter/google_maps_flutter.dart';

class RouteAsset {
  final String name;
  final List<LatLng> points;
  RouteAsset(this.name, this.points);
}

/// Loads a JSON asset of shape: { "name": string, "points": [ [lat,lng], ... ] }
class RouteAssetLoader {
  static Future<RouteAsset> load(String assetPath) async {
    final raw = await rootBundle.loadString(assetPath);
    final json = jsonDecode(raw);
    final name = json['name'] as String? ?? 'Unnamed Route';
    final ptsRaw = (json['points'] as List).cast<List>();
    final pts = ptsRaw
        .map((p) => LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble()))
        .toList(growable: false);
    if (pts.length < 2) {
      throw StateError('Route must contain at least 2 points');
    }
    return RouteAsset(name, pts);
  }
}
