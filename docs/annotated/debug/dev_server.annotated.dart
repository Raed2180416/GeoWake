// Annotated copy of lib/debug/dev_server.dart
// Purpose: Lightweight HTTP server for remote demo triggering in development/test builds.
// This enables developers and testers to trigger demo routes and alarms via HTTP requests.

import 'dart:async'; // Dart asynchronous programming primitives - Future, Stream, Timer, etc.
import 'dart:convert'; // JSON encoding/decoding - jsonEncode, jsonDecode, utf8, etc.
import 'dart:io'; // Dart I/O library - HttpServer, Socket, File, Process, etc.
import 'dart:developer' as dev; // Dart developer tools - log, debugger, Timeline, etc. (namespaced to avoid conflicts)
import 'package:google_maps_flutter/google_maps_flutter.dart'; // Google Maps Flutter plugin - LatLng class for coordinates
import 'package:geowake2/debug/demo_tools.dart'; // Demo route simulator - provides journey simulation functions

// ═══════════════════════════════════════════════════════════════════════════
// DEV SERVER CLASS
// ═══════════════════════════════════════════════════════════════════════════
class DevServer { // HTTP server for development/testing - responds to demo trigger requests
  // This is a simple REST API server that runs only in debug/profile builds
  // It listens on all network interfaces (0.0.0.0) so it can be accessed from:
  //   - localhost (same device)
  //   - LAN (other devices on same network)
  //   - USB debugging (ADB reverse port forwarding)
  
  static HttpServer? _server; // Nullable server instance - null when not running
  // Static member - shared across all DevServer instances (though only one should exist)
  // Nullable because server might not start (port conflict, permission denied, etc.)
  // HttpServer from dart:io - handles HTTP 1.1 requests

  // ═══════════════════════════════════════════════════════════════════════════
  // SERVER STARTUP
  // ═══════════════════════════════════════════════════════════════════════════
  static Future<void> start({int port = 8765}) async { // Start HTTP server on specified port
    // Default port 8765 - arbitrary choice, high enough to avoid system ports (<1024)
    // Can be overridden if port 8765 is already in use
    
    if (_server != null) return; // Already running - exit early to prevent duplicate servers
    // Guard clause prevents multiple server instances on same port (would throw exception)
    
    try { // Wrap server startup in try-catch - binding can fail
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port); // Bind to 0.0.0.0:port
      // InternetAddress.anyIPv4 = 0.0.0.0 (all IPv4 interfaces)
      // This allows connections from:
      //   - localhost (127.0.0.1)
      //   - device's IP on LAN (e.g., 192.168.1.100)
      //   - ADB reverse (for testing on physical Android devices)
      // Alternative would be InternetAddress.loopbackIPv4 (localhost only)
      
      dev.log('DevServer listening on 0.0.0.0:$port', name: 'DevServer'); // Log successful startup
      // Developers can now access server at http://<device-ip>:8765
      
      // ignore: unawaited_futures
      _server!.forEach(_handleRequest); // Process each incoming request
      // forEach listens for requests and calls _handleRequest for each one
      // This is fire-and-forget - we don't await the Future
      // The 'ignore' comment suppresses linter warning about unawaited Future
      // Server runs indefinitely until app closes or stop() is called
    } catch (e) { // Catch binding failures - port conflict, permission denied, etc.
      dev.log('DevServer failed to start: $e', name: 'DevServer'); // Log error but continue
      // Common failures:
      //   - Port already in use (another app or previous instance)
      //   - Permission denied (port < 1024 requires root on Linux)
      //   - Network interface not available
      // Non-fatal - app continues without dev server
    } // End try-catch
  } // End start method
  // Block summary: start() binds HTTP server to 0.0.0.0:8765 (or custom port).
  // Guards against duplicate servers and handles binding failures gracefully.
  // Server processes requests asynchronously via _handleRequest.

  // ═══════════════════════════════════════════════════════════════════════════
  // REQUEST HANDLER
  // ═══════════════════════════════════════════════════════════════════════════
  static Future<void> _handleRequest(HttpRequest req) async { // Handle single HTTP request
    // Called for each incoming request - runs in async context
    // HttpRequest contains method (GET/POST), URI, headers, body, etc.
    
    try { // Wrap request handling in try-catch - prevents one bad request from crashing server
      final path = req.uri.path; // Extract request path (e.g., '/health', '/demo/journey')
      // req.uri contains full URI: scheme, host, port, path, query parameters
      // We only care about path for routing
      
      dev.log('DevServer request: $path', name: 'DevServer'); // Log each request for debugging
      // Helps developers see which endpoints are being hit during testing
      
      // ─────────────────────────────────────────────────────────────────────
      // ROUTE: Health Check
      // ─────────────────────────────────────────────────────────────────────
      if (path == '/health') { // Health check endpoint - verify server is running
        return _json(req, {'ok': true}); // Return simple JSON response
        // Used by test scripts to verify server is up before triggering demos
        // curl http://localhost:8765/health → {"ok":true}
      } // End /health route
      
      // ─────────────────────────────────────────────────────────────────────
      // ROUTE: Start Demo Journey
      // ─────────────────────────────────────────────────────────────────────
      if (path == '/demo/journey') { // Trigger full demo journey with simulated GPS
        LatLng? origin; // Optional custom starting location
        
        // Parse optional lat/lng query parameters
        final lat = double.tryParse(req.uri.queryParameters['lat'] ?? ''); // Try to parse latitude
        // req.uri.queryParameters is Map<String, String> of ?key=value pairs
        // ?? '' provides empty string if 'lat' parameter is missing
        // tryParse returns null if parsing fails (invalid number)
        
        final lng = double.tryParse(req.uri.queryParameters['lng'] ?? ''); // Try to parse longitude
        // Example: /demo/journey?lat=12.96&lng=77.58
        
        if (lat != null && lng != null) { // Both parameters provided and valid
          origin = LatLng(lat, lng); // Create starting location from parameters
          // Allows custom demo start location (useful for testing specific areas)
        } // End origin parsing
        // If origin is null, DemoRouteSimulator will use default location (Bangalore)
        
        await DemoRouteSimulator.startDemoJourney(origin: origin); // Start simulated journey
        // This creates a route, starts tracking, and feeds simulated GPS positions
        // Journey runs for ~18 seconds and triggers distance alarm
        
        return _json(req, {'status': 'started'}); // Acknowledge request
        // Returns immediately while journey runs in background
        // Client can monitor progress via app UI or notifications
      } // End /demo/journey route
      
      // ─────────────────────────────────────────────────────────────────────
      // ROUTE: Trigger Transfer Alarm
      // ─────────────────────────────────────────────────────────────────────
      if (path == '/demo/transfer') { // Trigger metro transfer alarm
        await DemoRouteSimulator.triggerTransferAlarmDemo(); // Show transfer alarm
        // Displays full-screen alarm: "Change at Central Station"
        // Used to test transfer alarm UI and sound without simulating full route
        
        return _json(req, {'status': 'transfer_triggered'}); // Acknowledge request
        // Alarm should appear immediately on device
      } // End /demo/transfer route
      
      // ─────────────────────────────────────────────────────────────────────
      // ROUTE: Trigger Destination Alarm
      // ─────────────────────────────────────────────────────────────────────
      if (path == '/demo/destination') { // Trigger destination arrival alarm
        await DemoRouteSimulator.triggerDestinationAlarmDemo(); // Show destination alarm
        // Displays full-screen alarm: "Wake Up! Approaching: Demo Destination"
        // Used to test destination alarm UI and sound without simulating full route
        
        return _json(req, {'status': 'destination_triggered'}); // Acknowledge request
        // Alarm should appear immediately on device
      } // End /demo/destination route
      
      // ─────────────────────────────────────────────────────────────────────
      // ROUTE: 404 Not Found
      // ─────────────────────────────────────────────────────────────────────
      return _json(req, {'error': 'not_found', 'path': path}, status: HttpStatus.notFound); // Unknown endpoint
      // HttpStatus.notFound = 404
      // Returns which path was requested for debugging
      // Example: /demo/invalid → {"error":"not_found","path":"/demo/invalid"}
    } catch (e) { // Catch any exception in request handling
      return _json(req, {'error': e.toString()}, status: HttpStatus.internalServerError); // Return error as JSON
      // HttpStatus.internalServerError = 500
      // Prevents server crash - returns error to client instead
      // Example: {"error":"Exception: something went wrong"}
    } // End try-catch
  } // End _handleRequest method
  // Block summary: _handleRequest routes incoming requests to appropriate handlers:
  //   - /health: Health check (returns {"ok":true})
  //   - /demo/journey: Start simulated journey (optional lat/lng parameters)
  //   - /demo/transfer: Trigger transfer alarm immediately
  //   - /demo/destination: Trigger destination alarm immediately
  //   - Other: Return 404 not found
  // All routes return JSON responses. Errors return 500 with error message.

  // ═══════════════════════════════════════════════════════════════════════════
  // JSON RESPONSE HELPER
  // ═══════════════════════════════════════════════════════════════════════════
  static Future<void> _json(HttpRequest req, Map<String, dynamic> body, {int status = 200}) async { // Send JSON response
    // Helper method to reduce code duplication - all responses are JSON
    // Parameters:
    //   - req: The request to respond to
    //   - body: Data to encode as JSON
    //   - status: HTTP status code (default 200 OK)
    
    req.response.statusCode = status; // Set HTTP status code (200, 404, 500, etc.)
    // HttpResponse.statusCode is mutable - defaults to 200
    
    req.response.headers.contentType = ContentType.json; // Set Content-Type: application/json
    // Tells client that response body is JSON
    // ContentType.json = application/json charset=utf-8
    // Without this, client might not parse response correctly
    
    req.response.write(jsonEncode(body)); // Write JSON-encoded body to response
    // jsonEncode converts Map to JSON string
    // Example: {'ok': true} → '{"ok":true}'
    // write() adds data to response buffer (doesn't send immediately)
    
    await req.response.close(); // Close response and send to client
    // close() flushes buffer and completes the HTTP response
    // After close(), no more data can be written to response
    // await ensures data is fully sent before returning
  } // End _json method
  // Block summary: _json() is a helper for sending JSON responses.
  // Sets status code, content type, encodes body as JSON, and closes response.
  // Used by all routes to maintain consistent response format.
} // End DevServer class

/* ═══════════════════════════════════════════════════════════════════════════
   FILE SUMMARY: dev_server.dart - Development HTTP Server for Demo Control
   ═══════════════════════════════════════════════════════════════════════════
   
   This file provides a lightweight HTTP server that runs only in debug and
   profile builds (never in production/release builds). It enables developers
   and testers to trigger demo routes and alarms via HTTP requests.
   
   PURPOSE:
   
   - Remote Control: Trigger demos from laptop while testing on device
   - Automation: Test scripts can automate demo sequences via HTTP
   - QA Testing: Testers can trigger specific scenarios without app UI
   - CI/CD: Automated tests can verify alarm functionality
   
   ARCHITECTURE:
   
   - Simple REST API: HTTP GET requests to different paths
   - Fire-and-Forget: Requests return immediately, demos run in background
   - Error Resilient: Exceptions don't crash server, return 500 with error
   - Single Instance: Static _server prevents duplicate servers
   
   API ENDPOINTS:
   
   1. GET /health
      - Returns: {"ok":true}
      - Purpose: Verify server is running
   
   2. GET /demo/journey?lat=<lat>&lng=<lng>
      - Parameters: Optional lat/lng for custom start location
      - Returns: {"status":"started"}
      - Purpose: Start simulated GPS journey (~18 seconds, triggers alarm)
   
   3. GET /demo/transfer
      - Returns: {"status":"transfer_triggered"}
      - Purpose: Immediately show metro transfer alarm
   
   4. GET /demo/destination
      - Returns: {"status":"destination_triggered"}
      - Purpose: Immediately show destination arrival alarm
   
   5. Other paths
      - Returns: {"error":"not_found","path":"/requested/path"}
      - Status: 404 Not Found
   
   NETWORK CONFIGURATION:
   
   - Binds to: 0.0.0.0:8765 (all IPv4 interfaces)
   - Accessible from:
     - localhost: http://127.0.0.1:8765
     - LAN: http://<device-ip>:8765
     - ADB reverse: adb reverse tcp:8765 tcp:8765 → http://localhost:8765
   
   USAGE EXAMPLES:
   
   # Health check
   curl http://localhost:8765/health
   
   # Start demo journey at default location
   curl http://localhost:8765/demo/journey
   
   # Start demo journey at custom location
   curl "http://localhost:8765/demo/journey?lat=12.96&lng=77.58"
   
   # Trigger transfer alarm
   curl http://localhost:8765/demo/transfer
   
   # Trigger destination alarm
   curl http://localhost:8765/demo/destination
   
   CONNECTIONS TO OTHER FILES:
   
   - main.dart: Calls DevServer.start() in debug/profile builds
   - debug/demo_tools.dart: Provides demo journey and alarm simulation
   - services/trackingservice.dart: Demo journey uses tracking service
   - services/notification_service.dart: Alarms displayed via notification service
   
   STARTUP FLOW:
   
   1. main.dart detects debug/profile build
   2. Calls DevServer.start()
   3. Server binds to 0.0.0.0:8765
   4. Listens for requests indefinitely
   5. Each request routed through _handleRequest
   6. Demo functions called asynchronously
   7. Response sent immediately
   8. Server continues listening
   
   ERROR HANDLING:
   
   - Binding Failures: Logged but non-fatal (app continues without server)
   - Request Exceptions: Return 500 with error message (server continues)
   - Invalid Routes: Return 404 not found
   - Demo Failures: Handled by demo_tools.dart (logged but don't crash server)
   
   SECURITY CONSIDERATIONS:
   
   - Only in Debug/Profile: Never compiled into release builds (kDebugMode check in main.dart)
   - No Authentication: Anyone on network can trigger demos (acceptable for dev builds)
   - Limited Surface: Only demo endpoints (no access to real user data)
   - Local Network: Not exposed to internet (unless device is port-forwarded)
   
   POTENTIAL ISSUES / FUTURE ENHANCEMENTS:
   
   - No authentication: Could add API key for shared test devices
   - No HTTPS: Uses plain HTTP (acceptable for local dev, could add TLS)
   - No CORS headers: Browsers can't access from web pages (could add for web testing)
   - No request logging: Could log to file for debugging
   - No graceful shutdown: Server stops when app closes (could add stop() method)
   - Port hardcoded: Could make configurable via environment variable
   - No request rate limiting: Could prevent abuse on shared test devices
   - No request validation: Accepts any parameter values (could add validation)
   
   This server is intentionally simple - it's a development tool, not a production API.
   Its sole purpose is to make manual and automated testing easier by providing
   remote control of demo features. It should never be enabled in production builds.
*/
