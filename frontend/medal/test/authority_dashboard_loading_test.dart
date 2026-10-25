// test/authority_dashboard_loading_test.dart
// Verification tests for Authority Dashboard loading behavior, error states, and tab switching.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medal/modules/authority/screens/dashboard/authority_dashboard_screen.dart';
import 'package:medal/modules/authority/screens/dashboard/authority_main_screen.dart';

void main() {
  testWidgets('AuthorityDashboardScreen renders categories and feed cards',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AuthorityDashboardScreen(
            onNavigateToComplaints: () {},
          ),
        ),
      ),
    );

    // Initial pump
    await tester.pump();
    await tester.pumpAndSettle();

    // Verify categories are rendered
    expect(find.text('All Reports'), findsOneWidget);
    expect(find.text('Environmental'), findsOneWidget);
    expect(find.text('Infrastructure'), findsOneWidget);

    // Verify the complaint feed cards appear and loading indicator is gone
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      find.text(
        'Critical waste management failure observed at the canal junction. Local community impact rising due to blockage.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Switching categories in AuthorityDashboardScreen updates feed',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AuthorityDashboardScreen(
            onNavigateToComplaints: () {},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Switch to Environmental
    await tester.tap(find.text('Environmental'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Critical waste management failure observed at the canal junction. Local community impact rising due to blockage.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Street light outage at the main intersection has been fixed. Visibility is much better now for pedestrians.',
      ),
      findsNothing,
    );

    // Switch to Infrastructure
    await tester.tap(find.text('Infrastructure'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Street light outage at the main intersection has been fixed. Visibility is much better now for pedestrians.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Critical waste management failure observed at the canal junction. Local community impact rising due to blockage.',
      ),
      findsNothing,
    );

    // Switch back to All Reports (verifies cache and immediate rendering)
    await tester.tap(find.text('All Reports'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Critical waste management failure observed at the canal junction. Local community impact rising due to blockage.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Street light outage at the main intersection has been fixed. Visibility is much better now for pedestrians.',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
      'AuthorityMainScreen preserves Dashboard feed state when switching tabs and returning',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AuthorityMainScreen(),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Dashboard post is loaded
    expect(
      find.text(
        'Critical waste management failure observed at the canal junction. Local community impact rising due to blockage.',
      ),
      findsOneWidget,
    );

    // Switch to Complaints tab
    await tester.tap(find.text('COMPLAINTS'));
    await tester.pumpAndSettle();

    expect(find.text('MY COMPLAINTS'), findsOneWidget);

    // Switch back to Dashboard tab
    await tester.tap(find.text('DASHBOARD'));
    await tester.pumpAndSettle();

    // Post card is immediately visible without getting stuck loading
    expect(
      find.text(
        'Critical waste management failure observed at the canal junction. Local community impact rising due to blockage.',
      ),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets(
      'AuthorityDashboardScreen shows empty state when feed returns 0 items',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AuthorityDashboardScreen(
            onNavigateToComplaints: () {},
            feedLoader: ({category, limit, offset}) async => [],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify empty state is displayed
    expect(find.text('No Reports Available'), findsOneWidget);
    expect(
      find.text('There are currently no civic complaints in this category.'),
      findsOneWidget,
    );
    expect(find.text('Refresh Feed'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets(
      'AuthorityDashboardScreen shows error state with Retry action on API failure',
      (WidgetTester tester) async {
    int callCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AuthorityDashboardScreen(
            onNavigateToComplaints: () {},
            feedLoader: ({category, limit, offset}) async {
              callCount++;
              if (callCount == 1) {
                throw Exception('Connection timed out while loading community feed');
              }
              return [
                {
                  'id': 999,
                  'citizen_name': 'Test Citizen',
                  'created_at': DateTime.now().toIso8601String(),
                  'status': 'in_progress',
                  'description': 'Road repair required on Sector 5 main cross.',
                  'location': 'Sector 5 cross',
                  'upvotes_count': 10,
                  'comments_count': 2,
                  'reposts_count': 1,
                  'category': 'Infrastructure',
                }
              ];
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify error state is displayed with Retry button
    expect(find.text('Unable to load feed'), findsOneWidget);
    expect(
      find.text('Connection timed out while loading community feed'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    // Tap Retry -> feedLoader is called again and recovers successfully
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Unable to load feed'), findsNothing);
    expect(
      find.text('Road repair required on Sector 5 main cross.'),
      findsOneWidget,
    );
    expect(callCount, 2);
  });
}
