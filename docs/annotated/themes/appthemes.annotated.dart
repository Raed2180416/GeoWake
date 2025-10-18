// Annotated copy of lib/themes/appthemes.dart
// Purpose: Document theme definitions for consistent UI styling across the app in light and dark modes.

import 'package:flutter/material.dart'; // Flutter UI framework and Material Design
import 'package:google_fonts/google_fonts.dart'; // Google Fonts package for Montserrat font

class AppThemes { // Static class containing theme definitions
  // Light Theme - for daytime use or user preference
  // Uses bright, high-contrast colors for readability in well-lit environments
  static final ThemeData lightTheme = ThemeData( // Light theme configuration
    useMaterial3: true, // Enable Material 3 design system (latest version with updated components)
    brightness: Brightness.light, // Indicates this is a light theme for system UI integration
    primarySwatch: Colors.deepPurple, // Deep purple as the primary color family
    scaffoldBackgroundColor: Colors.white, // Pure white background for all screens
    textTheme: GoogleFonts.montserratTextTheme(), // Apply Montserrat font to all text widgets
    inputDecorationTheme: InputDecorationTheme( // Consistent styling for all text input fields
      fillColor: Colors.grey[200], // Light grey fill for input fields (subtle contrast)
      filled: true, // Enable fill color (makes input fields visually distinct)
      border: OutlineInputBorder( // Rounded border styling
        borderRadius: BorderRadius.circular(24), // Heavily rounded corners (pill shape)
        borderSide: BorderSide.none, // No visible border (relies on fill color for definition)
      ), // End OutlineInputBorder
      hintStyle: const TextStyle(color: Colors.black54), // Hint text color (medium grey for readability)
      prefixIconColor: Colors.black54, // Icon color inside input fields (matches hint text)
    ), // End InputDecorationTheme
  ); // End lightTheme

  // Dark Theme - for nighttime use or user preference
  // Uses darker colors to reduce eye strain in low-light environments
  static final ThemeData darkTheme = ThemeData( // Dark theme configuration
    useMaterial3: true, // Enable Material 3 design system (consistent with light theme)
    brightness: Brightness.dark, // Indicates this is a dark theme for system UI integration
    primarySwatch: Colors.deepPurple, // Same primary color as light theme (brand consistency)
    scaffoldBackgroundColor: const Color(0xFF303030), // Dark grey background (not pure black for less contrast)
    textTheme: GoogleFonts.montserratTextTheme( // Apply Montserrat font family
      const TextTheme( // Override specific text styles for dark mode
        bodyMedium: TextStyle(color: Colors.white), // Body text in white for contrast
      ), // End TextTheme
    ), // End montserratTextTheme
    appBarTheme: const AppBarTheme( // App bar styling for dark mode
      backgroundColor: Color(0xFF303030), // Match scaffold background (seamless appearance)
      foregroundColor: Colors.white, // White text and icons in app bar
      elevation: 0, // No shadow (flat design aesthetic)
    ), // End AppBarTheme
    inputDecorationTheme: InputDecorationTheme( // Input field styling for dark mode
      fillColor: const Color(0xFF424242), // Slightly lighter grey for input fields (contrast with background)
      filled: true, // Enable fill color
      border: OutlineInputBorder( // Rounded border styling (same as light theme)
        borderRadius: BorderRadius.circular(24), // Heavily rounded corners (pill shape)
        borderSide: BorderSide.none, // No visible border (relies on fill color)
      ), // End OutlineInputBorder
      hintStyle: const TextStyle(color: Colors.white60), // Hint text in translucent white (softer appearance)
      prefixIconColor: Colors.white70, // Icon color slightly more opaque than hint text
    ), // End InputDecorationTheme
  ); // End darkTheme
} // End AppThemes

/* File summary: appthemes.dart defines consistent visual styling for the entire GeoWake application through light
   and dark theme configurations. Both themes use Material 3 design system and Montserrat font for a modern,
   polished appearance. The light theme uses white backgrounds with grey input fields for daytime readability.
   The dark theme uses dark grey (#303030) backgrounds with slightly lighter input fields (#424242) to reduce
   eye strain in low-light conditions. Input fields in both themes use heavily rounded corners (24px radius) for
   a friendly, modern aesthetic. Colors are carefully chosen for accessibility: sufficient contrast between text
   and backgrounds, and distinct input field colors. The primarySwatch (deep purple) is consistent across both
   themes for brand recognition. The themes are referenced in main.dart and can be toggled by the user via
   the toggleTheme() method in MyAppState. */
