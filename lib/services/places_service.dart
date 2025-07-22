import 'dart:convert';
import 'package:http/http.dart' as http;

class PlacesService {
  final String apiKey;
  
  PlacesService({required this.apiKey});
  
  /// Fetches autocomplete suggestions from the Google Places API.
  /// If countryCode is provided, results will be biased towards that country.
  Future<List<Map<String, dynamic>>> fetchAutocompleteResults(
    String query, {
    String? countryCode,
    double? lat,
    double? lng,
  }) async {
    try {
      // Build the URL with optional country restriction and location bias
      String url = 'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$query&key=$apiKey';
      
      // Add country restriction if available
      if (countryCode != null && countryCode.isNotEmpty) {
        url += '&components=country:$countryCode';
      }
      
      // Add location bias if coordinates are available
      if (lat != null && lng != null) {
        url += '&location=$lat,$lng&radius=50000'; // 50km radius for biasing
      }
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['status'] == 'OK') {
          final predictions = jsonResponse['predictions'] as List<dynamic>;
          return predictions.map((item) {
            return {
              'description': item['description'],
              'place_id': item['place_id'],
              'isLocal': false,
            };
          }).toList();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }
  
  /// Fetches detailed information about a place from the Google Places API.
  Future<Map<String, dynamic>?> fetchPlaceDetails(String placeId) async {
    try {
      final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&key=$apiKey');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['status'] == 'OK') {
          final loc = jsonResponse['result']['geometry']['location'];
          return {
            'description': jsonResponse['result']['name'],
            'lat': loc['lat'],
            'lng': loc['lng'],
          };
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}