import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medal/modules/citizen/screens/feed_details.dart';
import 'package:medal/widgets/comment_bottom_sheet.dart';

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
    expect(find.text('Upvote (7)'), findsOneWidget);
    expect(find.text('Like'), findsNothing);

    // 2. Verify "Comment" and action button "Repost" are present
    expect(find.text('Comment (3)'), findsOneWidget);
    expect(find.text('Repost (0)'), findsOneWidget);

    // 3. Verify complaint details header elements
    expect(find.text('Broken Water Pipe'), findsOneWidget);
    expect(find.text('Saicharan'), findsOneWidget);
    expect(find.text('SC'), findsOneWidget);
    expect(find.text('SUBMITTED'), findsOneWidget);
    expect(find.text('Ward 12, Main Street'), findsOneWidget);

    // 4. Verify icons for Upvote, Comments, and Repost exist
    expect(find.byIcon(Icons.thumb_up_alt_outlined), findsOneWidget);
    expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);
    expect(find.byIcon(Icons.repeat), findsOneWidget);

    // 5. Verify SDG Badge is rendered (and Tracker in bottom nav also uses track_changes)
    expect(find.text('SDG 6'), findsOneWidget);
    expect(find.byIcon(Icons.track_changes), findsNWidgets(2));

    // 6. Verify Assigned Authority card
    expect(find.text('Assigned Authority'), findsOneWidget);
    expect(find.text('Ward Water Engineer'), findsOneWidget);
    expect(find.text('Water & Sanitation Department'), findsOneWidget);

    // 7. Verify Progress Timeline card
    expect(find.text('Progress Timeline'), findsOneWidget);
    expect(find.text('Complaint Submitted'), findsOneWidget);
    expect(find.text('Assigned To Officer'), findsOneWidget);
    expect(find.text('Work In Progress'), findsOneWidget);

    // 8. Verify separate CommentBottomSheet window is not open initially, but opens upon clicking Comment
    expect(find.byType(CommentBottomSheet), findsNothing);
    await tester.tap(find.text('Comment (3)'));
    await tester.pumpAndSettle();
    expect(find.byType(CommentBottomSheet), findsOneWidget);
  });

  testWidgets('FeedDetailScreen Comment button opens CommentBottomSheet separate window and initialShowComments works',
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
      'reposts_count': 2,
      'has_upvoted': false,
    };

    // When initialShowComments is false (default):
    await tester.pumpWidget(
      MaterialApp(
        home: FeedDetailScreen(feedData: mockFeedData, initialShowComments: false),
      ),
    );
    await tester.pumpAndSettle();

    // Verify separate CommentBottomSheet is not rendered
    expect(find.byType(CommentBottomSheet), findsNothing);

    // Tap comment button to open separate window
    await tester.tap(find.text('Comment (5)'));
    await tester.pumpAndSettle();

    // CommentBottomSheet is now open in separate window
    expect(find.byType(CommentBottomSheet), findsOneWidget);

    // Close the separate window
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.byType(CommentBottomSheet), findsNothing);
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

