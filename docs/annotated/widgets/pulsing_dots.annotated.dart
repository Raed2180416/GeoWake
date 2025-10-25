// Annotated copy of lib/widgets/pulsing_dots.dart
// Purpose: Animated loading indicator widget with pulsing dot animation.
// This provides visual feedback during loading states with an elegant pulsing animation.

import 'dart:async'; // Dart async primitives - Timer for periodic animations
import 'package:flutter/material.dart'; // Flutter Material Design - StatefulWidget, AnimatedContainer, Row, etc.

// ═══════════════════════════════════════════════════════════════════════════
// PULSING DOTS WIDGET
// ═══════════════════════════════════════════════════════════════════════════
class PulsingDots extends StatefulWidget { // Animated loading indicator with three pulsing dots
  // StatefulWidget because animation state changes over time
  // Common use cases:
  //   - Loading data from network
  //   - Processing user input
  //   - Waiting for operation to complete
  // Alternative to CircularProgressIndicator (more subtle, elegant)
  
  final double size; // Dot size in logical pixels (base size when not pulsing)
  // Determines scale of entire indicator
  // Larger size = more prominent loading indicator
  // Default 8.0 provides subtle loading feedback
  
  final Color color; // Dot color
  // Should contrast with background for visibility
  // Typically matches app's primary or accent color
  // Default grey is neutral and works on most backgrounds
  
  final Duration period; // Complete animation cycle duration
  // Time for one full pulse sequence (all 3 dots)
  // Shorter = faster animation (more energetic)
  // Longer = slower animation (more relaxed)
  // Default 900ms provides smooth, noticeable animation
  
  const PulsingDots({
    super.key, // Widget key for Flutter's element tree
    this.size = 8, // Default dot size: 8 logical pixels
    this.color = Colors.grey, // Default color: neutral grey
    this.period = const Duration(milliseconds: 900), // Default period: 900ms
  }); // Constructor with sensible defaults
  // All parameters optional - can use PulsingDots() with zero configuration

  @override
  State<PulsingDots> createState() => _PulsingDotsState(); // Create mutable state
  // Separates configuration (widget) from mutable data (state)
} // End PulsingDots widget class
// Block summary: PulsingDots is a configurable loading indicator with three pulsing dots.
// Size, color, and animation speed are customizable with sensible defaults.

// ═══════════════════════════════════════════════════════════════════════════
// PULSING DOTS STATE
// ═══════════════════════════════════════════════════════════════════════════
class _PulsingDotsState extends State<PulsingDots> { // State management for animation
  // Private class (underscore prefix) - only accessible within this file
  // Holds mutable animation state
  
  int _active = 0; // Index of currently pulsing dot (0, 1, or 2)
  // 0 = first (leftmost) dot is pulsing
  // 1 = middle dot is pulsing
  // 2 = last (rightmost) dot is pulsing
  // Cycles: 0 → 1 → 2 → 0 → 1 → 2 ...
  // Creates wave-like pulse effect across the three dots
  
  Timer? _timer; // Periodic timer for animation ticks
  // Nullable because timer might not be created yet or might be cancelled
  // Triggers state updates to advance animation
  // Runs continuously while widget is mounted

  // ═══════════════════════════════════════════════════════════════════════════
  // LIFECYCLE: INITIALIZATION
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  void initState() { // Widget initialization - called once when state is created
    super.initState(); // Call parent initialization - required
    
    _timer = Timer.periodic(widget.period ~/ 3, (_) { // Start animation timer
      // widget.period ~/ 3: Integer division by 3
      // Example: 900ms period → 300ms per dot
      // ~/ operator performs integer division (rounds down)
      // Each dot pulses for 1/3 of total period
      // Creates sequential pulse effect: dot1 → dot2 → dot3 → repeat
      
      if (!mounted) return; // Safety check: don't update if widget disposed
      // mounted flag is false when widget removed from tree
      // Prevents calling setState() on disposed widget (would throw exception)
      // Timer might fire after dispose() if cancellation is delayed
      
      setState(() => _active = (_active + 1) % 3); // Cycle active dot
      // (_active + 1) increments current index: 0→1, 1→2, 2→3
      // % 3 wraps around: 0→1, 1→2, 2→0 (modulo operation)
      // setState() triggers rebuild, updating dot sizes
      // Arrow function: concise syntax for simple state updates
    }); // End Timer.periodic
  } // End initState
  // Block summary: initState creates a periodic timer that cycles the active dot
  // every period/3 milliseconds, creating a continuous pulsing animation.

  // ═══════════════════════════════════════════════════════════════════════════
  // LIFECYCLE: CLEANUP
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  void dispose() { // Widget cleanup - called when state is permanently removed
    _timer?.cancel(); // Stop animation timer
    // ?. safe navigation: only call cancel() if _timer is not null
    // Prevents timer from firing after widget disposal
    // Critical for avoiding memory leaks and exceptions
    // Without cancellation, timer would keep running and trying to call setState()
    
    super.dispose(); // Call parent cleanup - required
    // Always call super.dispose() last to ensure proper framework cleanup
  } // End dispose
  // Block summary: dispose cancels the animation timer to prevent memory leaks
  // and attempts to update disposed widget.

  // ═══════════════════════════════════════════════════════════════════════════
  // UI BUILD
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) { // Build UI - called on every setState
    final sizes = List<double>.generate(3, (i) => i == _active ? widget.size * 1.8 : widget.size);
    // Generate list of 3 dot sizes based on active index
    // List.generate(3, ...) creates list with 3 elements
    // For each index i (0, 1, 2):
    //   - If i == _active: size = widget.size * 1.8 (pulsing dot is 80% larger)
    //   - Else: size = widget.size (normal size)
    // Example with size=8, _active=1:
    //   - sizes[0] = 8 (normal)
    //   - sizes[1] = 14.4 (pulsing, 1.8x larger)
    //   - sizes[2] = 8 (normal)
    // 1.8x multiplier creates noticeable but not extreme pulse
    
    return Row( // Horizontal layout for three dots
      mainAxisSize: MainAxisSize.min, // Take minimum width needed (don't expand)
      // MainAxisSize.min: Row width = sum of child widths + spacing
      // Prevents dots from stretching to fill available space
      // Useful when embedding in larger layouts (stays compact)
      
      children: List.generate(3, (i) => AnimatedContainer( // Generate 3 animated dot widgets
        // List.generate creates 3 AnimatedContainer widgets (one per dot)
        // AnimatedContainer automatically animates changes to size, color, etc.
        // Provides smooth transitions when _active changes
        
        duration: widget.period ~/ 3, // Animation duration matches timer interval
        // Each size change animates over period/3 milliseconds
        // Example: 900ms period → 300ms animation
        // Synchronized with timer ensures smooth continuous motion
        // Too fast = jittery, too slow = laggy
        
        margin: const EdgeInsets.symmetric(horizontal: 3), // Spacing between dots
        // 3 pixels of space on left and right of each dot
        // Total gap between dots = 6 pixels (3px right + 3px left)
        // symmetric(): same value for left and right
        // Creates even spacing across all three dots
        
        width: sizes[i], // Dot width from sizes list
        height: sizes[i], // Dot height (same as width = circular dot)
        // Square container (width = height)
        // Combined with circular decoration creates perfect circle
        // Size changes when i == _active (animates between widget.size and widget.size*1.8)
        
        decoration: BoxDecoration(
          color: widget.color.withOpacity(0.8), // Dot color with 80% opacity
          // withOpacity(0.8) creates semi-transparent version of base color
          // 0.8 = 80% opacity (slightly see-through)
          // Softer appearance than fully opaque (less harsh)
          // Blends better with various backgrounds
          
          shape: BoxShape.circle, // Circular shape
          // BoxShape.circle makes container round (vs rectangular default)
          // Uses width/height as diameter
          // Creates perfect circular dots
        ), // End BoxDecoration
      )), // End AnimatedContainer and List.generate
    ); // End Row
  } // End build
  // Block summary: build creates a row of 3 animated circular dots.
  // Active dot is 1.8x larger, creating a pulsing wave effect.
  // AnimatedContainer smoothly transitions between sizes.
} // End _PulsingDotsState class

/* ═══════════════════════════════════════════════════════════════════════════
   FILE SUMMARY: pulsing_dots.dart - Animated Loading Indicator Widget
   ═══════════════════════════════════════════════════════════════════════════
   
   This file provides a reusable loading indicator widget with an elegant
   pulsing animation. Three dots pulse sequentially, creating a wave effect
   that indicates ongoing activity without being distracting.
   
   WIDGET OVERVIEW:
   
   - Type: StatefulWidget (mutable animation state)
   - Visual: Three circular dots in a row
   - Animation: Dots pulse sequentially (wave effect)
   - Customizable: Size, color, and speed
   - Purpose: Loading/processing feedback
   
   ANIMATION BEHAVIOR:
   
   - Three Dots: Arranged horizontally with even spacing
   - Sequential Pulse: One dot enlarges at a time (left → center → right → repeat)
   - Size Change: Active dot is 1.8x larger (80% bigger)
   - Smooth Transition: AnimatedContainer provides interpolated size changes
   - Continuous: Animation loops indefinitely while widget is mounted
   - Timing: Each dot pulses for period/3 duration
   
   CONFIGURABLE PARAMETERS:
   
   1. size (default: 8.0):
      - Base dot size in logical pixels
      - Pulsing dot becomes size * 1.8
      - Scales entire indicator
   
   2. color (default: Colors.grey):
      - Dot color with 80% opacity
      - Should contrast with background
      - Typically matches app theme
   
   3. period (default: 900ms):
      - Complete animation cycle duration
      - Each dot pulses for period/3
      - Shorter = faster, longer = slower
   
   USAGE EXAMPLES:
   
   ```dart
   // Default configuration (grey, 8px, 900ms)
   PulsingDots()
   
   // Custom size and color
   PulsingDots(
     size: 12,
     color: Colors.deepPurple,
   )
   
   // Fast animation
   PulsingDots(
     period: Duration(milliseconds: 600),
   )
   
   // Centered in loading screen
   Center(
     child: PulsingDots(
       size: 10,
       color: Theme.of(context).primaryColor,
     ),
   )
   ```
   
   TECHNICAL IMPLEMENTATION:
   
   - Timer.periodic: Drives animation by updating _active every period/3
   - setState: Triggers rebuild when active dot changes
   - List.generate: Dynamically creates 3 dots with computed sizes
   - AnimatedContainer: Smoothly animates size changes
   - Modulo arithmetic: (_active + 1) % 3 creates infinite cycle
   
   LIFECYCLE MANAGEMENT:
   
   - initState: Creates and starts periodic timer
   - dispose: Cancels timer to prevent memory leaks
   - mounted check: Prevents setState on disposed widget
   
   ANIMATION MATH:
   
   - Period: Total cycle time (e.g., 900ms)
   - Per Dot: period / 3 (e.g., 300ms each)
   - Sequence: 0→1→2→0... (modulo 3 wrap-around)
   - Size Multiplier: 1.0 (normal) or 1.8 (pulsing)
   
   CONNECTIONS TO OTHER FILES:
   
   - Could be used in:
     - screens/splash_screen.dart: Initial loading
     - screens/homescreen.dart: Fetching routes
     - screens/maptracking.dart: Loading map tiles
     - Any screen showing loading state
   
   - Similar to but distinct from:
     - CircularProgressIndicator (Material spinner)
     - LinearProgressIndicator (Progress bar)
   
   ADVANTAGES OVER CIRCULAR INDICATOR:
   
   - More Subtle: Less visually dominant
   - More Elegant: Modern, refined appearance
   - Better for Small Spaces: Compact horizontal layout
   - Customizable: Size and color easily adjusted
   - Unique: Distinctive brand identity vs standard spinner
   
   PERFORMANCE CONSIDERATIONS:
   
   - Lightweight: Only rebuilds Row and 3 containers
   - Efficient: AnimatedContainer uses implicit animations (GPU-accelerated)
   - No Layout Changes: Size changes don't affect surrounding widgets (MainAxisSize.min)
   - Timer Overhead: Minimal (3 ticks per period)
   
   ACCESSIBILITY:
   
   - No Semantic Label: Could add for screen readers
   - Color Contrast: 80% opacity might be insufficient for some backgrounds
   - No Progress Value: Indeterminate (doesn't show completion percentage)
   
   POTENTIAL ISSUES / FUTURE ENHANCEMENTS:
   
   - No pause/resume: Animation runs continuously (could add control)
   - No completion state: Could add final state animation
   - No accessibility label: Screen readers don't announce loading state
   - Fixed opacity: 80% might not work on all backgrounds (could parameterize)
   - Fixed multiplier: 1.8x might not suit all sizes (could parameterize)
   - No RTL support: Dots always pulse left-to-right (could reverse for RTL)
   - No color animation: Could pulse color instead of/in addition to size
   - Timer not paused: Continues animating even when off-screen (minor battery drain)
   - No error state: Could show different appearance on error
   - Single row only: Could add vertical or grid layouts
   
   ALTERNATIVE IMPLEMENTATIONS:
   
   - Could use AnimationController for more control
   - Could use TweenAnimationBuilder for simpler code
   - Could use rotating transformation instead of size
   - Could use opacity instead of size
   - Could use multiple simultaneous pulses
   
   This widget demonstrates excellent Flutter practices:
   - Clear separation of configuration (widget) and state
   - Proper lifecycle management (timer cleanup)
   - Safety checks (mounted guard)
   - Sensible defaults with customization options
   - Efficient animations (AnimatedContainer)
   - Clean, readable code
   
   It's a simple but well-crafted component that enhances UX with subtle,
   elegant loading feedback. Perfect for situations where CircularProgressIndicator
   would be too heavy-handed or visually dominating.
*/
