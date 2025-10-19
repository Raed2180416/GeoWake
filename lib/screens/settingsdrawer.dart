// lib/screens/settingsdrawer.dart

import 'package:flutter/material.dart';
import '../main.dart';

// Import for ringtones screen
import 'package:geowake2/screens/ringtones_screen.dart';

 
class SettingsDrawer extends StatelessWidget {
  const SettingsDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.findAncestorStateOfType<MyAppState>();
    final isDarkMode = appState?.isDarkMode ?? false;
    final themeMode = appState?._themeMode ?? AppThemeMode.system;

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.deepPurple),
              child: Text(
                'Settings',
                style: TextStyle(
                  fontFamily: 'Pacifico', // Using fontFamily for consistency
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.brightness_6),
              title: const Text('Theme'),
              subtitle: Text(_getThemeModeLabel(themeMode)),
              onTap: () {
                _showThemeModeDialog(context, appState);
              },
            ),
            ListTile(
              leading: const Icon(Icons.alarm),
              title: const Text('Alarm Ringtones'),
              // --- STEP 2: UPDATE THIS onTap FUNCTION ---
              onTap: () {
                // This closes the drawer before navigating to the new screen
                // for a smoother user experience.
                Navigator.of(context).pop();
                
                // This is the command that pushes the RingtonesScreen onto the view.
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => const RingtonesScreen(),
                ));
              },
            ),
            ListTile(
              leading: const Icon(Icons.star),
              title: const Text('Go Premium'),
              onTap: () {
                // Implement premium purchase flow
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Close'),
              onTap: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  String _getThemeModeLabel(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.system:
        return 'System Default';
      case AppThemeMode.light:
        return 'Light';
      case AppThemeMode.dark:
        return 'Dark';
    }
  }

  void _showThemeModeDialog(BuildContext context, MyAppState? appState) {
    if (appState == null) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: AppThemeMode.values.map((mode) {
            return RadioListTile<AppThemeMode>(
              title: Text(_getThemeModeLabel(mode)),
              value: mode,
              groupValue: appState._themeMode,
              onChanged: (value) {
                if (value != null) {
                  appState.setThemeMode(value);
                  Navigator.pop(context);
                  Navigator.pop(context); // Close drawer
                }
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}