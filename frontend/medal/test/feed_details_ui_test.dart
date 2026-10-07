import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medal/modules/citizen/screens/feed_details.dart';
import 'package:medal/widgets/post_comment_section.dart';

void main() {
  testWidgets('FeedDetailScreen displays Upvote (not Like), Comments, and Report with real counts',
      (WidgetTester tester) async {
    final mockFeedData = {
      'id': 101,
      'title': 'Broken Water Pipe',
      'description': 'Water leaking near main road intersection.',
      'citizen_name': 'Saicharan',
      'citizen_initials': 'SC',
      'created_at': '2026-09-21T09:00:00Z',
      'status': 'submitted',
      'location': 'Ward 12, Main Street',
      'upvotes_count': 7,
      'comments_count': 3,
      'reports_count': 0,
      'has_upvoted': false,
      'sdg_alignment': 'SDG 6',
      'assigned_authority': 'Ward Water Engineer',
      'department': 'Water & Sanitation Department',
    };

    await tester.pumpWidget(
      MaterialApp(
        home: FeedDetailScreen(feedData: mockFeedData),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Verify "Upvote" is present and "Like" is NOT present
    expect(find.text('Upvote'), findsOneWidget);
    expect(find.text('Like'), findsNothing);

    // 2. Verify "Comments" and action button "Report" are present
    expect(find.text('Comments'), findsOneWidget);
    expect(find.widgetWithText(InkWell, 'Report'), findsOneWidget);

    // 3. Verify real counts are displayed
    expect(find.text('7'), findsOneWidget); // upvotes
    expect(find.text('3'), findsOneWidget); // comments
    expect(find.text('0'), findsOneWidget); // reports

    // 4. Verify complaint details header elements
    expect(find.text('Broken Water Pipe'), findsOneWidget);
    expect(find.text('Saicharan'), findsOneWidget);
    expect(find.text('SC'), findsOneWidget);
    expect(find.text('SUBMITTED'), findsOneWidget);
    expect(find.text('Ward 12, Main Street'), findsOneWidget);

    // 5. Verify icons for Upvote, Comments, and Report exist
    expect(find.byIcon(Icons.thumb_up_alt_outlined), findsOneWidget);
    expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);
    expect(find.byIcon(Icons.flag_outlined), findsOneWidget);

    // 6. Verify SDG Badge is rendered (and Tracker in bottom nav also uses track_changes)
    expect(find.text('SDG 6'), findsOneWidget);
    expect(find.byIcon(Icons.track_changes), findsNWidgets(2));

    // 7. Verify Assigned Authority card
    expect(find.text('Assigned Authority'), findsOneWidget);
    expect(find.text('Ward Water Engineer'), findsOneWidget);
    expect(find.text('Water & Sanitation Department'), findsOneWidget);

    // 8. Verify Progress Timeline card
    expect(find.text('Progress Timeline'), findsOneWidget);
    expect(find.text('Complaint Submitted'), findsOneWidget);
    expect(find.text('Assigned To Officer'), findsOneWidget);
    expect(find.text('Work In Progress'), findsOneWidget);

    // 9. Verify PostCommentSection is rendered
    expect(find.byType(PostCommentSection), findsOneWidget);
  });

  testWidgets('FeedDetailScreen Report button increments report count',
      (WidgetTester tester) async {
    final mockFeedData = {
      'id': 102,
      'title': 'Pothole Alert',
      'description': 'Deep road depression.',
      'citizen_name': 'Citizen One',
      'citizen_initials': 'CO',
      'created_at': '2026-09-21T09:00:00Z',
      'status': 'in_progress',
      'location': 'Tambaram Road',
      'upvotes_count': 12,
      'comments_count': 5,
      'reports_count': 2,
      'has_upvoted': false,
    };

    await tester.pumpWidget(
      MaterialApp(
        home: FeedDetailScreen(feedData: mockFeedData),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2'), findsOneWidget);

    // Tap report button
    await tester.tap(find.widgetWithText(InkWell, 'Report'));
    await tester.pump();

    // Verify count incremented to 3
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Report flagged for civic moderation review.'), findsOneWidget);
  });

  testWidgets('FeedDetailScreen does not open Mark as Resolved dialog on tapping status badge',
      (WidgetTester tester) async {
    final mockFeedData = {
      'id': 103,
      'title': 'Streetlight Broken',
      'description': 'Streetlight not working.',
      'citizen_name': 'Citizen Two',
      'citizen_initials': 'CT',
      'created_at': '2026-09-21T09:00:00Z',
      'status': 'submitted',
      'location': 'Anna Nagar',
    };

    await tester.pumpWidget(
      MaterialApp(
        home: FeedDetailScreen(feedData: mockFeedData),
      ),
    );
    await tester.pumpAndSettle();

    // Verify SUBMITTED is shown
    expect(find.text('SUBMITTED'), findsOneWidget);

    // Tap on SUBMITTED badge
    await tester.tap(find.text('SUBMITTED'));
    await tester.pump();

    // Verify "Mark as Resolved" and "Status update" dialogs are NOT opened
    expect(find.text('Mark as Resolved'), findsNothing);
    expect(find.text('Status update'), findsNothing);
  });
}

