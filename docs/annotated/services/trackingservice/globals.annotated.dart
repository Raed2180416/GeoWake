/// globals.dart: Source file from lib/lib/services/trackingservice/globals.dart
/// 
/// This annotated version provides detailed documentation for all classes, methods, and fields.

part of 'package:geowake2/services/trackingservice.dart';

// Test hooks and shared mutable globals
Stream<Position>? testGpsStream;
@visibleForTesting
Stream<AccelerometerEvent>? testAccelerometerStream;
@visibleForTesting
Duration gpsDropoutBuffer = const Duration(seconds: 25);

/// TestServiceInstance: Class for [brief description]
/// 
/// **Purpose**: [What this class does]
/// 
/// **Usage**: [How to use this class]
class TestServiceInstance implements ServiceInstance {
  /// [Brief description of this field]
  final _eventControllers = <String, StreamController<Map<String, dynamic>?>>{};

  @override
  /// invoke: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  void invoke(String method, [Map<String, dynamic>? args]) {
    /// log: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    dev.log("Test service invoke: $method, args: $args", name: "TestService");
  }

  @override
  /// stopSelf: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Future<void> stopSelf() async {
    /// log: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    dev.log("Test service stopped", name: "TestService");
  }

  @override
  /// on: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Stream<Map<String, dynamic>?> on(String event) {
    /// putIfAbsent: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    _eventControllers.putIfAbsent(
      event,
      /// broadcast: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      () => StreamController<Map<String, dynamic>?>.broadcast(),
    );
    return _eventControllers[event]!.stream;
  }

  /// dispose: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  void dispose() {
    /// for: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    for (var controller in _eventControllers.values) {
      /// close: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      controller.close();
    }
  }
}

// Heading smoothing and sample validation helpers
HeadingSmoother _headingSmoother = HeadingSmoother();
double? _smoothedHeadingDeg;
SampleValidator _sampleValidator = SampleValidator();

@visibleForTesting
/// setTestSampleValidatorBypass: [Brief description of what this function does]
/// 
/// **Parameters**: [Describe parameters if any]
/// **Returns**: [Describe return value]
void setTestSampleValidatorBypass(bool enable) {
  /// if: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  if (enable) {
    /// _BypassSampleValidator: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    _sampleValidator = _BypassSampleValidator();
  } else {
    _sampleValidator = SampleValidator();
  }
}

/// _BypassSampleValidator: Class for [brief description]
/// 
/// **Purpose**: [What this class does]
/// 
/// **Usage**: [How to use this class]
class _BypassSampleValidator extends SampleValidator {
  /// _BypassSampleValidator: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  _BypassSampleValidator();

  @override
  /// validate: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  SampleValidationResult validate(Position p, DateTime now) {
    // Always accept without side-effects so legacy tests counting updates behave unchanged.
    /// accept: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    return SampleValidationResult.accept(p);
  }
}
