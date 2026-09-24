import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medal/widgets/medal_app_bar.dart';
import 'package:medal/modules/citizen/screens/tracker.dart';
import 'package:medal/modules/citizen/screens/academy.dart';
import 'package:medal/modules/citizen/screens/feed.dart';
import 'package:medal/modules/citizen/screens/report.dart';
import 'package:medal/modules/citizen/screens/profile.dart';

void main() {
  testWidgets('MedalAppBar renders brand logo, title, and notification bell',
      (WidgetTester tester) async {
    bool notificationTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: MedalAppBar(
            onNotificationPressed: () {
              notificationTapped = true;
            },
          ),
          body: const Center(child: Text("Test Body")),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify MEDAL typography
    expect(find.text('MEdAL'), findsOneWidget);

    // Verify Medal ribbon/icon
    expect(find.byIcon(Icons.military_tech_rounded), findsOneWidget);

    // Verify Notification bell icon
    expect(find.byIcon(Icons.notifications), findsOneWidget);

    // Tap notification bell
    await tester.tap(find.byIcon(Icons.notifications));
    expect(notificationTapped, isTrue);
  });

  testWidgets('TrackerScreen has MedalAppBar and Status Tracker title below it',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TrackerScreen(),
      ),
    );
    await tester.pump();

    // Verify MedalAppBar is present
    expect(find.byType(MedalAppBar), findsOneWidget);
    expect(find.text('MEdAL'), findsOneWidget);
    expect(find.byIcon(Icons.military_tech_rounded), findsOneWidget);
    expect(find.byIcon(Icons.notifications), findsOneWidget);

    // Verify "Status Tracker" page title is present below the common header
    expect(find.text('Status Tracker'), findsOneWidget);

    // Verify Search bar is present
    expect(find.text('Search your complaints...'), findsOneWidget);
  });

  testWidgets('AcademyScreen has MedalAppBar and Academy title below it',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AcademyScreen(),
      ),
    );
    await tester.pump();

    // Verify MedalAppBar is present
    expect(find.byType(MedalAppBar), findsOneWidget);
    expect(find.text('MEdAL'), findsOneWidget);

    // Verify "Academy" page title is present below the common header
    expect(find.text('Academy'), findsOneWidget);

    // Verify Search bar and Categories are present
    expect(find.text('Search courses, SDGs or skills...'), findsOneWidget);
    expect(find.text('Categories'), findsOneWidget);
  });

  testWidgets('FeedScreen has MedalAppBar and filter tabs below it',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: FeedScreen(),
      ),
    );
    await tester.pump();

    // Verify MedalAppBar is present
    expect(find.byType(MedalAppBar), findsOneWidget);
    expect(find.text('MEdAL'), findsOneWidget);

    // Verify filter chips
    expect(find.text('All Reports'), findsOneWidget);
    expect(find.text('Environmental'), findsOneWidget);
    expect(find.text('Infrastructure'), findsOneWidget);
  });

  testWidgets('ReportScreen has MedalAppBar and Citizen Civic Report title',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ReportScreen(),
      ),
    );
    await tester.pump();

    // Verify MedalAppBar is present
    expect(find.byType(MedalAppBar), findsOneWidget);
    expect(find.text('MEdAL'), findsOneWidget);

    // Verify page title
    expect(find.text('Citizen Civic Report'), findsOneWidget);
  });

  testWidgets('ProfileScreen has MedalAppBar and My Profile title',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ProfileScreen(),
      ),
    );
    await tester.pump();

    // Verify MedalAppBar is present
    expect(find.byType(MedalAppBar), findsOneWidget);
    expect(find.text('MEdAL'), findsOneWidget);

    // Verify page title
    expect(find.text('My Profile'), findsOneWidget);
  });
}
