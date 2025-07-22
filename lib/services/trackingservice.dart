// lib/services/trackingservice.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:battery_plus/battery_plus.dart';
import 'dart:developer' as dev;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geowake2/services/deviation_detection.dart';
import 'package:geowake2/services/route_queue.dart';
import 'package:geowake2/services/sensor_fusion.dart';
import 'package:meta/meta.dart';
import 'package:sensors_plus/sensors_plus.dart';

// For testing: optionally override the GPS stream.
Stream<Position>? testGpsStream;
// For testing: optionally override the accelerometer stream.
@visibleForTesting
Stream<AccelerometerEvent>? testAccelerometerStream;

// Overridable GPS dropout buffer (default 25 seconds, can be lowered in tests).
@visibleForTesting
Duration gpsDropoutBuffer = Duration(seconds: 25);

// Test implementation for ServiceInstance to use in test mode.
class TestServiceInstance implements ServiceInstance {
  final _eventControllers = <String, StreamController<Map<String, dynamic>?>>{};

  @override
  void invoke(String method, [Map<String, dynamic>? args]) {
    dev.log("Test service invoke: $method, args: $args", name: "TestService");
  }

  @override
  Future<void> stopSelf() async {
    dev.log("Test service stopped", name: "TestService");
  }

  @override
  Stream<Map<String, dynamic>?> on(String event) {
    _eventControllers.putIfAbsent(
        event, () => StreamController<Map<String, dynamic>?>.broadcast());
    return _eventControllers[event]!.stream;
  }

  void dispose() {
    for (var controller in _eventControllers.values) {
      controller.close();
    }
    _eventControllers.clear();
  }
}

class TrackingService {
  static bool isTestMode = false; // Set to true in tests.
  static final TrackingService _instance = TrackingService._internal();
  factory TrackingService() => _instance;
  TrackingService._internal();

  Future<void> initializeService() async {
    if (!isTestMode) {
      final service = FlutterBackgroundService();
      try {
        await service.configure(
          androidConfiguration: AndroidConfiguration(
            onStart: _onStart,
            isForegroundMode: true,
            autoStart: false,
            notificationChannelId: 'geowake_tracking_channel',
            initialNotificationTitle: 'GeoWake Tracking',
            initialNotificationContent: 'Initializing...',
            foregroundServiceNotificationId: 888,
          ),
          iosConfiguration: IosConfiguration(
            autoStart: false,
            onForeground: _onStart,
            onBackground: onIosBackground,
          ),
        );
      } catch (e) {
        dev.log("Background service setup skipped in test mode: $e", name: "TrackingService");
      }
    }
  }

  Future<void> startTracking() async {
    if (isTestMode) {
      // In test mode, bypass background service calls.
      _onStart(TestServiceInstance());
      return;
    }
    final service = FlutterBackgroundService();
    try {
      if (!await service.isRunning()) {
        await service.startService();
      }
    } catch (e) {
      if (!isTestMode) rethrow;
    }
    service.invoke("startTracking");
  }

  Future<void> stopTracking() async {
    if (isTestMode) {
      _onStop();
      return;
    }
    final service = FlutterBackgroundService();
    service.invoke("stopTracking");
    if (await service.isRunning()) {
      service.invoke("stopService");
    }
  }

  // Public getter for tests to check sensor fusion status.
  @visibleForTesting
  bool get fusionActive => _fusionActive;
}

@pragma('vm:entry-point')
bool onIosBackground(ServiceInstance service) {
  WidgetsFlutterBinding.ensureInitialized();
  return true;
}

// Global variables.
double? _initialETA;
StreamSubscription<Position>? positionSubscription;
DateTime? _lastGpsUpdate;
SensorFusionManager? _sensorFusionManager;
Timer? _gpsCheckTimer;
LatLng? lastProcessedPosition; // Updated by the position stream.
double? _smoothedETA;
bool _fusionActive = false;

@pragma('vm:entry-point')
void _onStop() {
  positionSubscription?.cancel();
  positionSubscription = null;
  _gpsCheckTimer?.cancel();
  _gpsCheckTimer = null;
  if (_sensorFusionManager != null) {
    _sensorFusionManager!.stopFusion();
    _sensorFusionManager!.dispose();
    _sensorFusionManager = null;
  }
  _fusionActive = false;
}

@pragma('vm:entry-point')
void _onStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();

  if (service is! TestServiceInstance && !TrackingService.isTestMode) {
    service.on('stopService').listen((event) {
      service.stopSelf();
    });
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: "GeoWake Tracking",
        content: "Tracking is active",
      );
    }
  }

  service.on("updateRouteData").listen((event) {
    if (event != null && event.containsKey("initialETA")) {
      _initialETA = (event["initialETA"] as num).toDouble();
      service.invoke("logMessage", {"message": "Initial ETA updated to $_initialETA seconds"});
    }
  });

  // Use a shorter timer interval in test mode.
  final timerInterval = TrackingService.isTestMode ? Duration(seconds: 1) : Duration(seconds: 5);
  _gpsCheckTimer = Timer.periodic(timerInterval, (timer) {
    if (_lastGpsUpdate != null) {
      final elapsed = DateTime.now().difference(_lastGpsUpdate!);
      if (elapsed > gpsDropoutBuffer) {
        dev.log("GPS offline detected after ${elapsed.inSeconds} seconds. Activating sensor fusion.", name: "TrackingService");
        if (_sensorFusionManager == null && lastProcessedPosition != null) {
          _sensorFusionManager = SensorFusionManager(
            initialPosition: lastProcessedPosition!,
            accelerometerStream: testAccelerometerStream, // Use test stream if available.
          );
          _sensorFusionManager!.startFusion();
          _fusionActive = true;
          _sensorFusionManager!.fusedPositionStream.listen((fusedPos) {
            dev.log("Fused position update: (${fusedPos.latitude}, ${fusedPos.longitude})", name: "TrackingService");
            service.invoke("updateLocation", {
              "latitude": fusedPos.latitude,
              "longitude": fusedPos.longitude,
              "timestamp": DateTime.now().toIso8601String(),
              "eta": _smoothedETA
            });
          });
        }
      }
    }
  });

  Future<void> startLocationStream() async {
    final Battery battery = Battery();
    int batteryLevel = 100;
    try {
      batteryLevel = await battery.batteryLevel;
    } catch (e) {
      service.invoke("logMessage", {"message": "Error reading battery level: $e"});
    }

    LocationSettings settings;
    if (batteryLevel > 30) {
      settings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 50,
        timeLimit: Duration(seconds: 20),
      );
    } else {
      settings = const LocationSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: 100,
        timeLimit: Duration(seconds: 30),
      );
    }

    await positionSubscription?.cancel();
    final Stream<Position> stream = testGpsStream ?? Geolocator.getPositionStream(locationSettings: settings);
    positionSubscription = stream.listen((Position position) {
      try {
        _lastGpsUpdate = DateTime.now();
        lastProcessedPosition = LatLng(position.latitude, position.longitude);

        if (_sensorFusionManager != null) {
          dev.log("GPS resumed. Stopping sensor fusion.", name: "TrackingService");
          _sensorFusionManager!.stopFusion();
          _sensorFusionManager!.dispose();
          _sensorFusionManager = null;
          _fusionActive = false;
        }

        dev.log("GPS update processed: ${position.latitude}, ${position.longitude}", name: "TrackingService");

        double expectedAverageSpeed = 10.0;
        double currentSpeed = position.speed > 0 ? position.speed : expectedAverageSpeed;
        double computedETA = _initialETA != null ? _initialETA! * (expectedAverageSpeed / currentSpeed) : 0.0;
        double alpha = 0.5;
        if (_smoothedETA == null) {
          _smoothedETA = computedETA;
        } else {
          _smoothedETA = alpha * computedETA + (1 - alpha) * _smoothedETA!;
        }
        dev.log("Computed ETA: $computedETA seconds, Smoothed ETA: $_smoothedETA", name: "TrackingService");

        var activeRoute = RouteQueue.instance.getActiveRoute();
        if (activeRoute != null) {
          bool deviated = isDeviationExceeded(
            LatLng(position.latitude, position.longitude),
            activeRoute,
            false,
          );
          if (deviated) {
            dev.log("Deviation detected: User is off the active route", name: "TrackingService");
            service.invoke("deviationDetected", {"message": "User off route detected"});
          }
        }

        if (_initialETA != null && _smoothedETA != null && _smoothedETA! > 10 * _initialETA!) {
          dev.log("Long delay detected. Stopping tracking.", name: "TrackingService");
          positionSubscription?.cancel();
          positionSubscription = null;
          service.invoke("stopTracking");
        }

        service.invoke("updateLocation", {
          "latitude": position.latitude,
          "longitude": position.longitude,
          "timestamp": DateTime.now().toIso8601String(),
          "eta": _smoothedETA
        });
      } catch (e) {
        service.invoke("logMessage", {"message": "Error in GPS stream: $e"});
      }
    });
  }

  service.on("startTracking").listen((event) async {
    service.invoke("logMessage", {"message": "Received startTracking command."});
    await startLocationStream();
  });

  // Immediately start location stream in test mode.
  if (TrackingService.isTestMode) {
    await startLocationStream();
  }

  service.on("stopTracking").listen((event) async {
    service.invoke("logMessage", {"message": "Received stopTracking command."});
    await positionSubscription?.cancel();
    positionSubscription = null;
    _gpsCheckTimer?.cancel();
    _gpsCheckTimer = null;
    if (_sensorFusionManager != null) {
      _sensorFusionManager!.stopFusion();
      _sensorFusionManager!.dispose();
      _sensorFusionManager = null;
      _fusionActive = false;
    }
  });
}

// Expose testing getters.
@visibleForTesting
DateTime? get lastGpsUpdateValue => _lastGpsUpdate;
@visibleForTesting
LatLng? get lastValidPosition => lastProcessedPosition;
@visibleForTesting
bool get fusionActive => _fusionActive;
