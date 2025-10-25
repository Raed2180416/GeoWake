/// route_asset_loader.dart: Source file from lib/lib/services/simulation/route_asset_loader.dart
/// 
/// This annotated version provides detailed documentation for all classes, methods, and fields.

import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// RouteAsset: Class for [brief description]
/// 
/// **Purpose**: [What this class does]
/// 
/// **Usage**: [How to use this class]
class RouteAsset {
  /// [Brief description of this field]
  final String name;
  /// [Brief description of this field]
  final List<LatLng> points;
  RouteAsset(this.name, this.points);
}

/// Loads a JSON asset of shape: { "name": string, "points": [ [lat,lng], ... ] }
class RouteAssetLoader {
  /// load: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  static Future<RouteAsset> load(String assetPath) async {
    /// loadString: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    final raw = await rootBundle.loadString(assetPath);
    /// jsonDecode: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    final json = jsonDecode(raw);
    /// [Brief description of this field]
    final name = json['name'] as String? ?? 'Unnamed Route';
    final ptsRaw = (json['points'] as List).cast<List>();
    /// [Brief description of this field]
    final pts = ptsRaw
        /// map: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        .map((p) => LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble()))
        /// toList: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        .toList(growable: false);
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (pts.length < 2) {
      throw StateError('Route must contain at least 2 points');
    }
    return RouteAsset(name, pts);
  }
}
