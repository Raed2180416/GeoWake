import 'package:geolocator/geolocator.dart';
import 'dart:developer' as dev;

/// Validates GPS position data to prevent crashes from invalid coordinates.
/// Filters out NaN, infinity, "Null Island" (0,0), and low-accuracy positions.
class PositionValidator {
  // Minimum acceptable accuracy in meters (higher values = less accurate)
  static const double defaultMinAccuracy = 100.0;
  
  // Null Island coordinates (0, 0) - usually indicates GPS error
  static const double _nullIslandThreshold = 0.001;
  
  /// Validates a position and returns true if it's safe to use.
  /// 
  /// Checks performed:
  /// - Latitude/longitude are not NaN or infinite
  /// - Coordinates are within valid ranges (-90 to 90 for lat, -180 to 180 for lng)
  /// - Not at "Null Island" (0, 0) which indicates GPS error
  /// - Accuracy is acceptable (if minAccuracy is specified)
  /// - Speed is not NaN or negative
  /// 
  /// [position] - The GPS position to validate
  /// [minAccuracy] - Minimum acceptable accuracy in meters (optional)
  /// [allowMockLocation] - Whether to allow mock locations (default: false in production)
  static bool isValid(
    Position position, {
    double? minAccuracy,
    bool allowMockLocation = false,
  }) {
    try {
      // Check latitude
      if (!position.latitude.isFinite) {
        dev.log('Invalid position: latitude is not finite (${position.latitude})', 
                name: 'PositionValidator');
        return false;
      }
      
      if (position.latitude < -90 || position.latitude > 90) {
        dev.log('Invalid position: latitude out of range (${position.latitude})', 
                name: 'PositionValidator');
        return false;
      }
      
      // Check longitude
      if (!position.longitude.isFinite) {
        dev.log('Invalid position: longitude is not finite (${position.longitude})', 
                name: 'PositionValidator');
        return false;
      }
      
      if (position.longitude < -180 || position.longitude > 180) {
        dev.log('Invalid position: longitude out of range (${position.longitude})', 
                name: 'PositionValidator');
        return false;
      }
      
      // Check for "Null Island" (0, 0) - usually indicates GPS error
      if (position.latitude.abs() < _nullIslandThreshold && 
          position.longitude.abs() < _nullIslandThreshold) {
        dev.log('Invalid position: at Null Island (0, 0)', 
                name: 'PositionValidator');
        return false;
      }
      
      // Check accuracy if specified
      if (minAccuracy != null && position.accuracy.isFinite) {
        if (position.accuracy > minAccuracy) {
          dev.log('Invalid position: accuracy too low (${position.accuracy}m > ${minAccuracy}m)', 
                  name: 'PositionValidator');
          return false;
        }
      }
      
      // Check speed if available
      if (position.speed.isFinite && position.speed < 0) {
        dev.log('Invalid position: negative speed (${position.speed}m/s)', 
                name: 'PositionValidator');
        return false;
      }
      
      // Check for mock location (optional)
      if (!allowMockLocation && position.isMocked) {
        dev.log('Invalid position: mock location detected', 
                name: 'PositionValidator');
        return false;
      }
      
      return true;
    } catch (e) {
      dev.log('Error validating position: $e', name: 'PositionValidator');
      return false;
    }
  }
  
  /// Creates a detailed validation report for debugging.
  /// Returns a map with validation results and reasons for failure.
  static Map<String, dynamic> getValidationReport(Position position) {
    return {
      'timestamp': position.timestamp.toIso8601String(),
      'latitude': position.latitude,
      'longitude': position.longitude,
      'accuracy': position.accuracy,
      'speed': position.speed,
      'isMocked': position.isMocked,
      'checks': {
        'latitudeFinite': position.latitude.isFinite,
        'latitudeInRange': position.latitude >= -90 && position.latitude <= 90,
        'longitudeFinite': position.longitude.isFinite,
        'longitudeInRange': position.longitude >= -180 && position.longitude <= 180,
        'notNullIsland': !(position.latitude.abs() < _nullIslandThreshold && 
                          position.longitude.abs() < _nullIslandThreshold),
        'accuracyFinite': position.accuracy.isFinite,
        'speedValid': !position.speed.isFinite || position.speed >= 0,
        'notMocked': !position.isMocked,
      },
      'isValid': isValid(position),
    };
  }
  
  /// Sanitizes a position by clamping values to valid ranges.
  /// Only use this if you need to recover from slightly invalid data.
  /// Returns null if the position is fundamentally invalid (NaN, Infinity).
  static Position? sanitize(Position position) {
    try {
      // Can't fix NaN or Infinity
      if (!position.latitude.isFinite || !position.longitude.isFinite) {
        return null;
      }
      
      // Clamp latitude to valid range
      final lat = position.latitude.clamp(-90.0, 90.0);
      
      // Normalize longitude to -180 to 180 range
      var lng = position.longitude;
      while (lng > 180) lng -= 360;
      while (lng < -180) lng += 360;
      
      // Ensure speed is non-negative
      final speed = position.speed.isFinite && position.speed >= 0 
          ? position.speed 
          : 0.0;
      
      // Return sanitized position
      return Position(
        latitude: lat,
        longitude: lng,
        timestamp: position.timestamp,
        accuracy: position.accuracy,
        altitude: position.altitude,
        heading: position.heading,
        speed: speed,
        speedAccuracy: position.speedAccuracy,
        isMocked: position.isMocked,
        altitudeAccuracy: position.altitudeAccuracy,
        headingAccuracy: position.headingAccuracy,
      );
    } catch (e) {
      dev.log('Error sanitizing position: $e', name: 'PositionValidator');
      return null;
    }
  }
}
