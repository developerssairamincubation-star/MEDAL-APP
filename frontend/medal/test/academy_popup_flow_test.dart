import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medal/modules/citizen/screens/home.dart';
import 'package:medal/modules/citizen/screens/academy.dart';
import 'package:medal/modules/citizen/screens/components.dart';
import 'package:medal/modules/citizen/screens/feed.dart';

void main() {
  group('Post-Login Academy Popup Flow Tests', () {
    testWidgets('HomeScreen renders the approved Level Up Your Impact popup UI',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify the popup title, description, and school icon
      expect(find.text("Level Up Your Impact"), findsOneWidget);
      expect(
        find.text(
            "Join our new Academy module to learn how to create more effective reports and drive real community change."),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.school), findsOneWidget);

      // Verify both action buttons
      expect(find.text("Explore Academy"), findsOneWidget);
      expect(find.text("No Thanks"), findsOneWidget);
    });

    testWidgets(
        'MainScreen with showAcademyPopup: true mounts Feed in background and shows dimmed/blurred popup',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MainScreen(showAcademyPopup: true),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify FeedScreen is in the widget tree behind the popup
      expect(find.byType(FeedScreen), findsOneWidget);

      // 2. Verify BackdropFilter blur overlay is active
      expect(find.byType(BackdropFilter), findsWidgets);

      // 3. Verify popup is rendered on top of Feed
      expect(find.text("Level Up Your Impact"), findsOneWidget);
      expect(find.text("Explore Academy"), findsOneWidget);
      expect(find.text("No Thanks"), findsOneWidget);
    });

    testWidgets(
        'Modal popup on MainScreen: tapping Explore Academy navigates to AcademyScreen',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MainScreen(showAcademyPopup: true),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Level Up Your Impact"), findsOneWidget);

      // Tap Explore Academy
      final exploreBtn = find.text("Explore Academy");
      await tester.tap(exploreBtn);
      await tester.pumpAndSettle();

      // Verify AcademyScreen is now displayed and popup is dismissed
      expect(find.byType(AcademyScreen), findsOneWidget);
      expect(find.text("Level Up Your Impact"), findsNothing);
    });

    testWidgets(
        'Modal popup on MainScreen: tapping No Thanks dismisses popup and reveals active Feed without duplicates',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MainScreen(showAcademyPopup: true),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Level Up Your Impact"), findsOneWidget);

      // Tap No Thanks
      final noThanksBtn = find.text("No Thanks");
      await tester.tap(noThanksBtn);
      await tester.pumpAndSettle();

      // Verify popup is dismissed and user is on MainScreen / Feed
      expect(find.text("Level Up Your Impact"), findsNothing);
      expect(find.byType(MainScreen), findsOneWidget);
      expect(find.byType(FeedScreen), findsOneWidget);
    });

    testWidgets(
        'Tapping Explore Academy from HomeScreen navigates to AcademyScreen and clears the popup',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(AcademyScreen), findsNothing);

      final exploreBtn = find.text("Explore Academy");
      await tester.tap(exploreBtn);
      await tester.pumpAndSettle();

      expect(find.byType(AcademyScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
    });

    testWidgets(
        'Tapping No Thanks from HomeScreen navigates to MainScreen (Feed) and clears the popup',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(MainScreen), findsNothing);

      final noThanksBtn = find.text("No Thanks");
      await tester.tap(noThanksBtn);
      await tester.pumpAndSettle();

      expect(find.byType(MainScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
    });
  });
}
