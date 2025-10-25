part of 'package:geowake2/services/trackingservice.dart';

// Test hooks and shared mutable globals
Stream<Position>? testGpsStream;
@visibleForTesting
Stream<AccelerometerEvent>? testAccelerometerStream;
@visibleForTesting
Duration gpsDropoutBuffer = const Duration(seconds: 25);

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
      event,
      () => StreamController<Map<String, dynamic>?>.broadcast(),
    );
    return _eventControllers[event]!.stream;
  }

  void dispose() {
    for (var controller in _eventControllers.values) {
      controller.close();
    }
  }
}

// Heading smoothing and sample validation helpers
HeadingSmoother _headingSmoother = HeadingSmoother();
double? _smoothedHeadingDeg;
SampleValidator _sampleValidator = SampleValidator();

@visibleForTesting
void setTestSampleValidatorBypass(bool enable) {
  if (enable) {
    _sampleValidator = _BypassSampleValidator();
  } else {
    _sampleValidator = SampleValidator();
  }
}

class _BypassSampleValidator extends SampleValidator {
  _BypassSampleValidator();

  @override
  SampleValidationResult validate(Position p, DateTime now) {
    // Always accept without side-effects so legacy tests counting updates behave unchanged.
    return SampleValidationResult.accept(p);
  }
}
