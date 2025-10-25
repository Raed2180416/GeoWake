#!/bin/bash
# Script to get SSL certificate pins for the GeoWake backend server
# This script extracts the SHA-256 hash of the certificate's public key

SERVER="geowake-production.up.railway.app"
PORT="443"

echo "========================================="
echo "SSL Certificate Pin Retrieval Script"
echo "========================================="
echo ""
echo "Fetching certificate for: $SERVER:$PORT"
echo ""

# Method 1: Using openssl (most reliable)
echo "Method 1: Using OpenSSL"
echo "-----------------------"
PIN=$(openssl s_client -connect $SERVER:$PORT -showcerts </dev/null 2>/dev/null | \
      openssl x509 -outform DER 2>/dev/null | \
      openssl dgst -sha256 -binary | \
      openssl enc -base64)

if [ -n "$PIN" ]; then
    echo "✓ Certificate Pin (Base64 SHA-256):"
    echo "  $PIN"
    echo ""
    echo "Add this to lib/config/ssl_pinning_config.dart:"
    echo ""
    echo "  CertificatePin("
    echo "    '$SERVER',"
    echo "    '$PIN',"
    echo "  ),"
else
    echo "✗ Failed to retrieve certificate pin using openssl"
fi

echo ""
echo "========================================="
echo "IMPORTANT NOTES:"
echo "========================================="
echo "1. Certificate pins need to be updated when your server"
echo "   certificate changes (typically every 90 days for Let's Encrypt)"
echo ""
echo "2. It's recommended to pin BOTH:"
echo "   - The current certificate"
echo "   - A backup certificate"
echo ""
echo "3. Test thoroughly after updating pins to ensure the app"
echo "   can still connect to the server"
echo ""
echo "4. In production, ALWAYS enable SSL pinning for security"
echo "========================================="
