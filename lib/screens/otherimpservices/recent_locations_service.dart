import 'package:hive_flutter/hive_flutter.dart';

class RecentLocationsService {
  static const String boxName = 'recent_locations';

  // Retrieve stored recent locations (defaults to empty list).
  static Future<List<dynamic>> getRecentLocations() async {
    final box = Hive.box(boxName);
    final stored = box.get('locations', defaultValue: []);
    return stored as List<dynamic>;
  }

  // Persist the list of recent locations.
  static Future<void> saveRecentLocations(List<dynamic> locations) async {
    final box = Hive.box(boxName);
    await box.put('locations', locations);
    box.get('locations');
  }
}
