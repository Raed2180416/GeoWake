// Annotated copy of lib/debug/dev_server.dart
// Purpose: Document lightweight HTTP server for remote demo triggering during development.

import 'dart:async'; // For Future and async operations
import 'dart:convert'; // For JSON encoding/decoding
import 'dart:io'; // For HTTP server functionality
import 'dart:developer' as dev; // Structured logging
import 'package:google_maps_flutter/google_maps_flutter.dart'; // LatLng coordinate type
import 'package:geowake2/debug/demo_tools.dart'; // Demo simulation functions

class DevServer { // Static class providing HTTP server for remote demo control
  static HttpServer? _server; // HTTP server instance (null if not started)

  /// Starts the development HTTP server on the specified port
  /// This allows triggering demo journeys and alarms via HTTP requests
  /// Typically called from main.dart in debug/profile builds only
  /// Default port 8765 is chosen to avoid common port conflicts
  static Future<void> start({int port = 8765}) async { // Start server on given port
    if (_server != null) return; // Already running, don't start again
    
    try {
      // Bind HTTP server to all network interfaces (0.0.0.0)
      // This allows access from other devices on the network (e.g., curl from laptop)
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port); // Bind to 0.0.0.0:port
      dev.log('DevServer listening on 0.0.0.0:$port', name: 'DevServer'); // Log server start
      
      // Process incoming requests
      // ignore: unawaited_futures - Fire and forget, server runs independently
      _server!.forEach(_handleRequest); // Handle each incoming request
    } catch (e) { // Catch binding failures (e.g., port already in use)
      dev.log('DevServer failed to start: $e', name: 'DevServer'); // Log error
    }
  } // End start

  /// Handles individual HTTP requests and routes them to appropriate handlers
  /// Supports health check, journey simulation, and alarm triggering endpoints
  static Future<void> _handleRequest(HttpRequest req) async { // Request handler
    try {
      final path = req.uri.path; // Extract request path (e.g., "/demo/journey")
      dev.log('DevServer request: $path', name: 'DevServer'); // Log incoming request
      
      // Health check endpoint - returns {"ok": true}
      // Used to verify server is running: curl http://localhost:8765/health
      if (path == '/health') { // Health check
        return _json(req, {'ok': true}); // Return success JSON
      }
      
      // Demo journey endpoint - starts simulated GPS journey
      // Supports optional query parameters for custom origin:
      // curl http://localhost:8765/demo/journey?lat=12.96&lng=77.58
      if (path == '/demo/journey') { // Journey simulation
        LatLng? origin; // Optional origin coordinate
        
        // Parse optional lat/lng query parameters
        final lat = double.tryParse(req.uri.queryParameters['lat'] ?? ''); // Parse latitude
        final lng = double.tryParse(req.uri.queryParameters['lng'] ?? ''); // Parse longitude
        
        // If both lat and lng provided, create origin point
        if (lat != null && lng != null) { // Valid coordinates
          origin = LatLng(lat, lng); // Create origin from parameters
        }
        
        // Start demo journey (with or without custom origin)
        await DemoRouteSimulator.startDemoJourney(origin: origin); // Trigger simulation
        return _json(req, {'status': 'started'}); // Return success response
      }
      
      // Transfer alarm endpoint - triggers demo transfer alarm
      // Used to test multi-modal transit alarms:
      // curl http://localhost:8765/demo/transfer
      if (path == '/demo/transfer') { // Transfer alarm
        await DemoRouteSimulator.triggerTransferAlarmDemo(); // Trigger transfer alarm
        return _json(req, {'status': 'transfer_triggered'}); // Return success response
      }
      
      // Destination alarm endpoint - triggers demo destination alarm
      // Used to test arrival alarms:
      // curl http://localhost:8765/demo/destination
      if (path == '/demo/destination') { // Destination alarm
        await DemoRouteSimulator.triggerDestinationAlarmDemo(); // Trigger destination alarm
        return _json(req, {'status': 'destination_triggered'}); // Return success response
      }
      
      // Unknown path - return 404 error
      return _json(req, {'error': 'not_found', 'path': path}, status: HttpStatus.notFound); // 404 response
    } catch (e) { // Catch any handler errors
      // Return 500 error with exception details
      return _json(req, {'error': e.toString()}, status: HttpStatus.internalServerError); // 500 response
    }
  } // End _handleRequest

  /// Helper method to send JSON response
  /// Sets appropriate headers and status code
  static Future<void> _json(HttpRequest req, Map<String, dynamic> body, {int status = 200}) async { // JSON response helper
    req.response.statusCode = status; // Set HTTP status code (200, 404, 500, etc.)
    req.response.headers.contentType = ContentType.json; // Set Content-Type: application/json header
    req.response.write(jsonEncode(body)); // Write JSON-encoded body
    await req.response.close(); // Close response stream (sends response to client)
  } // End _json
} // End DevServer

/* File summary: dev_server.dart implements a lightweight HTTP server for remote control of demo features during
   development and testing. The server binds to 0.0.0.0 (all network interfaces) on port 8765, making it accessible
   from other devices on the local network. This enables convenient testing from a laptop while the app runs on a
   phone or emulator. Four endpoints are provided: /health for server verification, /demo/journey for simulated GPS
   journeys (with optional custom origin), /demo/transfer for transfer alarm testing, and /demo/destination for
   destination alarm testing. All responses are JSON-formatted for easy scripting and automation. The server is
   only started in debug/profile builds (see main.dart) and is automatically excluded from release builds. This
   tool significantly accelerates development by eliminating the need for manual UI interaction or physical movement
   to test tracking and alarm features. Error handling returns appropriate HTTP status codes (404 for unknown paths,
   500 for handler errors). The server runs independently after starting (unawaited forEach) and doesn't block the
   main app. Port 8765 was chosen to avoid conflicts with common development servers (3000, 8080, etc.). */
