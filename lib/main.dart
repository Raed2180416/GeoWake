import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'services/trackingservice.dart';
import 'screens/homescreen.dart';
import 'screens/maptracking.dart';
import 'screens/otherimpservices/preload_map_screen.dart';
import 'screens/splash_screen.dart'; // <-- new splash screen file
import 'themes/appthemes.dart';
import 'screens/otherimpservices/recent_locations_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize Hive for recent locations.
    await Hive.initFlutter();
    await Hive.openBox(RecentLocationsService.boxName);
  } catch (e) {
    debugPrint("Hive initialization failed: $e");
  }

  try {
    // Initialize the background tracking service (but do not start tracking yet).
    await TrackingService().initializeService();
  } catch (e) {
    debugPrint("Tracking Service initialization failed: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  bool isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _checkNotificationPermission();
  }

  /// Check and request notification permission on Android 13+ or iOS.
  Future<void> _checkNotificationPermission() async {
    final status = await Permission.notification.status;
    if (status.isDenied) {
      await Permission.notification.request();
    }
  }

  void toggleTheme() {
    setState(() {
      isDarkMode = !isDarkMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GeoWake',
      theme: isDarkMode ? AppThemes.darkTheme : AppThemes.lightTheme,
      // Set the initial route to our splash screen.
      initialRoute: '/splash',
      onGenerateRoute: (settings) {
        if (settings.name == '/splash') {
          return MaterialPageRoute(
            builder: (_) => const SplashScreen(),
            settings: settings,
          );
        }
        if (settings.name == '/preloadMap') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (_) => PreloadMapScreen(arguments: args),
            settings: settings,
          );
        }
        if (settings.name == '/mapTracking') {
          return MaterialPageRoute(
            builder: (_) => MapTrackingScreen(),
            settings: settings,
          );
        }
        // The default route '/' now points to your HomeScreen.
        if (settings.name == '/') {
          return MaterialPageRoute(builder: (_) => const HomeScreen());
        }
        return null;
      },
    );
  }
}
