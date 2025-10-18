class EtaUtils {
  static double? etaRemainingSeconds({
    required double progressMeters,
    required List<double> stepBoundariesMeters,
    required List<double> stepDurationsSeconds,
  }) {
    // Validate inputs
    if (stepBoundariesMeters.isEmpty ||
        stepDurationsSeconds.isEmpty ||
        stepBoundariesMeters.length != stepDurationsSeconds.length) {
      return null;
    }
    
    // Handle invalid progress values
    if (!progressMeters.isFinite || progressMeters < 0) {
      progressMeters = 0.0;
    }
    
    // Completed route
    if (progressMeters >= stepBoundariesMeters.last) return 0.0;

    // Find current step index where boundary > progress
    int idx = 0;
    while (idx < stepBoundariesMeters.length && stepBoundariesMeters[idx] <= progressMeters) {
      idx++;
    }
    if (idx >= stepBoundariesMeters.length) return 0.0;

    final prevBoundary = idx == 0 ? 0.0 : stepBoundariesMeters[idx - 1];
    final stepLen = (stepBoundariesMeters[idx] - prevBoundary).clamp(0.0, double.infinity);
    final withinStep = (progressMeters - prevBoundary).clamp(0.0, stepLen);
    final remainInStepMeters = (stepLen - withinStep).clamp(0.0, stepLen);
    final stepDur = stepDurationsSeconds[idx];
    
    // Prevent division by zero and handle edge cases
    final currStepRemain = stepLen > 0 ? (remainInStepMeters / stepLen) * stepDur : 0.0;

    double tail = 0.0;
    for (int j = idx + 1; j < stepDurationsSeconds.length; j++) {
      tail += stepDurationsSeconds[j];
    }
    
    final totalRemaining = currStepRemain + tail;
    
    // Clamp to reasonable range (0 to 24 hours)
    return totalRemaining.clamp(0.0, 86400.0);
  }
}
