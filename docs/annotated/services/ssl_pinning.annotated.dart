/// ssl_pinning.dart: Source file from lib/lib/services/ssl_pinning.dart
/// 
/// This annotated version provides detailed documentation for all classes, methods, and fields.

import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/io_client.dart' show IOClient; // explicit import
import 'package:http/http.dart' as http;

/// Represents a single pin (base64 SHA256 of SPKI / public key bytes)
class CertificatePin {
  /// [Brief description of this field]
  final String host; // hostname
  /// [Brief description of this field]
  final String sha256Base64; // expected hash
  CertificatePin(this.host, this.sha256Base64);
}

/// Verifier interface to allow test injection.
abstract class CertificatePinVerifier {
  /// verify: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  bool verify(String host, X509Certificate cert);
}

/// DefaultCertificatePinVerifier: Class for [brief description]
/// 
/// **Purpose**: [What this class does]
/// 
/// **Usage**: [How to use this class]
class DefaultCertificatePinVerifier implements CertificatePinVerifier {
  /// [Brief description of this field]
  final List<CertificatePin> pins;
  /// [Brief description of this field]
  final bool allowBypassInDebug;
  DefaultCertificatePinVerifier(this.pins, {this.allowBypassInDebug = true});

  @override
  /// verify: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  bool verify(String host, X509Certificate cert) {
    /// where: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    final candidates = pins.where((p) => p.host == host).toList();
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (candidates.isEmpty) {
      // no pins configured for host -> allow (fail-open for non pinned hosts)
      return true;
    }
    try {
      // Use DER encoded certificate -> extract public key portion (subjectPublicKeyInfo) heuristically.
      // Dart does not expose SPKI directly; as an approximation hash full DER cert.
      // Provide extensibility if future parsing added.
      /// [Brief description of this field]
      final der = cert.der;
      /// encode: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      final hash = base64.encode(sha256.convert(der).bytes);
      /// for: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      for (final p in candidates) {
        /// if: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        if (p.sha256Base64 == hash) return true;
      }
      return false;
    /// catch: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    } catch (_) {
      return false;
    }
  }
}

/// HttpOverrides that enforces certificate/public key pinning.
abstract class PinEnforcer {
  /// ensure: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Future<void> ensure(String host, int port, {bool https = true});
}

/// TlsPinEnforcer: Class for [brief description]
/// 
/// **Purpose**: [What this class does]
/// 
/// **Usage**: [How to use this class]
class TlsPinEnforcer implements PinEnforcer {
  /// [Brief description of this field]
  final CertificatePinVerifier verifier;
  /// [Brief description of this field]
  final Map<String,bool> _cache = {};
  TlsPinEnforcer(this.verifier);
  @override
  /// ensure: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Future<void> ensure(String host, int port, {bool https = true}) async {
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (_cache.containsKey(host)) return;
    final targetPort = port == 0 ? (https ? 443 : 80) : port;
    /// connect: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    final socket = await SecureSocket.connect(host, targetPort, onBadCertificate: (c) => false);
    /// [Brief description of this field]
    final cert = socket.peerCertificate;
    /// verify: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    final ok = cert != null ? verifier.verify(host, cert) : false;
    /// destroy: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    socket.destroy();
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (!ok) {
      throw PinMismatchException(host);
    }
    _cache[host] = true;
  }
}

/// PinMismatchException: Class for [brief description]
/// 
/// **Purpose**: [What this class does]
/// 
/// **Usage**: [How to use this class]
class PinMismatchException implements Exception {
  /// [Brief description of this field]
  final String host;
  PinMismatchException(this.host);
  @override
  /// toString: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  String toString() => 'PinMismatchException: host=$host';
}

/// PinnedHttpClient: Class for [brief description]
/// 
/// **Purpose**: [What this class does]
/// 
/// **Usage**: [How to use this class]
class PinnedHttpClient extends http.BaseClient {
  /// [Brief description of this field]
  final http.Client _inner;
  /// [Brief description of this field]
  final PinEnforcer enforcer;
  /// [Brief description of this field]
  final bool enabled;
  PinnedHttpClient(this._inner, {required this.enforcer, this.enabled = true});
  @override
  /// send: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (enabled && request.url.scheme == 'https') {
      /// ensure: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      await enforcer.ensure(request.url.host, request.url.port, https: true);
    }
    /// send: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    return _inner.send(request);
  }
}

/// PinnedHttpClientFactory: Class for [brief description]
/// 
/// **Purpose**: [What this class does]
/// 
/// **Usage**: [How to use this class]
class PinnedHttpClientFactory {
  /// create: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  static http.Client create({required CertificatePinVerifier verifier, bool enabled = true, PinEnforcer Function(CertificatePinVerifier v)? enforcerBuilder}) {
    final base = HttpClient();
    final inner = IOClient(base);
    /// enforcerBuilder: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    final enforcer = enforcerBuilder != null ? enforcerBuilder(verifier) : TlsPinEnforcer(verifier);
    return PinnedHttpClient(inner, enforcer: enforcer, enabled: enabled);
  }
}
