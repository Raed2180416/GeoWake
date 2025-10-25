// Annotated copy of lib/themes/appthemes.dart
// Purpose: Application-wide theme definitions for light and dark modes.
// This file centralizes all visual styling to ensure consistent UI across the entire app.

import 'package:flutter/material.dart'; // Flutter Material Design library - ThemeData, Colors, TextStyle, etc.
import 'package:google_fonts/google_fonts.dart'; // Google Fonts plugin - provides Montserrat and 1000+ other fonts

// ═══════════════════════════════════════════════════════════════════════════
// APP THEMES CLASS
// ═══════════════════════════════════════════════════════════════════════════
class AppThemes { // Static container for theme definitions
  // All members are static - no instance needed, acts as namespace
  // Provides two complete theme configurations: light and dark
  // Themes are immutable (final) - defined once, never changed at runtime

  // ═══════════════════════════════════════════════════════════════════════════
  // LIGHT THEME
  // ═══════════════════════════════════════════════════════════════════════════
  static final ThemeData lightTheme = ThemeData( // Light color scheme theme
    // ThemeData is Flutter's master theme configuration object
    // Contains styling for every widget type (buttons, text fields, cards, etc.)
    // All descendant widgets inherit these styles automatically
    
    useMaterial3: true, // Material 3 integration
    // Material 3 is Google's latest design system (2021+)
    // Enables modern features: color roles, dynamic color, elevation overlays
    // Provides more refined default styles compared to Material 2
    // true = use Material 3 components (recommended for new apps)
    // false = use legacy Material 2 components
    
    brightness: Brightness.light, // Light mode indicator
    // Tells Flutter this is a light theme (bright background, dark text)
    // Affects automatic color calculations and system UI (status bar)
    // Brightness.light = light background, Brightness.dark = dark background
    
    primarySwatch: Colors.deepPurple, // Primary color palette
    // MaterialColor with multiple shades (50, 100, 200, ... 900)
    // deepPurple = purple-ish blue color (#673AB7)
    // Used for:
    //   - Primary buttons (FloatingActionButton, ElevatedButton)
    //   - AppBar background (if not overridden)
    //   - Progress indicators, switches, sliders
    //   - Selected items, active states
    // Flutter auto-generates light/dark variants from swatch
    
    scaffoldBackgroundColor: Colors.white, // Default screen background
    // Applied to Scaffold widget (base of most screens)
    // Pure white (#FFFFFF) for clean, bright appearance
    // Provides high contrast with dark text
    // Alternative options: Colors.grey[50] (off-white), Colors.grey[100] (light gray)
    
    textTheme: GoogleFonts.montserratTextTheme(), // Montserrat for all text
    // Applies Montserrat font to all text in the app
    // Montserrat is a modern geometric sans-serif font
    // Clean, professional appearance, good readability
    // montserratTextTheme() generates complete TextTheme with all text styles
    // Google Fonts plugin downloads font on first use, caches locally
    // Replaces default system font (Roboto on Android, San Francisco on iOS)
    
    inputDecorationTheme: InputDecorationTheme( // Text field styling
      // Applies to TextField, TextFormField, and all input widgets
      // Defines border, fill color, hint style, padding, etc.
      
      fillColor: Colors.grey[200], // Input field background color
      // Light gray (#EEEEEE) provides subtle contrast against white background
      // Makes input fields clearly distinguishable from surrounding content
      // Soft color reduces eye strain compared to pure white
      
      filled: true, // Enable background fill
      // true = use fillColor as background
      // false = transparent background (only border visible)
      // Filled inputs are more prominent and easier to tap
      
      border: OutlineInputBorder( // Input field border style
        // OutlineInputBorder draws border around entire field (vs underline)
        
        borderRadius: BorderRadius.circular(24), // Rounded corners
        // 24 logical pixels corner radius (half of typical field height)
        // Creates pill-shaped fields (very rounded)
        // Modern, friendly appearance (vs sharp corners)
        // Consistent with Material 3 rounded aesthetic
        
        borderSide: BorderSide.none, // No visible border
        // Remove border line - filled background is sufficient for visual separation
        // Cleaner appearance, reduces visual noise
        // Border only appears on focus (default Material behavior)
      ), // End OutlineInputBorder
      
      hintStyle: const TextStyle(color: Colors.black54), // Placeholder text color
      // black54 = 54% opacity black (#8A000000)
      // Subtle gray that indicates "this is not real content"
      // Dark enough to read, light enough to distinguish from input text
      // Hints disappear when user starts typing
      
      prefixIconColor: Colors.black54, // Leading icon color (e.g., search icon)
      // Matches hint text color for visual consistency
      // Icons appear before input text (left side in LTR languages)
      // 54% opacity provides subtle appearance
    ), // End InputDecorationTheme
  ); // End lightTheme
  // Block summary: Light theme provides bright, clean appearance with deep purple accents.
  // Uses Montserrat font for modern typography and rounded input fields for friendly UI.
  // Material 3 integration ensures modern design standards.

  // ═══════════════════════════════════════════════════════════════════════════
  // DARK THEME
  // ═══════════════════════════════════════════════════════════════════════════
  static final ThemeData darkTheme = ThemeData( // Dark color scheme theme
    // Dark themes reduce eye strain in low-light environments
    // Also saves battery on OLED screens (black pixels = off pixels)
    
    useMaterial3: true, // Material 3 integration
    // Consistent with light theme - both use Material 3
    
    brightness: Brightness.dark, // Dark mode indicator
    // Tells Flutter this is a dark theme (dark background, light text)
    // System UI (status bar, navigation bar) adapts to dark appearance
    
    primarySwatch: Colors.deepPurple, // Primary color palette
    // Same as light theme - maintains brand consistency across themes
    // Purple accents work well on both light and dark backgrounds
    
    scaffoldBackgroundColor: const Color(0xFF303030), // Default screen background
    // Dark gray (#303030) instead of pure black
    // Pure black (#000000) can cause:
    //   - Smearing on OLED screens
    //   - Excessive contrast (harsh on eyes)
    //   - Difficulty distinguishing layered surfaces
    // 0xFF303030 breakdown:
    //   - 0xFF = full opacity
    //   - 30 30 30 = RGB values (48, 48, 48 in decimal)
    // Very dark but not pure black - easier on eyes
    
    textTheme: GoogleFonts.montserratTextTheme( // Montserrat font with dark text colors
      const TextTheme( // Base text theme with light colors
        bodyMedium: TextStyle(color: Colors.white), // Default body text color
        // bodyMedium is the most common text style (regular paragraphs)
        // White text on dark background provides high contrast
        // Other text styles (headline, caption, etc.) inherit from this base
      ), // End TextTheme
    ), // montserratTextTheme applies Montserrat to the provided TextTheme
    // Result: Montserrat font with white text color
    
    appBarTheme: const AppBarTheme( // Top app bar styling
      // AppBar is the header at top of most screens (title, back button, actions)
      
      backgroundColor: Color(0xFF303030), // AppBar background color
      // Same as scaffold background - creates seamless appearance
      // AppBar blends into screen rather than standing out
      // Modern "floating header" aesthetic
      
      foregroundColor: Colors.white, // AppBar text/icon color
      // White text and icons for visibility on dark background
      // Includes:
      //   - Title text
      //   - Back button icon
      //   - Action buttons (more_vert, search, etc.)
      
      elevation: 0, // No shadow under AppBar
      // elevation = 0 removes drop shadow
      // Creates flat, modern appearance (vs Material 2 default shadow)
      // Consistent with Material 3 "surface tint" instead of shadows
      // Makes AppBar blend seamlessly with screen content
    ), // End AppBarTheme
    
    inputDecorationTheme: InputDecorationTheme( // Text field styling for dark theme
      // Same structure as light theme but with dark colors
      
      fillColor: const Color(0xFF424242), // Input field background color
      // Lighter gray (#424242) than scaffold (#303030)
      // Creates subtle elevation effect (elevated surfaces are lighter in dark themes)
      // 0xFF424242 = RGB(66, 66, 66)
      // Provides clear visual separation from background
      
      filled: true, // Enable background fill
      // Same as light theme - filled inputs are easier to identify
      
      border: OutlineInputBorder( // Input field border style
        borderRadius: BorderRadius.circular(24), // Rounded corners
        // Same radius as light theme - consistent UX across themes
        
        borderSide: BorderSide.none, // No visible border
        // Same as light theme - rely on fill color for separation
      ), // End OutlineInputBorder
      
      hintStyle: const TextStyle(color: Colors.white60), // Placeholder text color
      // white60 = 60% opacity white (#99FFFFFF)
      // Lighter than input text but still readable
      // 60% opacity provides good contrast on dark background
      
      prefixIconColor: Colors.white70, // Leading icon color
      // white70 = 70% opacity white (#B3FFFFFF)
      // Slightly more prominent than hints (icons are important navigation cues)
      // Still subtle enough to not compete with input content
    ), // End InputDecorationTheme
  ); // End darkTheme
  // Block summary: Dark theme provides comfortable low-light viewing with same purple accents.
  // Uses dark gray backgrounds (not pure black) and white text for optimal contrast.
  // AppBar elevation removed for modern flat design.
} // End AppThemes class

/* ═══════════════════════════════════════════════════════════════════════════
   FILE SUMMARY: appthemes.dart - Application Theme Definitions
   ═══════════════════════════════════════════════════════════════════════════
   
   This file defines the visual appearance of the entire GeoWake application.
   It provides two complete themes (light and dark) that style every widget,
   ensuring consistent UI throughout the app.
   
   TWO THEMES PROVIDED:
   
   1. Light Theme (AppThemes.lightTheme):
      - White background (#FFFFFF)
      - Deep purple accents (#673AB7)
      - Montserrat font (modern geometric sans-serif)
      - Light gray input fields (#EEEEEE)
      - Black text with 54% opacity hints
      - Material 3 modern design
   
   2. Dark Theme (AppThemes.darkTheme):
      - Dark gray background (#303030, not pure black)
      - Deep purple accents (#673AB7, same as light)
      - Montserrat font (consistent across themes)
      - Slightly lighter input fields (#424242)
      - White text with 60% opacity hints
      - Flat AppBar (no shadow)
      - Material 3 modern design
   
   KEY DESIGN DECISIONS:
   
   - Material 3: Modern design system with refined components
   - Consistent Colors: Same primary swatch (deep purple) across themes
   - Typography: Montserrat font for clean, professional appearance
   - Rounded Inputs: 24px border radius for friendly, approachable UI
   - Filled Fields: Background color makes inputs prominent and easy to tap
   - No Borders: Clean appearance relies on fill color for separation
   - Dark Gray: #303030 instead of #000000 reduces eye strain and smearing
   - Flat AppBar: No shadow in dark theme for modern aesthetic
   
   WIDGET STYLING COVERAGE:
   
   - Scaffold: Background color for all screens
   - AppBar: Header styling (dark theme only, light uses defaults)
   - TextField/TextFormField: Input decoration, colors, borders
   - Text: Font family (Montserrat) and colors
   - Buttons: Primary color from swatch (automatic)
   - Progress Indicators: Primary color from swatch (automatic)
   - All other widgets: Inherit from ThemeData defaults
   
   CONNECTIONS TO OTHER FILES:
   
   - main.dart: Applies theme based on isDarkMode flag
     ```dart
     theme: isDarkMode ? AppThemes.darkTheme : AppThemes.lightTheme
     ```
   - All screens/*.dart: Inherit theme styles automatically
   - All widgets/*.dart: Use theme colors via Theme.of(context)
   - settingsdrawer.dart: Could provide theme toggle control
   
   THEME USAGE EXAMPLE:
   
   ```dart
   // In any widget
   final theme = Theme.of(context);
   Text('Hello', style: theme.textTheme.bodyMedium);  // Uses Montserrat
   Container(color: theme.scaffoldBackgroundColor);   // Uses white or #303030
   ```
   
   MATERIAL 3 BENEFITS:
   
   - Color Roles: Semantic colors (primary, secondary, tertiary, error, etc.)
   - Dynamic Color: Can adapt to system theme (Android 12+)
   - Refined Components: Buttons, cards, dialogs updated to modern standards
   - Elevation Overlays: Better depth perception in dark theme
   - Typography: Improved text styles with better readability
   
   COLOR ACCESSIBILITY:
   
   - Light Theme: High contrast (black on white) meets WCAG AAA
   - Dark Theme: Good contrast (white on #303030) meets WCAG AA
   - Hints: Lower opacity ensures they don't compete with content
   - Purple Accents: Sufficient contrast on both light and dark backgrounds
   
   POTENTIAL ISSUES / FUTURE ENHANCEMENTS:
   
   - No system theme detection: Could auto-switch based on OS preference
   - Theme not persisted: Resets to light on app restart (could save to Hive)
   - Limited customization: Only light/dark, no color scheme options
   - No high contrast mode: Could add for accessibility
   - AppBar style only in dark: Light theme uses defaults (could be explicit)
   - No color animation: Theme switch is instant (could add fade transition)
   - Montserrat download: First use requires network (could bundle font)
   - No RTL testing: Rounded corners might need adjustment for Arabic/Hebrew
   - No tablet optimization: Same theme for phone and tablet (could scale)
   - No brand colors: Uses default deep purple (could customize to brand)
   
   FONT CHOICE RATIONALE:
   
   Montserrat selected because:
   - Modern geometric design (friendly, approachable)
   - Excellent readability at all sizes
   - Professional appearance without being boring
   - Good letter spacing (easier to read numbers/addresses)
   - Free and widely available via Google Fonts
   - Widely used in modern apps (familiar to users)
   
   DARK THEME COLOR CHOICE:
   
   #303030 instead of #000000 because:
   - Reduces OLED smearing (pure black can smear when scrolling)
   - Less harsh contrast (easier on eyes in dark environments)
   - Follows Material Design dark theme guidelines
   - Allows layering with lighter surfaces (#424242, #525252, etc.)
   - Better visual hierarchy (pure black flattens everything)
   
   This file is the foundation of the app's visual identity. Every screen, button,
   and text field derives its appearance from these theme definitions. Changing
   colors or fonts here instantly updates the entire app. It's a critical file
   for maintaining consistent, professional UI/UX.
*/
