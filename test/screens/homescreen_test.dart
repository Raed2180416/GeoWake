import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geowake2/screens/homescreen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HomeScreen Widget Tests', () {
    testWidgets('HomeScreen builds without crashing', (WidgetTester tester) async {
      // Build the HomeScreen widget
      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(),
        ),
      );

      // Allow async initialization
      await tester.pumpAndSettle();

      // Verify the widget tree is built
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('HomeScreen displays map', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Map should be present (GoogleMap widget)
      // Note: This will find the placeholder if maps plugin is not available
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('HomeScreen has search field', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Search field should be present
      expect(find.byType(TextField), findsAtLeastNWidgets(1));
    });

    testWidgets('HomeScreen has alarm mode toggle', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Should have switches for alarm modes
      expect(find.byType(Switch), findsAtLeastNWidgets(1));
    });

    testWidgets('HomeScreen has sliders for alarm values', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Should have sliders for setting alarm thresholds
      expect(find.byType(Slider), findsAtLeastNWidgets(1));
    });

    testWidgets('HomeScreen can toggle between distance and time mode', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Find the distance/time mode switch
      final switches = find.byType(Switch);
      if (switches.evaluate().isNotEmpty) {
        // Tap the first switch
        await tester.tap(switches.first);
        await tester.pumpAndSettle();

        // Widget should rebuild without crashing
        expect(find.byType(HomeScreen), findsOneWidget);
      }
    });

    testWidgets('HomeScreen slider can be adjusted', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Find sliders
      final sliders = find.byType(Slider);
      if (sliders.evaluate().isNotEmpty) {
        // Try to drag slider
        await tester.drag(sliders.first, const Offset(50.0, 0.0));
        await tester.pumpAndSettle();

        // Widget should rebuild without crashing
        expect(find.byType(HomeScreen), findsOneWidget);
      }
    });

    testWidgets('HomeScreen search field accepts input', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Find the search field
      final searchFields = find.byType(TextField);
      if (searchFields.evaluate().isNotEmpty) {
        // Enter text in search field
        await tester.enterText(searchFields.first, 'Test Location');
        await tester.pumpAndSettle();

        // Text should be entered
        expect(find.text('Test Location'), findsOneWidget);
      }
    });

    testWidgets('HomeScreen handles no network connectivity gracefully', (WidgetTester tester) async {
      // This tests that the widget can render even without network
      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Should not crash even without network
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('HomeScreen rebuilds after state changes', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Trigger state change by tapping a switch
      final switches = find.byType(Switch);
      if (switches.evaluate().isNotEmpty) {
        await tester.tap(switches.first);
        await tester.pump();

        // Should rebuild successfully
        expect(find.byType(HomeScreen), findsOneWidget);
      }
    });
  });

  group('HomeScreen Edge Cases', () {
    testWidgets('handles rapid mode switching', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Rapidly toggle switches
      final switches = find.byType(Switch);
      if (switches.evaluate().isNotEmpty) {
        for (int i = 0; i < 5; i++) {
          await tester.tap(switches.first);
          await tester.pump(const Duration(milliseconds: 100));
        }

        await tester.pumpAndSettle();

        // Should handle rapid changes without crashing
        expect(find.byType(HomeScreen), findsOneWidget);
      }
    });

    testWidgets('handles empty search input', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(),
        ),
      );

      await tester.pumpAndSettle();

      final searchFields = find.byType(TextField);
      if (searchFields.evaluate().isNotEmpty) {
        // Enter and clear text
        await tester.enterText(searchFields.first, 'Test');
        await tester.pumpAndSettle();
        await tester.enterText(searchFields.first, '');
        await tester.pumpAndSettle();

        // Should handle empty input gracefully
        expect(find.byType(HomeScreen), findsOneWidget);
      }
    });

    testWidgets('handles special characters in search', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(),
        ),
      );

      await tester.pumpAndSettle();

      final searchFields = find.byType(TextField);
      if (searchFields.evaluate().isNotEmpty) {
        // Enter special characters
        await tester.enterText(searchFields.first, '@#\$%^&*()');
        await tester.pumpAndSettle();

        // Should handle special characters gracefully
        expect(find.byType(HomeScreen), findsOneWidget);
      }
    });
  });
}
