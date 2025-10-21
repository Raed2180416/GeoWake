import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:developer' as dev;

/// A widget that displays a banner when the device is offline.
/// Automatically monitors connectivity and shows/hides the banner accordingly.
class OfflineIndicator extends StatefulWidget {
  final Widget child;
  final Color? backgroundColor;
  final Color? textColor;
  final String? message;
  
  const OfflineIndicator({
    Key? key,
    required this.child,
    this.backgroundColor,
    this.textColor,
    this.message,
  }) : super(key: key);
  
  @override
  State<OfflineIndicator> createState() => _OfflineIndicatorState();
}

class _OfflineIndicatorState extends State<OfflineIndicator> {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isOnline = true;
  
  @override
  void initState() {
    super.initState();
    _checkInitialConnectivity();
    _listenToConnectivityChanges();
  }
  
  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
  
  /// Check initial connectivity status
  Future<void> _checkInitialConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      if (mounted) {
        setState(() {
          _isOnline = _hasConnectivity(results);
        });
      }
    } catch (e) {
      dev.log('Error checking initial connectivity: $e', name: 'OfflineIndicator');
    }
  }
  
  /// Listen to connectivity changes
  void _listenToConnectivityChanges() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (results) {
        if (mounted) {
          setState(() {
            _isOnline = _hasConnectivity(results);
          });
        }
      },
      onError: (e) {
        dev.log('Error in connectivity stream: $e', name: 'OfflineIndicator');
      },
    );
  }
  
  /// Check if any connectivity result indicates we're online
  bool _hasConnectivity(List<ConnectivityResult> results) {
    return results.any((result) => 
      result != ConnectivityResult.none
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Show offline banner when offline
        if (!_isOnline)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: widget.backgroundColor ?? Colors.red.shade700,
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  Icon(
                    Icons.wifi_off,
                    color: widget.textColor ?? Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.message ?? 'No internet connection',
                      style: TextStyle(
                        color: widget.textColor ?? Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        // Main content
        Expanded(child: widget.child),
      ],
    );
  }
}

/// A simple connectivity status widget that can be placed anywhere in the UI
class ConnectivityStatus extends StatefulWidget {
  final Color? onlineColor;
  final Color? offlineColor;
  final double size;
  
  const ConnectivityStatus({
    Key? key,
    this.onlineColor,
    this.offlineColor,
    this.size = 12,
  }) : super(key: key);
  
  @override
  State<ConnectivityStatus> createState() => _ConnectivityStatusState();
}

class _ConnectivityStatusState extends State<ConnectivityStatus> {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isOnline = true;
  
  @override
  void initState() {
    super.initState();
    _checkInitialConnectivity();
    _listenToConnectivityChanges();
  }
  
  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
  
  Future<void> _checkInitialConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      if (mounted) {
        setState(() {
          _isOnline = _hasConnectivity(results);
        });
      }
    } catch (e) {
      dev.log('Error checking initial connectivity: $e', name: 'ConnectivityStatus');
    }
  }
  
  void _listenToConnectivityChanges() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (results) {
        if (mounted) {
          setState(() {
            _isOnline = _hasConnectivity(results);
          });
        }
      },
      onError: (e) {
        dev.log('Error in connectivity stream: $e', name: 'ConnectivityStatus');
      },
    );
  }
  
  bool _hasConnectivity(List<ConnectivityResult> results) {
    return results.any((result) => 
      result != ConnectivityResult.none
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _isOnline 
          ? (widget.onlineColor ?? Colors.green)
          : (widget.offlineColor ?? Colors.red),
      ),
    );
  }
}

/// Service to check connectivity status without UI
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();
  
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isOnline = true;
  
  bool get isOnline => _isOnline;
  
  /// Start monitoring connectivity
  void startMonitoring() {
    _checkConnectivity();
    _subscription = _connectivity.onConnectivityChanged.listen(
      (results) {
        _isOnline = results.any((result) => result != ConnectivityResult.none);
        dev.log('Connectivity changed: ${_isOnline ? "online" : "offline"}', 
                name: 'ConnectivityService');
      },
      onError: (e) {
        dev.log('Connectivity monitoring error: $e', name: 'ConnectivityService');
      },
    );
  }
  
  /// Stop monitoring connectivity
  void stopMonitoring() {
    _subscription?.cancel();
    _subscription = null;
  }
  
  /// Check current connectivity status
  Future<bool> checkConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _isOnline = results.any((result) => result != ConnectivityResult.none);
      return _isOnline;
    } catch (e) {
      dev.log('Error checking connectivity: $e', name: 'ConnectivityService');
      return _isOnline; // Return last known state
    }
  }
  
  /// Get current connectivity result details
  Future<List<ConnectivityResult>> getConnectivityResults() async {
    try {
      return await _connectivity.checkConnectivity();
    } catch (e) {
      dev.log('Error getting connectivity results: $e', name: 'ConnectivityService');
      return [ConnectivityResult.none];
    }
  }
  
  Future<void> _checkConnectivity() async {
    await checkConnectivity();
  }
}
