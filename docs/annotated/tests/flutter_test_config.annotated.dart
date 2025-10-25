// Annotated copy of test/flutter_test_config.dart
// Purpose: Global test configuration and setup for Flutter test suite.
// This file is automatically executed before any tests run, providing centralized initialization.

import 'dart:async'; // Dart async primitives - Future, FutureOr for flexible return types
import 'dart:io'; // Dart I/O library - Directory, File for filesystem operations
import 'package:hive/hive.dart'; // Hive database - NoSQL local storage (without Flutter UI dependencies)

// ═══════════════════════════════════════════════════════════════════════════
// GLOBAL TEST EXECUTABLE
// ═══════════════════════════════════════════════════════════════════════════
// Runs before any tests. Initializes Hive with a temp directory so boxes open in tests.
// This function is discovered and called automatically by the Flutter test framework.
// The name "testExecutable" is a convention recognized by the test runner.
Future<void> testExecutable(FutureOr<void> Function() testMain) async { // Test suite entry point
  // testMain: callback function that runs all the tests
  // FutureOr<void>: can return either void or Future<void> (flexible return type)
  // This wrapper runs before and after all tests, providing setup/teardown
  
  final tmpDir = await Directory.systemTemp.createTemp('geowake2_test_hive_'); // Create temporary directory
  // Directory.systemTemp: platform-specific temp directory
  //   - Linux: /tmp
  //   - macOS: /var/folders/...
  //   - Windows: C:\Users\<user>\AppData\Local\Temp
  // createTemp('geowake2_test_hive_'): creates unique temp dir with prefix
  //   - Result: /tmp/geowake2_test_hive_<random_suffix>/
  // Random suffix prevents conflicts if multiple test runs execute simultaneously
  // Temporary directory ensures tests don't interfere with production data
  
  Hive.init(tmpDir.path); // Initialize Hive database engine with temp directory
  // Sets the base path for all Hive operations
  // All box files will be created under tmpDir
  // Example: /tmp/geowake2_test_hive_abc123/route_cache_v1.hive
  // Without init, Hive would fail to open boxes (path not set)
  // This is critical because tests use Hive boxes (RouteCache, RecentLocations, etc.)
  
  try { // Exception handling block - ensures cleanup even if tests fail
    await testMain(); // Execute all tests
    // This calls the main test function which discovers and runs all test files
    // Includes:
    //   - Unit tests (individual function/class tests)
    //   - Integration tests (multi-component tests)
    //   - Widget tests (UI component tests)
    // await ensures we wait for all tests to complete before cleanup
  } finally { // Cleanup block - runs regardless of test success/failure
    // finally ensures cleanup happens even if:
    //   - Tests fail with exceptions
    //   - Tests timeout
    //   - Test runner is interrupted (Ctrl+C)
    
    await Hive.close(); // Close all open Hive boxes
    // Flushes pending writes to disk
    // Releases file handles
    // Prevents "box is already open" errors in subsequent test runs
    // Critical for clean test isolation
    
    try { // Attempt to delete temp directory
      await tmpDir.delete(recursive: true); // Delete temp directory and all contents
      // recursive: true = delete directory and all files/subdirectories
      // Cleans up .hive files, .lock files, etc.
      // Prevents test artifacts from accumulating on disk
      // Important for CI/CD environments with limited disk space
    } catch (_) {} // Ignore deletion errors
    // Deletion might fail if:
    //   - Files are still locked by OS
    //   - Permission denied
    //   - Directory already deleted
    // Non-fatal - OS will eventually clean up temp directories
    // Underscore parameter name: we don't use the exception object
  } // End finally block
} // End testExecutable function

/* ═══════════════════════════════════════════════════════════════════════════
   FILE SUMMARY: flutter_test_config.dart - Test Suite Global Configuration
   ═══════════════════════════════════════════════════════════════════════════
   
   This file provides global setup and teardown for the entire test suite.
   It's automatically discovered and executed by the Flutter test framework
   before any tests run.
   
   PRIMARY PURPOSE:
   
   Initialize Hive database with temporary storage to prevent tests from:
   - Interfering with production data
   - Interfering with each other
   - Leaving artifacts on filesystem
   - Failing due to missing Hive initialization
   
   EXECUTION FLOW:
   
   1. Test runner discovers flutter_test_config.dart
   2. Calls testExecutable() before any tests
   3. testExecutable creates temp directory
   4. Hive.init() configures storage path
   5. testMain() runs all tests
   6. Hive.close() flushes and closes boxes
   7. Temp directory deleted (cleanup)
   
   WHY TEMP DIRECTORY:
   
   - Isolation: Each test run is independent
   - Clean State: No leftover data from previous runs
   - Safety: Can't corrupt production database
   - Parallel Runs: Multiple test runs won't conflict
   - CI/CD: No persistent state between builds
   
   HIVE USAGE IN TESTS:
   
   Many tests use Hive boxes:
   - RouteCache (route_cache_integration_test.dart)
   - RecentLocationsService (test various screens)
   - Any service that persists data locally
   
   Without this setup, tests would fail with:
   "Hive is not initialized. Call Hive.init() first."
   
   CLEANUP IMPORTANCE:
   
   - Without cleanup: temp dirs accumulate (disk bloat)
   - Without Hive.close(): file handles leak
   - Without recursive delete: .hive files remain
   
   ALTERNATIVE APPROACHES CONSIDERED:
   
   - Per-test setup: More flexible but lots of boilerplate
   - In-memory storage: Hive doesn't support (requires filesystem)
   - Mock Hive: Too much mocking overhead
   - Shared temp dir: Tests could interfere with each other
   
   CONNECTIONS TO OTHER FILES:
   
   - test/*_test.dart: All test files benefit from this setup
   - lib/services/route_cache.dart: Opens Hive boxes in tests
   - lib/screens/otherimpservices/recent_locations_service.dart: Uses Hive
   - main.dart: Production Hive.initFlutter() vs test Hive.init()
   
   POTENTIAL ISSUES / FUTURE ENHANCEMENTS:
   
   - No logging: Could log temp dir path for debugging
   - Ignore delete errors: Could log if deletion fails
   - No timeout: testMain() could hang indefinitely (test framework handles)
   - Single temp dir: All tests share same Hive instance (potential conflicts)
   - No cleanup verification: Don't verify all boxes actually closed
   - Platform differences: Temp dir location varies by OS (acceptable)
   
   TEST FRAMEWORK INTEGRATION:
   
   The Flutter test framework:
   1. Searches for flutter_test_config.dart in test/
   2. Looks for testExecutable(testMain) function
   3. Calls it instead of calling testMain directly
   4. Expects it to call testMain() itself
   5. Respects async/await (waits for completion)
   
   This is a powerful pattern for global test setup that keeps individual
   test files clean and focused. Without this file, every test using Hive
   would need its own initialization boilerplate.
   
   CRITICAL BEHAVIORS:
   
   - Temp Directory: Unique per run (no conflicts)
   - Hive Init: Required before any box operations
   - Cleanup: Guaranteed via finally (even on failure)
   - Error Handling: Graceful (deletion failures ignored)
   - Async Aware: Properly awaits all operations
   
   This 18-line file is essential infrastructure that makes hundreds of tests
   possible. It's invisible to test writers but critical to test reliability.
*/
