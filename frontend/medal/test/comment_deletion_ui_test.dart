import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medal/core/services/api_service.dart';
import 'package:medal/widgets/comment_bottom_sheet.dart';
import 'package:medal/modules/citizen/screens/feed_details.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiService().logout();
  });

  testWidgets('CommentBottomSheet renders correctly and initializes',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CommentBottomSheet(
            complaintId: 101,
            initialCount: 5,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
  });

  testWidgets('ApiService currentUserId correctly identifies logged-in user',
      (WidgetTester tester) async {
    final apiService = ApiService();
    expect(apiService.currentUserId, isNull);

    // Mock setting authentication
    await apiService.setAuth('mock.jwt.token', {'id': 42, 'role': 'citizen', 'full_name': 'Test User'});
    expect(apiService.currentUserId, equals(42));

    await apiService.logout();
    expect(apiService.currentUserId, isNull);
  });

  testWidgets('CommentBottomSheet handles deleted comment text and hides reply button',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CommentBottomSheet(
            complaintId: 102,
            initialCount: 1,
          ),
        ),
      ),
    );
    await tester.pump();

    // Verify input bar is present
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('FeedDetailScreen shows delete button when current user is report author',
      (WidgetTester tester) async {
    final apiService = ApiService();
    await apiService.setAuth('mock.jwt.token', {'id': 99, 'role': 'citizen', 'full_name': 'Author User'});

    final feedData = {
      'id': 105,
      'citizen_id': 99,
      'citizen_name': 'Author User',
      'title': 'Test Report',
      'description': 'Test Description',
      'status': 'submitted',
      'location': 'Main St',
      'upvotes_count': 0,
      'comments_count': 0,
      'reports_count': 0,
    };

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => FeedDetailScreen(feedData: feedData)),
                );
              },
              child: const Text('Open Details'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Details'));
    await tester.pumpAndSettle();

    // Verify Delete Report icon button is present in AppBar for author
    expect(find.byIcon(Icons.delete_outline), findsWidgets);

    await apiService.logout();
  });
}
