import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:geowake2/services/permissionflow.dart';
import 'package:geowake2/screens/otherimpservices/recent_locations_service.dart';
import 'package:geowake2/services/places_service.dart';
import 'package:geowake2/services/metro_stop_service.dart'; // Updated service using Google Places API
import 'settingsdrawer.dart';
import 'package:geowake2/services/trackingservice.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart'; // For connectivity checks
import 'package:battery_plus/battery_plus.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  Timer? _debounce;
  String? _currentCountryCode;

  List<Map<String, dynamic>> _recentLocations = [];
  final Map<String, List<Map<String, dynamic>>> _cache = {};
  List<Map<String, dynamic>> _autocompleteResults = [];
  Map<String, dynamic>? _selectedLocation;

  late PlacesService _placesService;

  bool _useDistanceMode = true;
  bool _metroMode = false;
  double _distanceSliderValue = 5.0;
  double _timeSliderValue = 15.0;
  bool _isLoading = false;
  bool _isTracking = false;
  bool _noConnectivity = false;

  // Track low battery (removed _noGps entirely)
  bool _lowBattery = false;

  LatLng? _currentPosition;
  final Completer<GoogleMapController> _mapController = Completer();
  Set<Marker> _markers = {
    const Marker(
      markerId: MarkerId('defaultMarker'),
      position: LatLng(37.422, -122.084),
      infoWindow: InfoWindow(title: 'Default Marker'),
    ),
  };

  final String _apiKey = 'AIzaSyC0vrbOhat2g5qRyhrnT6ptLmjELctXHw0';

  // Battery instance
  final Battery _battery = Battery();

  // Subscription for connectivity changes remains
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _placesService = PlacesService(apiKey: _apiKey);
    _loadRecentLocations();

    // Removed lifecycle observer and GPS connectivity checks

    // Monitor battery changes
    _initBatteryMonitoring();

    // Monitor connectivity changes
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      dev.log("Connectivity Changed: $results", name: "Connectivity Debug");
      if (!mounted) return;
      setState(() {
        _noConnectivity = results.isEmpty || results.contains(ConnectivityResult.none);
      });
    });

    // Get initial location
    _getCurrentLocation().then((pos) async {
      if (!mounted) return;
      if (pos != null) {
        setState(() {
          _currentPosition = LatLng(pos.latitude, pos.longitude);
          _markers = {
            Marker(
              markerId: const MarkerId('currentLocation'),
              position: _currentPosition!,
              infoWindow: const InfoWindow(title: 'Current Location'),
            ),
          };
        });
        await _getCountryCode();
      }
    }).catchError((error) {
      dev.log("Error getting current location: $error", name: "HomeScreen");
    });

    // Manage search focus
    _searchFocus.addListener(() {
      if (!mounted) return;
      if (_searchFocus.hasFocus && _searchController.text.isEmpty) {
        _showTopRecentLocations();
      } else if (!_searchFocus.hasFocus) {
        setState(() => _autocompleteResults = []);
      }
    });
  }

  Future<void> _initBatteryMonitoring() async {
    final int initialLevel = await _battery.batteryLevel;
    setState(() => _lowBattery = (initialLevel < 25));
    _battery.onBatteryStateChanged.listen((BatteryState state) async {
      final level = await _battery.batteryLevel;
      setState(() => _lowBattery = (level < 25));
    });
  }

  Future<void> _getCountryCode() async {
    if (_currentPosition == null) return;
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json?'
      'latlng=${_currentPosition!.latitude},${_currentPosition!.longitude}&key=$_apiKey'
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final components = data['results'][0]['address_components'] as List;
          for (var component in components) {
            final types = component['types'] as List;
            if (types.contains('country')) {
              setState(() => _currentCountryCode = component['short_name']);
              dev.log("Detected country code: $_currentCountryCode", name: "HomeScreen");
              break;
            }
          }
        }
      }
    } catch (e) {
      dev.log("Error fetching country code: $e", name: "HomeScreen");
    }
  }

  Future<void> _loadRecentLocations() async {
    try {
      final loaded = await RecentLocationsService.getRecentLocations();
      final typed = loaded.map((item) {
        if (item is Map) return Map<String, dynamic>.from(item);
        try {
          return jsonDecode(item.toString()) as Map<String, dynamic>;
        } catch (_) {
          return <String, dynamic>{};
        }
      }).toList();
      if (mounted) {
        setState(() => _recentLocations = typed);
      }
    } catch (e) {
      dev.log("Error loading recent locations: $e", name: "HomeScreen");
      if (mounted) {
        setState(() => _recentLocations = []);
      }
    }
  }

  void _showTopRecentLocations() {
    final top3 = _recentLocations.take(3).toList();
    setState(() {
      _autocompleteResults = top3.map((loc) => {
        'description': loc['description'],
        'lat': loc['lat'],
        'lng': loc['lng'],
        'isLocal': true,
      }).toList();
    });
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      if (query.isEmpty) {
        _showTopRecentLocations();
        return;
      }
      final localMatches = _recentLocations.where((loc) {
        final desc = (loc['description'] ?? '').toLowerCase();
        return desc.contains(query.toLowerCase());
      }).toList();
      if (localMatches.isNotEmpty) {
        setState(() {
          _autocompleteResults = localMatches.map((loc) => {
            'description': loc['description'],
            'lat': loc['lat'],
            'lng': loc['lng'],
            'isLocal': true,
          }).toList();
        });
      } else {
        if (_cache.containsKey(query)) {
          setState(() => _autocompleteResults = _cache[query]!);
        } else {
          try {
            final results = await _placesService.fetchAutocompleteResults(
              query,
              countryCode: _currentCountryCode,
              lat: _currentPosition?.latitude,
              lng: _currentPosition?.longitude,
            );
            _cache[query] = results;
            if (!mounted) return;
            setState(() => _autocompleteResults = results);
          } catch (e) {
            dev.log("Error fetching autocomplete results: $e", name: "HomeScreen");
          }
        }
      }
    });
  }

  Future<void> _onSuggestionSelected(Map<String, dynamic> suggestion) async {
    setState(() => _autocompleteResults = []);
    if (suggestion['isLocal'] == true) {
      final lat = suggestion['lat'];
      final lng = suggestion['lng'];
      final desc = suggestion['description'] ?? 'Unknown';
      await _setSelectedLocation(desc, lat, lng, isLocal: true);
      await _addToRecentLocations(desc, lat, lng);
    } else {
      final placeId = suggestion['place_id'];
      try {
        final details = await _placesService.fetchPlaceDetails(placeId);
        if (details != null) {
          final desc = details['description'] ?? 'Unknown';
          final lat = details['lat'];
          final lng = details['lng'];
          await _setSelectedLocation(desc, lat, lng, isLocal: false);
          await _addToRecentLocations(desc, lat, lng);
        }
      } catch (e) {
        dev.log("Error fetching place details: $e", name: "HomeScreen");
      }
    }
  }

  Future<void> _setSelectedLocation(String desc, double lat, double lng, {bool isLocal = false}) async {
    setState(() {
      _selectedLocation = {
        'description': desc,
        'lat': lat,
        'lng': lng,
        'isLocal': isLocal,
      };
      _searchController.text = desc;
      _markers = {
        Marker(
          markerId: const MarkerId('selectedMarker'),
          position: LatLng(lat, lng),
          infoWindow: InfoWindow(title: desc),
          draggable: true,
          onDragEnd: (newPos) {
            setState(() {
              _selectedLocation?['lat'] = newPos.latitude;
              _selectedLocation?['lng'] = newPos.longitude;
            });
          },
        ),
      };
    });
    try {
      final controller = await _mapController.future;
      controller.animateCamera(CameraUpdate.newLatLngZoom(LatLng(lat, lng), 14));
    } catch (e) {
      dev.log("Error animating camera: $e", name: "HomeScreen");
    }
  }

  Future<void> _addToRecentLocations(String desc, double lat, double lng) async {
    _recentLocations.removeWhere((loc) => loc['description'] == desc);
    _recentLocations.insert(0, {
      'description': desc,
      'lat': lat,
      'lng': lng,
    });
    if (_recentLocations.length > 10) {
      _recentLocations = _recentLocations.sublist(0, 10);
    }
    try {
      await RecentLocationsService.saveRecentLocations(_recentLocations);
    } catch (e) {
      dev.log("Error saving recent locations: $e", name: "HomeScreen");
    }
  }

  Future<void> _removeRecentLocation(Map<String, dynamic> suggestion) async {
    setState(() {
      _recentLocations.removeWhere((loc) => loc['description'] == suggestion['description']);
      _autocompleteResults.removeWhere((item) => item['description'] == suggestion['description']);
    });
    try {
      await RecentLocationsService.saveRecentLocations(_recentLocations);
    } catch (e) {
      dev.log("Error removing recent location: $e", name: "HomeScreen");
    }
  }

  Future<void> _onWakeMePressed() async {
    if (_noConnectivity) {
      _showErrorDialog(
        "Internet Required",
        "You need an internet connection to fetch route data. Please try again later or turn on mobile data."
      );
      return;
    }
    if (_selectedLocation == null) {
      _showErrorDialog("Destination Missing", "Please select a destination from the suggestions.");
      return;
    }
    setState(() {
      _isLoading = true;
      _isTracking = true;
    });
    try {
      final permissionFlow = PermissionFlow(context);
      final canProceed = await permissionFlow.initiatePermissionFlow();
      if (!mounted) return;
      if (canProceed) {
        await _proceedWithDirections();
      } else {
        dev.log("User did not grant required permissions => cannot proceed", name: "PermissionDebug");
        setState(() => _isTracking = false);
      }
    } catch (e) {
      dev.log("Error in _onWakeMePressed: $e", name: "PermissionDebug");
      setState(() => _isTracking = false);
      _showErrorDialog("An Error Occurred", "An unexpected error occurred. Please try again.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _proceedWithDirections() async {
    try {
      final Position? currentPosition = await _getCurrentLocation();
      if (currentPosition == null) {
        dev.log("No location available => cannot proceed with route", name: "HomeScreen");
        _showErrorDialog(
          "Location Error",
          "Unable to get your current location. Please ensure location services are enabled."
        );
        setState(() => _isTracking = false);
        return;
      }
      double destLat = _selectedLocation?['lat'] ?? 37.422;
      double destLng = _selectedLocation?['lng'] ?? -122.084;
      double userLat = currentPosition.latitude;
      double userLng = currentPosition.longitude;
      dev.log("User coordinates: ($userLat, $userLng)", name: "HomeScreen");
      dev.log("Destination coordinates: ($destLat, $destLng)", name: "HomeScreen");

      if (_metroMode) {
        LatLng originalDestination = LatLng(destLat, destLng);
        final validationResult = await MetroStopService.validateMetroRoute(
          startLocation: LatLng(userLat, userLng),
          destination: originalDestination,
          maxRadius: 500,
        );
        if (!validationResult.isValid || validationResult.closestStop == null) {
          _showErrorDialog(
            "Metro Route Unavailable",
            validationResult.errorMessage ??
                "No valid metro route available. Please choose a valid metro destination."
          );
          setState(() => _isTracking = false);
          return;
        } else {
          dev.log(
            "Transit stop found: ${validationResult.closestStop!.name} at distance: ${validationResult.distance} m",
            name: "HomeScreen"
          );
          destLat = validationResult.closestStop!.location.latitude;
          destLng = validationResult.closestStop!.location.longitude;
          _selectedLocation?['lat'] = destLat;
          _selectedLocation?['lng'] = destLng;
        }
      }
      final directions = await _fetchDirections(userLat, userLng, destLat, destLng);
      final initialETA = directions['routes'][0]['legs'][0]['duration']['value'] as int;
      dev.log("Initial ETA: $initialETA seconds", name: "HomeScreen");
      if (!mounted) return;
      final trackingService = TrackingService();
      await trackingService.startTracking();
      FlutterBackgroundService().invoke("updateRouteData", {"initialETA": initialETA});
      final Map<String, dynamic> mapArgs = {
        'destination': _searchController.text,
        'mode': _useDistanceMode ? 'distance' : 'time',
        'value': _useDistanceMode ? _distanceSliderValue : _timeSliderValue,
        'metroMode': _metroMode,
        'directions': directions,
        'userLat': userLat,
        'userLng': userLng,
        'lat': destLat,
        'lng': destLng,
        'apiKey': _apiKey,
      };
      dev.log("Passing arguments to PreloadMapScreen: ${mapArgs.toString()}", name: "HomeScreen");
      Navigator.pushReplacementNamed(context, '/preloadMap', arguments: mapArgs);
    } catch (e) {
      dev.log("Error in _proceedWithDirections: $e", name: "HomeScreen");
      _showErrorDialog("Route Error", e.toString());
      setState(() => _isTracking = false);
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  // Simplified _getCurrentLocation without extra GPS connectivity checks.
  Future<Position?> _getCurrentLocation() async {
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  Future<Map<String, dynamic>> _fetchDirections(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) async {
    final params = <String, String>{
      'origin': '$startLat,$startLng',
      'destination': '$endLat,$endLng',
      'key': _apiKey,
    };
    params['mode'] = _metroMode ? 'transit' : 'driving';
    final url = Uri.https('maps.googleapis.com', '/maps/api/directions/json', params);
    dev.log("Fetching directions from URL: $url", name: "HomeScreen");
    final response = await http.get(url);
    dev.log("HTTP response status: ${response.statusCode}", name: "HomeScreen");
    dev.log("Raw response body: ${response.body}", name: "HomeScreen");
    if (response.statusCode != 200) {
      throw Exception("Failed to fetch directions (HTTP ${response.statusCode}).");
    }
    final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
    if (jsonResponse['status'] == 'ZERO_RESULTS') {
      throw Exception("No feasible route found (ZERO_RESULTS).");
    }
    if (jsonResponse['status'] != 'OK') {
      throw Exception("No feasible route found: ${jsonResponse['status']}");
    }
    final routes = jsonResponse['routes'] as List<dynamic>?;
    if (routes == null || routes.isEmpty) {
      throw Exception("No routes available from Directions API.");
    }
    return jsonResponse;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    _connectivitySubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Responsive sizes via MediaQuery.
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color searchBarFillColor = isDarkMode ? Colors.grey[800]! : Colors.grey[200]!;

    return Scaffold(
      drawer: const SettingsDrawer(),
      appBar: AppBar(
        title: Text(
          'GeoWake',
          style: GoogleFonts.pacifico(
            textStyle: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: screenWidth * 0.07,
            ),
          ),
        ),
        actions: [
          Row(
            children: [
              const Text('Metro Mode', style: TextStyle(fontSize: 12)),
              Switch(
                value: _metroMode,
                onChanged: _isTracking ? null : (val) => setState(() => _metroMode = val),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ],
      ),
      bottomNavigationBar: Container(
        height: screenHeight * 0.06,
        color: Colors.grey[300],
        child: const Center(child: Text('Ad Banner Placeholder')),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(screenWidth * 0.04),
          child: AbsorbPointer(
            absorbing: _isTracking,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  focusNode: _searchFocus,
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                  decoration: InputDecoration(
                    hintText: 'Enter your destination',
                    prefixIcon: const Icon(Icons.search),
                    contentPadding: EdgeInsets.symmetric(
                      vertical: screenHeight * 0.015,
                      horizontal: screenWidth * 0.04,
                    ),
                    filled: true,
                    fillColor: searchBarFillColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    hintStyle: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black54),
                    prefixIconColor: isDarkMode ? Colors.white70 : Colors.black54,
                  ),
                ),
                SizedBox(height: screenHeight * 0.01),
                if (_autocompleteResults.isNotEmpty)
                  Container(
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.grey[800] : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _autocompleteResults.length,
                      itemBuilder: (context, index) {
                        final suggestion = _autocompleteResults[index];
                        return ListTile(
                          title: Text(suggestion['description'] ?? 'Unknown'),
                          onTap: () => _onSuggestionSelected(suggestion),
                          trailing: suggestion['isLocal'] == true
                              ? GestureDetector(
                                  onTap: () => _removeRecentLocation(suggestion),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.grey.shade400,
                                    ),
                                    padding: const EdgeInsets.all(4),
                                    child: const Icon(Icons.close, size: 16),
                                  ),
                                )
                              : null,
                        );
                      },
                    ),
                  ),
                SizedBox(height: screenHeight * 0.02),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    height: screenHeight * 0.3,
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: _currentPosition ?? const LatLng(37.422, -122.084),
                        zoom: 14,
                      ),
                      markers: _markers,
                      onMapCreated: (controller) => _mapController.complete(controller),
                    ),
                  ),
                ),
                SizedBox(height: screenHeight * 0.03),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Time'),
                    Switch(
                      value: _useDistanceMode,
                      onChanged: (val) => setState(() => _useDistanceMode = val),
                    ),
                    const Text('Distance'),
                  ],
                ),
                SizedBox(height: screenHeight * 0.02),
                GestureDetector(
                  onTap: () async {
                    final newValue = await showDialog<double>(
                      context: context,
                      builder: (_) {
                        return _EnterValueDialog(
                          initialValue: _useDistanceMode ? _distanceSliderValue : _timeSliderValue,
                          isDistanceMode: _useDistanceMode,
                        );
                      },
                    );
                    if (!mounted) return;
                    if (newValue != null) {
                      setState(() {
                        if (_useDistanceMode) {
                          _distanceSliderValue = newValue.clamp(0.5, 10.0);
                        } else {
                          _timeSliderValue = newValue.clamp(1.0, 60.0);
                        }
                      });
                    }
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      vertical: screenHeight * 0.015,
                      horizontal: screenWidth * 0.04,
                    ),
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.grey[700] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isDarkMode ? Colors.white38 : Colors.grey,
                        width: 1.0,
                      ),
                    ),
                    child: Text(
                      _useDistanceMode
                          ? 'Alert me within ${_distanceSliderValue.toStringAsFixed(1)} km'
                          : 'Alert me in ${_timeSliderValue.toStringAsFixed(0)} min',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: screenWidth * 0.045),
                    ),
                  ),
                ),
                SizedBox(height: screenHeight * 0.015),
                Slider(
                  value: _useDistanceMode ? _distanceSliderValue : _timeSliderValue,
                  min: _useDistanceMode ? 0.5 : 1.0,
                  max: _useDistanceMode ? 10.0 : 60.0,
                  divisions: _useDistanceMode ? 19 : 59,
                  label: _useDistanceMode
                      ? _distanceSliderValue.toStringAsFixed(1)
                      : _timeSliderValue.toStringAsFixed(0),
                  onChanged: (val) {
                    setState(() {
                      if (_useDistanceMode) {
                        _distanceSliderValue = val;
                      } else {
                        _timeSliderValue = val;
                      }
                    });
                  },
                ),
                SizedBox(height: screenHeight * 0.03),
                ElevatedButton(
                  onPressed: (_selectedLocation == null ||
                          _searchController.text.isEmpty ||
                          _isLoading ||
                          _isTracking)
                      ? null
                      : _onWakeMePressed,
                  child: Text(
                    _isLoading ? 'Loading...' : 'Wake Me!',
                    style: TextStyle(fontSize: screenWidth * 0.05),
                  ),
                ),
                if (_lowBattery)
                  Padding(
                    padding: EdgeInsets.only(top: screenHeight * 0.02),
                    child: Row(
                      children: [
                        const Spacer(),
                        _buildAlertButton(
                          icon: Icons.battery_alert,
                          onPressed: () {
                            // Handle battery warning tap if needed.
                          },
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAlertButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.redAccent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}

class _EnterValueDialog extends StatefulWidget {
  final double initialValue;
  final bool isDistanceMode;
  const _EnterValueDialog({
    required this.initialValue,
    required this.isDistanceMode,
  });
  @override
  State<_EnterValueDialog> createState() => _EnterValueDialogState();
}

class _EnterValueDialogState extends State<_EnterValueDialog> {
  late TextEditingController _controller;
  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.isDistanceMode
          ? widget.initialValue.toStringAsFixed(1)
          : widget.initialValue.toStringAsFixed(0),
    );
  }
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isDistanceMode ? 'Enter distance (km)' : 'Enter time (minutes)'),
      content: TextField(
        controller: _controller,
        keyboardType: TextInputType.numberWithOptions(
          decimal: widget.isDistanceMode,
          signed: false,
        ),
        decoration: InputDecoration(
          hintText: widget.isDistanceMode ? 'Distance in km (0.5 - 10)' : 'Time in minutes (1 - 60)',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            final text = _controller.text.trim();
            if (text.isEmpty) {
              Navigator.of(context).pop();
              return;
            }
            final value = double.tryParse(text);
            if (value == null) {
              Navigator.of(context).pop();
              return;
            }
            Navigator.of(context).pop(value);
          },
          child: const Text('OK'),
        ),
      ],
    );
  }
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
