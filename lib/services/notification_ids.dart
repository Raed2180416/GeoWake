/// Centralized notification ID constants to avoid collisions.
class NotificationIds {
  NotificationIds._();
  static const int alarm = 100; // High priority wake alarm
  static const int progress = 101; // Ongoing journey progress
  static const int backgroundService = 102; // Foreground service notification
  static const int debug = 190; // Debug/diagnostic
}
