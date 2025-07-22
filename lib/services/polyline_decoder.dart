import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Decodes an encoded polyline string into a list of [LatLng] coordinates.
/// Returns an empty list if the input is empty or an error occurs.
List<LatLng> decodePolyline(String encoded) {
  if (encoded.isEmpty) {
    return [];
  }
  List<LatLng> polyline = [];
  int index = 0;
  int len = encoded.length;
  int lat = 0;
  int lng = 0;

  try {
    while (index < len) {
      int shift = 0;
      int result = 0;
      int b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      polyline.add(LatLng(lat / 1E5, lng / 1E5));
    }
  } catch (e) {
    // Return the decoded points so far if an error occurs.
    return polyline;
  }
  return polyline;
}
