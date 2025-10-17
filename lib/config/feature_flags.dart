/// Centralized feature flags (all default false for safety unless noted)
class FeatureFlags {
  // Enables use of the SegmentProjector for deviation & progress calculations
  static bool advancedProjection = false;
  // Enables persistence of tracking snapshots
  static bool persistence = false; // mirrors TrackingService.enablePersistence (kept for future centralization)
}
