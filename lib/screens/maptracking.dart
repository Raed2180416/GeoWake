import 'dart:async';
import 'dart:math';
import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geowake2/services/polyline_decoder.dart';
import 'package:geowake2/services/direction_service.dart';
import 'package:geowake2/services/polyline_simplifier.dart';
import 'package:geolocator/geolocator.dart';
import 'settingsdrawer.dart';
import 'package:geowake2/services/snap_to_route.dart';
import 'package:geowake2/services/trackingservice.dart';
import 'package:geowake2/config/alarm_thresholds.dart';
import 'package:geowake2/services/movement_classifier.dart';
import 'package:geowake2/services/active_route_manager.dart';
import 'package:geowake2/services/transfer_utils.dart';
import 'package:geowake2/widgets/pulsing_dots.dart';
import 'package:geowake2/services/eta_utils.dart';
import 'package:geowake2/services/alarm_player.dart';
import 'package:geowake2/services/notification_service.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geowake2/services/persistence/tracking_session_state.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class MapTrackingScreen extends StatefulWidget {
  MapTrackingScreen({Key? key}) : super(key: key);
  @override
  State<MapTrackingScreen> createState() => _MapTrackingScreenState();
}

class _MapTrackingScreenState extends State<MapTrackingScreen> {
  final Completer<GoogleMapController> _mapController = Completer();
  bool _isLoading = true;
  double? _destinationLat;
  double? _destinationLng;
  String? _destinationName;
  bool _metroMode = false;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  String _etaText = "Calculating ETA...";
  String _distanceText = "Calculating distance...";
  String? _switchNotice;
  bool _hasValidArgs = false;

  Map<String, dynamic>? directions;

  // StreamSubscription to update the current location marker.
  StreamSubscription<Position>? _locationSubscription;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  LatLng? _currentUserLocation;
  List<LatLng> _routePoints = const [];
  bool _isOnline = true;
  int? _lastSnapIndex;
  StreamSubscription<RouteSwitchEvent>? _routeSwitchSub;
  StreamSubscription<ActiveRouteState>? _routeStateSub;
  double _routeLengthMeters = 0.0;
  double? _speedEmaMps; // simple smoothed speed estimate
  final MovementClassifier _uiMovementClassifier = MovementClassifier();
  final List<double> _transferBoundariesMeters = [];
  final List<double> _stepBoundariesMeters = [];
  final List<double> _stepDurationsSeconds = [];

  Future<void> _initFromSessionLazy() async {
    try {
      final session = await TrackingSessionStateFile.load();
      if (session == null) {
        dev.log('MapTrackingScreen: lazy session load failed (null)', name: 'MapTrackingScreen');
        return;
      }
      _destinationLat = (session['destinationLat'] as num?)?.toDouble();
      _destinationLng = (session['destinationLng'] as num?)?.toDouble();
      _destinationName = session['destinationName'] as String? ?? 'Destination';
      _metroMode = (session['alarmMode'] == 'stops');
      if (_destinationLat == null || _destinationLng == null) {
        dev.log('MapTrackingScreen: lazy session missing lat/lng', name: 'MapTrackingScreen');
        return;
      }
      if (!mounted) return;
      setState(() {
        _hasValidArgs = true;
        _markers = {
          Marker(
            markerId: const MarkerId('destinationMarker'),
            position: LatLng(_destinationLat!, _destinationLng!),
            infoWindow: InfoWindow(title: _destinationName ?? 'Destination'),
          ),
        };
        _isLoading = false; // Minimal ready
      });
      dev.log('MapTrackingScreen: initialized from lazy session (no directions)', name: 'MapTrackingScreen');
      // Attempt route rehydration if auto-resumed and we have a destination.
      if (TrackingService.autoResumed) {
        _rehydrateDirectionsIfNeeded();
      }
    } catch (e) {
      dev.log('MapTrackingScreen: lazy session exception $e', name: 'MapTrackingScreen');
    }
  }

  Future<void> _rehydrateDirectionsIfNeeded() async {
    if (_destinationLat == null || _destinationLng == null) return;
    if (_polylines.isNotEmpty && _routePoints.isNotEmpty) return; // already have
    dev.log('GW_RESUME_ROUTE_FETCH start', name: 'MapTrackingScreen');
    final int tStart = DateTime.now().millisecondsSinceEpoch;
    try {
      final pos = _currentUserLocation;
      Position? fresh;
      if (pos == null) {
        try { fresh = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high); } catch (_) {}
      }
      final startLat = pos?.latitude ?? fresh?.latitude ?? _destinationLat!; // fall back to dest (degenerate) if no loc yet
      final startLng = pos?.longitude ?? fresh?.longitude ?? _destinationLng!;
      final ds = DirectionService();
      final dirs = await ds.getDirections(
        startLat,
        startLng,
        _destinationLat!,
        _destinationLng!,
        isDistanceMode: true,
        threshold: 1.0,
        transitMode: _metroMode,
        forceRefresh: true,
      );
      directions = dirs;
      if (_metroMode) {
        List<Polyline> segmented = ds.buildSegmentedPolylines(directions!, true);
        if (segmented.isEmpty) {
          // Retry once in case steps missing due to transient API issue
          dev.log('GW_RESUME_ROUTE_SEGMENT_RETRY metro segmentation empty; refetching', name: 'MapTrackingScreen');
          try {
            final retryDirs = await ds.getDirections(
              startLat,
              startLng,
              _destinationLat!,
              _destinationLng!,
              isDistanceMode: true,
              threshold: 1.0,
              transitMode: _metroMode,
              forceRefresh: true,
            );
            directions = retryDirs;
            segmented = ds.buildSegmentedPolylines(directions!, true);
          } catch (e) {
            dev.log('GW_RESUME_ROUTE_SEGMENT_RETRY_FAIL err=$e', name: 'MapTrackingScreen');
          }
        }
        if (segmented.isNotEmpty) {
          setState(() {
            _polylines = segmented.toSet();
            _routePoints = segmented.expand((p) => p.points).toList(growable: false);
          });
          _buildTransferBoundariesFromDirections();
          _buildStepBoundariesAndDurations();
        } else {
          dev.log('GW_RESUME_ROUTE_SEGMENT_FALLBACK no segmented polylines', name: 'MapTrackingScreen');
        }
      } else {
        final segmented = DirectionService().buildSegmentedPolylines(directions!, false);
        if (segmented.isNotEmpty) {
          setState(() {
            _polylines = segmented.toSet();
            _routePoints = segmented.expand((p) => p.points).toList(growable: false);
          });
        } else {
          try {
            final route = directions!['routes'][0];
            final String encodedPolyline = route['overview_polyline']['points'] as String;
            final points = PolylineSimplifier.simplifyPolyline(decodePolyline(encodedPolyline), 10);
            setState(() {
              _polylines = { Polyline(polylineId: const PolylineId('route'), points: points, color: Colors.blue, width: 4) };
              _routePoints = points;
            });
          } catch (e) {
            dev.log('GW_RESUME_ROUTE_FALLBACK_FAIL err=$e', name: 'MapTrackingScreen');
          }
        }
        _transferBoundariesMeters.clear();
        _buildStepBoundariesAndDurations();
      }
      _computeRouteLength();
      // After obtaining route, compute metrics from current (or fallback) position
      final userLat = startLat;
      final userLng = startLng;
      _computeInitialMetrics(userLat, userLng);
      _adjustCamera(userLat, userLng);
      final int tDone = DateTime.now().millisecondsSinceEpoch;
      final int dt = tDone - tStart;
      dev.log('GW_RESUME_ROUTE_READY ok pts=${_routePoints.length} dtMs=$dt', name: 'MapTrackingScreen');
      if (dt > 5000) {
        dev.log('GW_RESUME_ROUTE_SLOW dtMs=$dt attempts=$_rehydrationAttempts', name: 'MapTrackingScreen');
      }
    } catch (e) {
      dev.log('GW_RESUME_ROUTE_FAIL err=$e', name: 'MapTrackingScreen');
    }
  }

  // Deferred retry scheduler for auto-resume when GPS not yet ready or network/directions failed.
  Timer? _rehydrationRetryTimer;
  int _rehydrationAttempts = 0;
  static const int _rehydrationMaxAttempts = 5;

  void _scheduleRehydrationRetry({String reason = 'unspecified'}) {
    if (!TrackingService.autoResumed) return; // only for auto resume path
    if (_polylines.isNotEmpty) return; // already resolved
    if (_rehydrationAttempts >= _rehydrationMaxAttempts) {
      dev.log('GW_RESUME_ROUTE_GIVEUP attempts=$_rehydrationAttempts reason=$reason', name: 'MapTrackingScreen');
      return;
    }
    _rehydrationAttempts += 1;
    final backoffMs = 400 * _rehydrationAttempts; // linear backoff (0.4s,0.8s,... up to 2s)
    dev.log('GW_RESUME_ROUTE_RETRY in ${backoffMs}ms attempt=$_rehydrationAttempts reason=$reason', name: 'MapTrackingScreen');
    _rehydrationRetryTimer?.cancel();
    _rehydrationRetryTimer = Timer(Duration(milliseconds: backoffMs), () {
      _rehydrateDirectionsIfNeeded();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    dev.log("MapTrackingScreen received args: ${args.toString()}", name: "MapTrackingScreen");
    if (args == null || args['lat'] == null || args['lng'] == null || args['destination'] == null) {
      // Fallback: If auto resume flagged, try to lazily load session (lightweight) and initialize minimal state.
      if (TrackingService.autoResumed) {
        dev.log('MapTrackingScreen: missing route args; attempting lazy session load', name: 'MapTrackingScreen');
        _initFromSessionLazy();
        return;
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text("Error"),
              content: const Text("Destination information missing."),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.pop(context);
                  },
                  child: const Text("OK"),
                ),
              ],
            ),
          );
        });
        return;
      }
    }
    _hasValidArgs = true;    
    _destinationName = args['destination'];
    _destinationLat = args['lat'];
    _destinationLng = args['lng'];
    _metroMode = args['metroMode'] ?? false;
    double userLat = args['userLat'] ?? 37.422;
    double userLng = args['userLng'] ?? -122.084;
    _currentUserLocation = LatLng(userLat, userLng);
    dev.log("MapTrackingScreen: Destination: $_destinationName, ($_destinationLat, $_destinationLng)",
        name: "MapTrackingScreen");
    dev.log("MapTrackingScreen: Initial user location: ($userLat, $userLng)",
        name: "MapTrackingScreen");

    _markers = {
      Marker(
        markerId: const MarkerId('destinationMarker'),
        position: LatLng(_destinationLat!, _destinationLng!),
        infoWindow: InfoWindow(title: _destinationName!),
      ),
      Marker(
        markerId: const MarkerId('currentLocationMarker'),
        position: _currentUserLocation!,
        infoWindow: const InfoWindow(title: 'Your Location'),
      ),
    };

    _etaText = args['eta']?.toString() ?? _etaText;
    _distanceText = args['distance']?.toString() ?? _distanceText;
    directions = args['directions'];
    if (directions != null) {
      if (_metroMode) {
        final directionService = DirectionService();
        final segmentedPolylines =
            directionService.buildSegmentedPolylines(directions!, true);
        setState(() {
          _polylines = segmentedPolylines.toSet();
          // For metro, merge all polylines to a single list for snapping (optional)
          _routePoints = segmentedPolylines.expand((p) => p.points).toList(growable: false);
          _isLoading = false;
        });
        _computeRouteLength();
        _buildTransferBoundariesFromDirections();
  _buildStepBoundariesAndDurations();
        _computeInitialMetrics(userLat, userLng);
        _adjustCamera(userLat, userLng);
      } else {
        try {
          final directionService = DirectionService();
          final segmentedPolylines =
              directionService.buildSegmentedPolylines(directions!, false);
          if (segmentedPolylines.isNotEmpty) {
            setState(() {
              _polylines = segmentedPolylines.toSet();
              _routePoints = segmentedPolylines
                  .expand((p) => p.points)
                  .toList(growable: false);
              _isLoading = false;
            });
          } else {
            // Fallback to overview polyline if step data is missing
            final route = directions!['routes'][0];
            final String encodedPolyline = route['overview_polyline']['points'] as String;
            final points = PolylineSimplifier.simplifyPolyline(
                decodePolyline(encodedPolyline), 10);
            setState(() {
              _polylines = {
                Polyline(
                  polylineId: const PolylineId('route'),
                  points: points,
                  color: Colors.blue,
                  width: 4,
                )
              };
              _routePoints = points;
              _isLoading = false;
            });
          }
          _computeRouteLength();
          _transferBoundariesMeters.clear();
          _buildStepBoundariesAndDurations();
          _computeInitialMetrics(userLat, userLng);
          _adjustCamera(userLat, userLng);
        } catch (e) {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            dev.log("Error processing directions data: $e", name: "MapTrackingScreen");
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Unable to load route map. Please check your connection and try again."),
              ),
            );
          }
        }
      }
    } else {
      setState(() {
        _isLoading = false;
      });
      dev.log("No valid routes in directions data", name: "MapTrackingScreen");
      if (TrackingService.autoResumed) {
        // Attempt rehydration if we launched with auto-resume but had no directions args.
        _rehydrateDirectionsIfNeeded();
      }
    }

    // Start listening for location updates to update the current location marker.
    _startLocationUpdates();

    // Listen for route switches from TrackingService and show a banner.
    _routeSwitchSub ??= TrackingService().routeSwitchStream.listen((evt) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Switched route: ${evt.fromKey} → ${evt.toKey}')
        ),
      );
    });

    // Listen for connectivity changes to show offline indicator
    _connectivitySubscription ??= Connectivity().onConnectivityChanged.listen((results) {
      if (!mounted) return;
      setState(() {
        _isOnline = results.isNotEmpty && !results.contains(ConnectivityResult.none);
      });
    });

    // Listen for continuous route state to compute ETA and remaining distance.
    _routeStateSub ??= TrackingService().activeRouteStateStream.listen((state) {
      if (!mounted) return;
      // Prefer manager-provided remaining to avoid drift
      final remainingM = state.remainingMeters;

      // Derive progress from remaining and precomputed route length
      final progress = (_routeLengthMeters - remainingM).clamp(0.0, _routeLengthMeters);

      // Prefer step-based ETA when step boundaries/durations are present
      double? etaSec = EtaUtils.etaRemainingSeconds(
        progressMeters: progress,
        stepBoundariesMeters: _stepBoundariesMeters,
        stepDurationsSeconds: _stepDurationsSeconds,
      );
      if (etaSec == null) {
        final rep = _uiMovementClassifier.representativeSpeed();
        etaSec = rep > 0 ? remainingM / rep : remainingM / ThresholdsProvider.current.fallbackWalkMps;
      }

      // Format strings once here (single source of truth)
      final String etaStr = etaSec < 90
          ? '${etaSec.toStringAsFixed(0)} sec remaining'
          : etaSec < 3600
              ? '${(etaSec / 60).toStringAsFixed(0)} min remaining'
              : '${(etaSec / 3600).toStringAsFixed(1)} hr remaining';
      final String distStr = remainingM >= 1000
          ? '${(remainingM / 1000).toStringAsFixed(2)} km to destination'
          : '${remainingM.toStringAsFixed(0)} m to destination';

      String? switchMsg;
      if (state.pendingSwitchToKey != null && state.pendingSwitchInSeconds != null) {
        final secs = state.pendingSwitchInSeconds!;
        final when = secs < 60 ? '${secs.toStringAsFixed(0)} sec' : '${(secs / 60).toStringAsFixed(0)} min';
        switchMsg = "You'll have to switch routes in $when";
      }

      setState(() {
        _etaText = etaStr;
        _distanceText = distStr;
        _switchNotice = switchMsg;
      });
    });
  }

  Future<void> _startLocationUpdates() async {
    // Use high accuracy updates in the foreground.
    LocationSettings settings = const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );
    _locationSubscription =
        Geolocator.getPositionStream(locationSettings: settings).listen((position) {
      _currentUserLocation = LatLng(position.latitude, position.longitude);
      dev.log("MapTrackingScreen: New user location: (${position.latitude}, ${position.longitude})",
          name: "MapTrackingScreen");
      // If auto-resumed and we still haven't rebuilt polylines, try again once we have the first usable fix.
      if (TrackingService.autoResumed && _polylines.isEmpty) {
        _scheduleRehydrationRetry(reason: 'gps_fix');
      }
      // Smooth speed estimate (retained for possible UI or fallback)
      final rawSpeed = position.speed; // m/s
      if (rawSpeed.isFinite && rawSpeed >= 0) {
        _uiMovementClassifier.add(rawSpeed);
        final v = rawSpeed < 0.5 && _speedEmaMps != null ? _speedEmaMps! : rawSpeed;
        _speedEmaMps = _speedEmaMps == null ? v : (_speedEmaMps! * 0.8 + v * 0.2); // keep EMA for any legacy UI uses
      }

      // Snap only for marker rendering; do not recompute ETA/distance here
      LatLng markerPos = _currentUserLocation!;
      if (_routePoints.length >= 2) {
        final snap = SnapToRouteEngine.snap(
          point: _currentUserLocation!,
          polyline: _routePoints,
          hintIndex: _lastSnapIndex,
          searchWindow: 30,
        );
        _lastSnapIndex = snap.segmentIndex;
        markerPos = snap.snappedPoint;
      }

      // Update the marker for current (snapped) location.
      setState(() {
        _markers.removeWhere((m) => m.markerId.value == 'currentLocationMarker');
        _markers.add(Marker(
          markerId: const MarkerId('currentLocationMarker'),
          position: markerPos,
          infoWindow: const InfoWindow(title: 'Your Location'),
        ));
      });
    });
  }

  void _computeInitialMetrics(double userLat, double userLng) {
    if (_routePoints.length < 2) return;
    final p = LatLng(userLat, userLng);
    final snap = SnapToRouteEngine.snap(point: p, polyline: _routePoints, hintIndex: null, searchWindow: 30);
    final progress = snap.progressMeters;
    final remaining = (_routeLengthMeters - progress).clamp(0.0, double.infinity);
    double? etaSec = EtaUtils.etaRemainingSeconds(
      progressMeters: progress,
      stepBoundariesMeters: _stepBoundariesMeters,
      stepDurationsSeconds: _stepDurationsSeconds,
    );
    if (etaSec == null) {
      _uiMovementClassifier.add(_speedEmaMps ?? 0);
      final rep = _uiMovementClassifier.representativeSpeed();
      etaSec = rep > 0 ? remaining / rep : remaining / ThresholdsProvider.current.fallbackWalkMps;
    }
    final etaStr = etaSec < 90
        ? '${etaSec.toStringAsFixed(0)} sec remaining'
        : etaSec < 3600
            ? '${(etaSec / 60).toStringAsFixed(0)} min remaining'
            : '${(etaSec / 3600).toStringAsFixed(1)} hr remaining';
    final distStr = remaining >= 1000
        ? '${(remaining / 1000).toStringAsFixed(2)} km to destination'
        : '${remaining.toStringAsFixed(0)} m to destination';
    String? switchMsg;
    if (_transferBoundariesMeters.isNotEmpty) {
      final next = _transferBoundariesMeters.firstWhere((b) => b > progress, orElse: () => -1);
      if (next > 0) {
        final toSwitchM = next - progress;
  _uiMovementClassifier.add(_speedEmaMps ?? 0);
  final rep = _uiMovementClassifier.representativeSpeed();
  final tSec = toSwitchM / (rep > 0 ? rep : ThresholdsProvider.current.fallbackWalkMps);
        final when = tSec < 60 ? '${tSec.toStringAsFixed(0)} sec' : '${(tSec / 60).toStringAsFixed(0)} min';
        switchMsg = "You'll have to switch routes in $when";
      }
    }
    if (mounted) {
      setState(() {
        _etaText = etaStr;
        _distanceText = distStr;
        _switchNotice = switchMsg;
  // metrics ready
      });
    }
  }

  void _computeRouteLength() {
    double sum = 0.0;
    for (var i = 1; i < _routePoints.length; i++) {
      sum += Geolocator.distanceBetween(
        _routePoints[i - 1].latitude,
        _routePoints[i - 1].longitude,
        _routePoints[i].latitude,
        _routePoints[i].longitude,
      );
    }
    _routeLengthMeters = sum;
  }

  void _buildTransferBoundariesFromDirections() {
    _transferBoundariesMeters
      ..clear()
      ..addAll(TransferUtils.buildTransferBoundariesMeters(directions!, metroMode: _metroMode));
  }

  void _buildStepBoundariesAndDurations() {
    _stepBoundariesMeters.clear();
    _stepDurationsSeconds.clear();
    if (directions == null) return;
    try {
      final routes = (directions!['routes'] as List?) ?? const [];
      if (routes.isEmpty) return;
      final route = routes.first as Map<String, dynamic>;
      final legs = (route['legs'] as List?) ?? const [];
      double cum = 0.0;
      for (final leg in legs) {
        final steps = (leg['steps'] as List?) ?? const [];
        for (final step in steps) {
          final m = ((step['distance'] as Map<String, dynamic>?)?['value']) as num?;
          final s = ((step['duration'] as Map<String, dynamic>?)?['value']) as num?;
          if (m != null && s != null) {
            cum += m.toDouble();
            _stepBoundariesMeters.add(cum);
            _stepDurationsSeconds.add(s.toDouble());
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _adjustCamera(double userLat, double userLng) async {
    final GoogleMapController controller = await _mapController.future;
    if (_destinationLat == null || _destinationLng == null) return;
    final bounds = LatLngBounds(
      southwest: LatLng(min(userLat, _destinationLat!), min(userLng, _destinationLng!)),
      northeast: LatLng(max(userLat, _destinationLat!), max(userLng, _destinationLng!)),
    );
    controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _routeSwitchSub?.cancel();
    _routeStateSub?.cancel();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasValidArgs) {
      return Scaffold(
        appBar: AppBar(title: const Text("Map Tracking")),
        body: const Center(child: Text("Invalid or missing destination data.")),
      );
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (!didPop) {
          // Handle the back button press here if needed
          // For now, we'll just prevent the pop since canPop is false
        }
      },
      child: Scaffold(
        drawer: const SettingsDrawer(),
        appBar: AppBar(
          title: Row(
            children: [
              Text(
                _metroMode ? 'Metro Tracking' : 'Map Tracking',
                style: GoogleFonts.pacifico(
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 26,
                  ),
                ),
              ),
              if (_metroMode) ...[
                const SizedBox(width: 8),
                const Icon(Icons.train),
              ],
            ],
          ),
        ),
        bottomNavigationBar: Container(
          height: 50,
          color: Colors.grey[300],
          child: const Center(child: Text('Ad Banner Placeholder')),
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Offline mode indicator banner
              if (!_isOnline)
                Container(
                  width: double.infinity,
                  color: Colors.orange.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.wifi_off, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Offline - Using cached route data',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: Stack(
                  children: [
                    GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: LatLng(_destinationLat!, _destinationLng!),
                        zoom: 14,
                      ),
                      markers: _markers,
                      polylines: _polylines,
                      onMapCreated: (controller) {
                        if (!_mapController.isCompleted) {
                          _mapController.complete(controller);
                        }
                      },
                    ),
                    // Route legend overlay (compact, avoids overflow)
                    Positioned(
                      top: 12,
                      left: 12,
                      right: 12,
                      child: Material(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return Wrap(
                                spacing: 12,
                                runSpacing: 6,
                                alignment: WrapAlignment.start,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  _LegendItem(
                                    color: Colors.blue,
                                    dashed: false,
                                    label: 'Driving',
                                  ),
                                  _LegendItem(
                                    color: Colors.blue,
                                    dashed: true,
                                    label: 'Walking',
                                  ),
                                  _LegendItem(
                                    color: Colors.green,
                                    dashed: false,
                                    label: 'Metro Line A',
                                  ),
                                  _LegendItem(
                                    color: Colors.purple,
                                    dashed: false,
                                    label: 'Metro Line B',
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    if (_isLoading)
                      const Center(child: CircularProgressIndicator()),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Stop alarm button moved to bottom of screen
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _etaText,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                        if (!_etaText.contains('remaining')) ...[
                          const SizedBox(width: 8),
                          const PulsingDots(color: Colors.grey),
                        ]
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _distanceText,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                        if (!_distanceText.contains('to destination')) ...[
                          const SizedBox(width: 8),
                          const PulsingDots(color: Colors.grey),
                        ]
                      ],
                    ),
                    if (_switchNotice != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _switchNotice!,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.orange),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        // Stop Alarm Button - only visible when alarm is playing
                        Expanded(
                          child: ValueListenableBuilder<bool>(
                            valueListenable: AlarmPlayer.isPlaying,
                            builder: (context, playing, child) {
                              final cs = Theme.of(context).colorScheme;
                              return ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: cs.secondaryContainer,
                                  foregroundColor: cs.onSecondaryContainer,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  disabledBackgroundColor: Colors.grey.shade300,
                                  disabledForegroundColor: Colors.grey.shade600,
                                ),
                                onPressed: playing ? () async {
                                  await AlarmPlayer.stop();
                                  try {
                                    // Also notify the background service
                                    final service = FlutterBackgroundService();
                                    service.invoke('stopAlarm');
                                  } catch (e) {
                                    dev.log('Failed to send stopAlarm to service: $e', name: 'MapTracking');
                                  }
                                } : null, // Button disabled when alarm not playing
                                icon: const Icon(Icons.notifications_off, size: 24),
                                label: const Text('STOP ALARM'),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 8), // Spacing between buttons
                        // End Tracking Button
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.error,
                              foregroundColor: Theme.of(context).colorScheme.onError,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            onPressed: () async {
                              // Stop alarm sounds and vibration
                              await AlarmPlayer.stop();
                              
                              // Stop tracking service
                              await TrackingService().stopTracking();
                              
                              // Cancel notifications through notification service
                              try {
                                await NotificationService().cancelJourneyProgress();
                              } catch (e) {
                                dev.log('Error cancelling notifications: $e', name: 'MapTracking');
                              }
                              
                              // Navigate back to home screen
                              Navigator.pushReplacementNamed(context, '/');
                            },
                            icon: const Icon(Icons.stop_circle_outlined, size: 24),
                            label: const Text('END TRACKING'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final bool dashed;
  final String label;
  const _LegendItem({required this.color, required this.dashed, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          painter: _LineSamplePainter(color: color, dashed: dashed),
          size: const Size(28, 6),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ],
    );
  }
}

class _LineSamplePainter extends CustomPainter {
  final Color color;
  final bool dashed;
  _LineSamplePainter({required this.color, required this.dashed});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final y = size.height / 2;
    if (!dashed) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    } else {
      const double dashWidth = 8.0;
      const double dashSpace = 6.0;
      double x = 0.0;
      while (x < size.width) {
        final double x2 = (x + dashWidth) > size.width ? size.width : (x + dashWidth);
        canvas.drawLine(Offset(x, y), Offset(x2, y), paint);
        x += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

