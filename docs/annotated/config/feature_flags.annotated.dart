/// Centralized feature flags (all default false for safety unless noted)
///
/// **Purpose**: Control experimental or incomplete features via compile-time flags.
/// All flags default to false to ensure new features don't activate unexpectedly.
///
/// **Usage**: Set flags before app initialization or in test setup:
/// ```dart
/// FeatureFlags.advancedProjection = true;  // Enable experimental projection
/// ```
///
/// **Safety**: Always default to false. Only enable once thoroughly tested.
class FeatureFlags {
  /// Enables use of the SegmentProjector for deviation & progress calculations
  /// 
  /// When true, uses more sophisticated geometry to calculate user's position
  /// relative to route segments. More accurate but computationally intensive.
  /// 
  /// Default: false (uses simpler straight-line calculations)
  static bool advancedProjection = false;
  
  /// Enables persistence of tracking snapshots
  /// 
  /// When true, periodically saves tracking state to disk to enable
  /// restoration after app is killed or device restarts.
  /// 
  /// Default: false (no persistence, cleaner but no crash recovery)
  /// 
  /// Note: Mirrors TrackingService.enablePersistence (kept for future centralization)
  static bool persistence = false;
}
