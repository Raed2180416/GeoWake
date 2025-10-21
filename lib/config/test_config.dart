/// Centralized test configuration to replace scattered global mutable state.
/// This class provides a single source of truth for test mode settings across
/// the application, improving testability and reducing coupling.
class TestConfig {
  static TestConfig? _instance;
  
  /// Get the singleton instance
  static TestConfig get instance => _instance ??= TestConfig._();
  
  /// Reset for testing - allows tests to start with clean state
  static void resetForTests() {
    _instance = TestConfig._();
  }
  
  TestConfig._();
  
  // API Client test flags
  bool apiClientTestMode = false;
  bool disableApiConnectionTest = false;
  
  // Alarm Scheduler test flags
  bool alarmSchedulerTestMode = false;
  
  // Notification Service test flags
  bool notificationServiceTestMode = false;
  
  // Tracking Service test flags
  bool trackingServiceTestMode = false;
  bool suppressPersistenceInTest = true;
  bool testForceProximityGating = false;
  bool testBypassProximityForTime = false;
  
  // Logging
  bool enableDebugLogging = true;
  
  /// Enable all test modes (useful for comprehensive testing)
  void enableAllTestModes() {
    apiClientTestMode = true;
    disableApiConnectionTest = true;
    alarmSchedulerTestMode = true;
    notificationServiceTestMode = true;
    trackingServiceTestMode = true;
  }
  
  /// Disable all test modes (useful for production or integration tests)
  void disableAllTestModes() {
    apiClientTestMode = false;
    disableApiConnectionTest = false;
    alarmSchedulerTestMode = false;
    notificationServiceTestMode = false;
    trackingServiceTestMode = false;
    testForceProximityGating = false;
    testBypassProximityForTime = false;
  }
}
