import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/io_client.dart' show IOClient; // explicit import
import 'package:http/http.dart' as http;

/// Represents a single pin (base64 SHA256 of SPKI / public key bytes)
class CertificatePin {
  final String host; // hostname
  final String sha256Base64; // expected hash
  CertificatePin(this.host, this.sha256Base64);
}

/// Verifier interface to allow test injection.
abstract class CertificatePinVerifier {
  bool verify(String host, X509Certificate cert);
}

class DefaultCertificatePinVerifier implements CertificatePinVerifier {
  final List<CertificatePin> pins;
  final bool allowBypassInDebug;
  DefaultCertificatePinVerifier(this.pins, {this.allowBypassInDebug = true});

  @override
  bool verify(String host, X509Certificate cert) {
    final candidates = pins.where((p) => p.host == host).toList();
    if (candidates.isEmpty) {
      // no pins configured for host -> allow (fail-open for non pinned hosts)
      return true;
    }
    try {
      // Use DER encoded certificate -> extract public key portion (subjectPublicKeyInfo) heuristically.
      // Dart does not expose SPKI directly; as an approximation hash full DER cert.
      // Provide extensibility if future parsing added.
      final der = cert.der;
      final hash = base64.encode(sha256.convert(der).bytes);
      for (final p in candidates) {
        if (p.sha256Base64 == hash) return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}

/// HttpOverrides that enforces certificate/public key pinning.
abstract class PinEnforcer {
  Future<void> ensure(String host, int port, {bool https = true});
}

class TlsPinEnforcer implements PinEnforcer {
  final CertificatePinVerifier verifier;
  final Map<String,bool> _cache = {};
  TlsPinEnforcer(this.verifier);
  @override
  Future<void> ensure(String host, int port, {bool https = true}) async {
    if (_cache.containsKey(host)) return;
    final targetPort = port == 0 ? (https ? 443 : 80) : port;
    final socket = await SecureSocket.connect(host, targetPort, onBadCertificate: (c) => false);
    final cert = socket.peerCertificate;
    final ok = cert != null ? verifier.verify(host, cert) : false;
    socket.destroy();
    if (!ok) {
      throw PinMismatchException(host);
    }
    _cache[host] = true;
  }
}

class PinMismatchException implements Exception {
  final String host;
  PinMismatchException(this.host);
  @override
  String toString() => 'PinMismatchException: host=$host';
}

class PinnedHttpClient extends http.BaseClient {
  final http.Client _inner;
  final PinEnforcer enforcer;
  final bool enabled;
  PinnedHttpClient(this._inner, {required this.enforcer, this.enabled = true});
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (enabled && request.url.scheme == 'https') {
      await enforcer.ensure(request.url.host, request.url.port, https: true);
    }
    return _inner.send(request);
  }
}

class PinnedHttpClientFactory {
  static http.Client create({required CertificatePinVerifier verifier, bool enabled = true, PinEnforcer Function(CertificatePinVerifier v)? enforcerBuilder}) {
    final base = HttpClient();
    final inner = IOClient(base);
    final enforcer = enforcerBuilder != null ? enforcerBuilder(verifier) : TlsPinEnforcer(verifier);
    return PinnedHttpClient(inner, enforcer: enforcer, enabled: enabled);
  }
}
