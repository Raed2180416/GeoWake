// Annotated copy of lib/widgets/pulsing_dots.dart
// Purpose: Document animated loading indicator widget with pulsing dot animation.

import 'dart:async'; // For Timer periodic updates
import 'package:flutter/material.dart'; // Flutter UI framework

class PulsingDots extends StatefulWidget { // Animated loading indicator with three pulsing dots
  final double size; // Base size of each dot in logical pixels
  final Color color; // Color of the dots
  final Duration period; // Total duration of the full pulse cycle (all 3 dots)
  const PulsingDots({ // Constructor with optional parameters and defaults
    super.key, // Optional widget key for optimization
    this.size = 8, // Default dot size is 8 logical pixels
    this.color = Colors.grey, // Default color is grey (neutral for any theme)
    this.period = const Duration(milliseconds: 900) // Default full cycle is 900ms
  }); // End constructor

  @override
  State<PulsingDots> createState() => _PulsingDotsState(); // Create mutable state
} // End PulsingDots

class _PulsingDotsState extends State<PulsingDots> { // Private state class for animation management
  int _active = 0; // Index of currently pulsing dot (0, 1, or 2)
  Timer? _timer; // Periodic timer for animation updates

  @override
  void initState() { // Initialize state when widget is first created
    super.initState(); // Call parent implementation
    // Create periodic timer that fires every 1/3 of the total period
    // This means each dot pulses for 1/3 of the total cycle time
    _timer = Timer.periodic(widget.period ~/ 3, (_) { // Timer fires every period/3 milliseconds
      if (!mounted) return; // Safety check - don't update if widget is disposed
      setState(() => _active = (_active + 1) % 3); // Cycle through dots 0 → 1 → 2 → 0
    }); // End Timer.periodic
  } // End initState

  @override
  void dispose() { // Clean up when widget is removed from tree
    _timer?.cancel(); // Cancel timer to prevent memory leaks and unnecessary updates
    super.dispose(); // Call parent implementation
  } // End dispose

  @override
  Widget build(BuildContext context) { // Build UI
    // Calculate size for each dot: active dot is 1.8x larger, inactive dots are base size
    final sizes = List<double>.generate(3, (i) => i == _active ? widget.size * 1.8 : widget.size);
    // Sizes list example: if _active=1, sizes=[8.0, 14.4, 8.0]
    
    return Row( // Horizontal layout for three dots
      mainAxisSize: MainAxisSize.min, // Only take as much width as needed (not stretch)
      children: List.generate(3, (i) => AnimatedContainer( // Generate 3 animated dot containers
        duration: widget.period ~/ 3, // Animation duration matches timer period (smooth transition)
        margin: const EdgeInsets.symmetric(horizontal: 3), // 3 pixels of space between dots
        width: sizes[i], // Width matches calculated size (changes when this dot becomes active)
        height: sizes[i], // Height matches width (keeps dots circular)
        decoration: BoxDecoration( // Visual styling
          color: widget.color.withOpacity(0.8), // Semi-transparent dot color (80% opacity)
          shape: BoxShape.circle, // Circular shape
        ), // End BoxDecoration
      )), // End AnimatedContainer and List.generate
    ); // End Row
  } // End build
} // End _PulsingDotsState

/* File summary: pulsing_dots.dart provides a reusable animated loading indicator widget displaying three dots
   that pulse in sequence. The animation is driven by a periodic timer that updates the active dot index every
   period/3 milliseconds. The active dot smoothly scales to 1.8x its base size using AnimatedContainer, creating
   a wave effect across the three dots. The widget is highly customizable through constructor parameters: size
   (base dot diameter), color (dot color), and period (full cycle duration). Default values (8px, grey, 900ms)
   work well for most use cases. The widget properly cleans up its timer in dispose() to prevent memory leaks.
   The mounted check in the timer callback prevents setState calls on disposed widgets. The semi-transparent
   color (80% opacity) creates a softer visual effect. This widget is typically used in loading states, such as
   waiting for API responses or processing operations. The Row with mainAxisSize.min ensures the widget doesn't
   unnecessarily take up horizontal space. */
