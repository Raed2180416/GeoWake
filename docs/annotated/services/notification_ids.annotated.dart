/// Centralized notification ID constants to avoid collisions.
///
/// **Purpose**: Android notification system requires unique integer IDs for each
/// notification. Using constants prevents accidental collisions between different
/// notification types.
///
/// **ID Ranges**:
/// - 100-109: User-facing alarms and tracking notifications
/// - 110-189: Reserved for future features
/// - 190-199: Debug and diagnostic notifications
///
/// **Why this matters**: 
/// - If two notifications use the same ID, the second replaces the first
/// - Using consistent IDs allows updating existing notifications
/// - Makes it easy to cancel specific notification types
///
/// **Usage**:
/// ```dart
/// // Show alarm notification
/// notificationsPlugin.show(
///   NotificationIds.alarm,
///   'Wake Up!',
///   'Approaching destination',
///   details,
/// );
/// 
/// // Cancel alarm notification
/// notificationsPlugin.cancel(NotificationIds.alarm);
/// ```
class NotificationIds {
  /// Private constructor prevents instantiation
  /// (this is a constants-only class)
  NotificationIds._();
  
  /// High priority wake alarm notification
  /// Used for destination, transfer, and boarding alarms
  static const int alarm = 100;
  
  /// Ongoing journey progress notification
  /// Shows current progress and allows quick actions
  static const int progress = 101;
  
  /// Foreground service notification (required by Android)
  /// Keeps the service alive and informs user tracking is active
  static const int backgroundService = 102;
  
  /// Debug/diagnostic notifications
  /// Used during development and testing
  static const int debug = 190;
}
