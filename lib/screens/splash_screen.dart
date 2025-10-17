import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/bootstrap_service.dart';
import '../services/navigation_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);
  
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController ringController;
  late AnimationController textController;
  Timer? _textTimer;
  Timer? _fallbackNavTimer;
  StreamSubscription? _bootSub;
  
  @override
  void initState() {
    super.initState();
    
    // Controller for the pulsing (ringing) effect.
    ringController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    // Controller for the fade and slide in of the text.
    textController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    
    // Start text animation slightly after the splash appears.
    _textTimer = Timer(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      textController.forward();
    });

    // Listen to bootstrap phases for early navigation
    _bootSub = BootstrapService.I.states.listen((s) {
      if (!mounted) return;
      if (s.phase == BootstrapPhase.ready) {
        final nav = NavigationService.navigatorKey.currentState;
        if (nav == null) return;
        final target = s.targetRoute ?? '/';
        if (target == '/mapTracking') {
          debugPrint('GW_NAV_SPLASH_BOOT_READY mapTracking');
          nav.pushNamedAndRemoveUntil('/mapTracking', (r) => false, arguments: s.mapTrackingArgs);
        } else {
          debugPrint('GW_NAV_SPLASH_BOOT_READY home');
          nav.pushNamedAndRemoveUntil('/', (r) => false);
        }
      }
    });
    // Fallback after 7s if bootstrap never reports ready
    _fallbackNavTimer = Timer(const Duration(seconds: 7), () {
      if (!mounted) return;
      final nav = NavigationService.navigatorKey.currentState;
      if (nav != null) {
        debugPrint('GW_NAV_SPLASH_FALLBACK_TIMEOUT');
        nav.pushNamedAndRemoveUntil('/', (r) => false);
      }
    });
  }
  
  @override
  void dispose() {
    _textTimer?.cancel();
    _fallbackNavTimer?.cancel();
    _bootSub?.cancel();
    ringController.dispose();
    textController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    // Load your custom clock logo image.
    final clockImage = Image.asset('assets/geowake.png', width: 150);
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // AnimatedBuilder creates the pulsing effect.
            AnimatedBuilder(
              animation: ringController,
              builder: (context, child) {
                double scale = 1 + 0.05 * sin(ringController.value * 2 * pi);
                return Transform.scale(
                  scale: scale,
                  child: child,
                );
              },
              child: clockImage,
            ),
            const SizedBox(height: 30),
            // Fade and Slide transition for the "GeoWake" text.
            FadeTransition(
              opacity: CurvedAnimation(
                parent: textController,
                curve: Curves.easeInOut,
              ),
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.4), // Starts slightly below
                  end: Offset.zero,           // Ends at its original position
                ).animate(CurvedAnimation(
                  parent: textController,
                  curve: Curves.easeOut,
                )),
                child: Text(
                  "GeoWake",
                  style: GoogleFonts.pacifico(
                    fontSize: 36,
                    color: Colors.blueGrey[800],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
