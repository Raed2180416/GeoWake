# SSL Certificate Pinning Configuration

## Overview
SSL certificate pinning has been implemented to enhance the security of API communications between the GeoWake app and the backend server. This prevents man-in-the-middle attacks by ensuring the app only accepts connections with specific, known certificates.

## Implementation Status
✅ **Infrastructure Complete**: SSL pinning code is fully implemented and ready to use
⚠️ **Pins Need Configuration**: Actual certificate pins need to be added before enabling in production

## How to Configure

### Step 1: Get the Certificate Pins
Run the provided script to extract the certificate pins from your server:

```bash
bash scripts/get_ssl_pins.sh
```

This will output the certificate pin in the correct format. You should see something like:

```
✓ Certificate Pin (Base64 SHA-256):
  ABC123XYZ456...==
```

### Step 2: Update the Configuration
Open `lib/config/ssl_pinning_config.dart` and replace the placeholder pins with the actual values:

```dart
return [
  CertificatePin(
    'geowake-production.up.railway.app',
    'ACTUAL_CERTIFICATE_HASH_HERE', // Replace with real pin
  ),
  // Recommended: Add a backup pin
  CertificatePin(
    'geowake-production.up.railway.app',
    'BACKUP_CERTIFICATE_HASH_HERE',
  ),
];
```

### Step 3: Test
1. Build the app in debug mode
2. Verify it can connect to the server
3. Test in release mode before deploying

## Important Notes

### Certificate Rotation
- Certificates typically expire every 90 days (Let's Encrypt)
- When the server certificate changes, you MUST update the pins
- Always maintain at least 2 pins (current + backup) to avoid breaking the app during rotation

### Development vs Production
- **Development**: Pinning is disabled to allow easier testing
- **Production**: Pinning is automatically enabled for security

### Security Best Practices
1. ✅ Never commit private keys to the repository
2. ✅ Always test certificate updates in staging first
3. ✅ Monitor certificate expiration dates
4. ✅ Have a backup certificate pin configured
5. ✅ Document all pin updates in version control

## Troubleshooting

### "Pin Mismatch" Errors
- The server certificate has changed
- Run `get_ssl_pins.sh` to get the new pin
- Update `ssl_pinning_config.dart` with the new pin
- Rebuild and test

### Connection Failures in Development
- Check that placeholder pins are not being used in production builds
- Verify the server is accessible
- Check network connectivity

## Architecture

```
main.dart
  └─> BootstrapService.start()
      └─> _lateInit()
          └─> SSL_PINNING step
              └─> ApiClient.configureCertificatePins()
                  └─> PinnedHttpClientFactory.create()
                      └─> All HTTPS requests are now pinned
```

## Files Modified
- `lib/config/ssl_pinning_config.dart` - Pin configuration
- `lib/services/bootstrap_service.dart` - Initialization
- `lib/services/ssl_pinning.dart` - Core implementation (already existed)
- `lib/services/api_client.dart` - Pin enforcement (already existed)
- `scripts/get_ssl_pins.sh` - Utility to extract pins

## Next Steps
1. **REQUIRED**: Configure actual certificate pins in `ssl_pinning_config.dart`
2. **REQUIRED**: Test thoroughly before production deployment
3. **RECOMMENDED**: Set up monitoring for certificate expiration
4. **RECOMMENDED**: Document certificate rotation procedures in your ops runbook
