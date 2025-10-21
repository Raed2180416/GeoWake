import 'package:geowake2/services/ssl_pinning.dart';
import 'package:flutter/foundation.dart';

/// SSL certificate pins for the GeoWake backend server.
/// These pins should be updated when the server certificate changes.
/// 
/// To get the certificate pin for your server:
/// 1. Run: openssl s_client -connect geowake-production.up.railway.app:443 -showcerts </dev/null 2>/dev/null | openssl x509 -outform DER | openssl dgst -sha256 -binary | openssl enc -base64
/// 2. Add the resulting base64 hash below
/// 
/// IMPORTANT: You should pin both the current certificate AND a backup certificate
/// to avoid breaking the app if the certificate rotates.
class SSLPinningConfig {
  /// Get the configured pins for the application
  static List<CertificatePin> get pins {
    // In debug/development, we can optionally disable pinning or use test pins
    if (kDebugMode) {
      // For now, return empty to allow development without strict pinning
      // In production builds, this will always enforce pinning
      return [];
    }
    
    // Production pins - THESE NEED TO BE CONFIGURED WITH ACTUAL CERTIFICATE HASHES
    // The hashes below are placeholders and should be replaced with actual values
    return [
      CertificatePin(
        'geowake-production.up.railway.app',
        'PLACEHOLDER_CERTIFICATE_HASH_1', // Replace with actual certificate pin
      ),
      // It's recommended to also pin a backup certificate
      // CertificatePin(
      //   'geowake-production.up.railway.app',
      //   'PLACEHOLDER_BACKUP_CERTIFICATE_HASH',
      // ),
    ];
  }
  
  /// Whether SSL pinning should be enforced
  /// In production, this should always be true
  /// In development, it can be disabled for easier testing
  static bool get enabled {
    // Always enable in release mode for security
    if (kReleaseMode) {
      return true;
    }
    
    // In debug mode, only enable if we have valid pins configured
    // This prevents breaking development when pins are not yet configured
    final configuredPins = pins;
    return configuredPins.isNotEmpty && 
           !configuredPins.any((pin) => pin.sha256Base64.contains('PLACEHOLDER'));
  }
}
