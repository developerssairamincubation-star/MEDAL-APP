import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medal/modules/citizen/screens/components.dart';
import 'package:medal/modules/citizen/screens/report.dart';

void main() {
  testWidgets(
      'Citizen reporting exit alert is shown on center close button and respects No / Yes',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MainScreen(initialIndex: 2),
      ),
    );
    await tester.pump();

    // Verify user is on ReportScreen
    expect(find.byType(ReportScreen), findsOneWidget);
    expect(find.text('Cancel Reporting'), findsNothing);

    // Tap the floating center close button (✕)
    final closeIconFinder = find.byIcon(Icons.close);
    expect(closeIconFinder, findsOneWidget);
    await tester.tap(closeIconFinder);
    await tester.pump(const Duration(milliseconds: 300));

    // Verify the "Cancel Reporting" dialog is displayed
    expect(find.text('Cancel Reporting'), findsOneWidget);
    expect(
      find.text(
        'Are you sure to exit the reporting page? The changes you have made will not be saved.',
      ),
      findsOneWidget,
    );
    expect(find.text('No'), findsOneWidget);
    expect(find.text('Yes'), findsOneWidget);

    // Tap "No" -> dialog closes, user remains on ReportScreen
    await tester.tap(find.text('No'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Cancel Reporting'), findsNothing);
    expect(find.byType(ReportScreen), findsOneWidget);

    // Tap the center close button again
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump(const Duration(milliseconds: 300));

    // Tap "Yes" -> dialog closes and user exits to Feed
    await tester.tap(find.text('Yes'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Cancel Reporting'), findsNothing);
    expect(find.byType(ReportScreen), findsNothing);
  });

  testWidgets(
      'Citizen reporting exit alert is shown when tapping another tab and AppBar back arrow',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MainScreen(initialIndex: 2),
      ),
    );
    await tester.pump();

    // Tap the TRACKER tab
    await tester.tap(find.text('TRACKER'));
    await tester.pump(const Duration(milliseconds: 300));

    // Alert dialog should be visible
    expect(find.text('Cancel Reporting'), findsOneWidget);

    // Dismiss with "No"
    await tester.tap(find.text('No'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(ReportScreen), findsOneWidget);

    // Tap the top AppBar back arrow
    final backArrow = find.byIcon(Icons.arrow_back);
    expect(backArrow, findsOneWidget);
    await tester.tap(backArrow);
    await tester.pump(const Duration(milliseconds: 300));

    // Alert dialog should appear again
    expect(find.text('Cancel Reporting'), findsOneWidget);
    await tester.tap(find.text('Yes'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(ReportScreen), findsNothing);
  });
}
