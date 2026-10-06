import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medal/core/services/api_service.dart';
import 'package:medal/widgets/comments_controller.dart';
import 'package:medal/widgets/comment_bottom_sheet.dart';
import 'package:medal/widgets/post_comment_section.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiService().logout();
    ComplaintCommentsController.clearRegistry();
  });

  test('ComplaintCommentsController is a single shared instance per complaintId', () {
    final controller1 = ComplaintCommentsController.forComplaint(42);
    final controller2 = ComplaintCommentsController.forComplaint(42);
    final controllerOther = ComplaintCommentsController.forComplaint(99);

    expect(identical(controller1, controller2), isTrue);
    expect(identical(controller1, controllerOther), isFalse);
  });

  testWidgets('Bidirectional state synchronization between inline section and bottom sheet',
      (WidgetTester tester) async {
    const testComplaintId = 555;
    final controller = ComplaintCommentsController.forComplaint(testComplaintId);

    // Seed mock comment in controller
    final mockParentComment = {
      'id': 1,
      'complaint_id': testComplaintId,
      'user_id': 10,
      'user_name': 'Lisa Godwin',
      'user_initials': 'LG',
      'comment': 'Initial parent comment for road repair.',
      'content': 'Initial parent comment for road repair.',
      'parent_comment_id': null,
      'created_at': DateTime.now().toIso8601String(),
      'is_deleted': false,
    };
    controller.setCommentsForTesting([mockParentComment]);

    int inlineReportedCount = -1;
    int popupReportedCount = -1;

    // Build a test harness displaying both inline comment section and bottom sheet simultaneously
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                PostCommentSection(
                  complaintId: testComplaintId,
                  initialCommentCount: 1,
                  onCommentCountChanged: (count) {
                    inlineReportedCount = count;
                  },
                ),
                SizedBox(
                  height: 400,
                  child: CommentBottomSheet(
                    complaintId: testComplaintId,
                    initialCount: 1,
                    onCommentCountChanged: (count) {
                      popupReportedCount = count;
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify initial comment appears in BOTH inline section and bottom sheet
    expect(find.textContaining('Initial parent comment for road repair', findRichText: true), findsNWidgets(2));
    expect(find.text('Lisa Godwin'), findsNWidgets(2));

    // Simulate adding a nested reply
    final mockReply = {
      'id': 2,
      'complaint_id': testComplaintId,
      'user_id': 11,
      'user_name': 'Ramya Govindhan',
      'user_initials': 'RG',
      'comment': '@LisaGodwin We are looking into this today.',
      'content': '@LisaGodwin We are looking into this today.',
      'parent_comment_id': 1,
      'created_at': DateTime.now().toIso8601String(),
      'is_deleted': false,
    };

    controller.comments.add(mockReply);
    controller.notifyListeners();
    await tester.pumpAndSettle();

    // Verify reply appears in BOTH views simultaneously with author and mention
    expect(find.text('Ramya Govindhan'), findsNWidgets(2));
    expect(find.textContaining('We are looking into this today.', findRichText: true), findsNWidgets(2));
    expect(inlineReportedCount, equals(2));
    expect(popupReportedCount, equals(2));

    // Test voting synchronization
    controller.toggleVote(1, 1);
    await tester.pumpAndSettle();
    expect(controller.userVotes[1], equals(1));

    // Test soft-deletion synchronization on parent with replies
    await controller.deleteComment(1);
    await tester.pumpAndSettle();

    // The deleted parent should show 'This comment was deleted' in both views
    expect(find.text('This comment was deleted'), findsNWidgets(2));
    expect(controller.activeCommentCount, equals(1));
    expect(inlineReportedCount, equals(1));
    expect(popupReportedCount, equals(1));

    // Deleting leaf reply 2 (which has no replies) removes it completely
    await controller.deleteComment(2);
    await tester.pumpAndSettle();
    expect(find.text('Ramya Govindhan'), findsNothing);
    expect(controller.activeCommentCount, equals(0));
    expect(inlineReportedCount, equals(0));
    expect(popupReportedCount, equals(0));
  });

  testWidgets('Multi-level hierarchy (root -> reply -> reply to reply -> further reply) and long-press delete behavior',
      (WidgetTester tester) async {
    const testComplaintId = 777;
    final controller = ComplaintCommentsController.forComplaint(testComplaintId);

    // Mock logged-in user: id 99 (Bob Davis)
    await ApiService().setAuth('mock.jwt.token', {
      'id': 99,
      'role': 'citizen',
      'full_name': 'Bob Davis',
      'username': 'Bob Davis',
      'profile_image_url': 'http://172.16.125.17:8000/media/bob.jpg',
    });

    // 1. Root comment (Bob Davis, id 100)
    // 2. Reply to root (Alice Walker, id 200, parent 100)
    // 3. Reply to Alice's reply (Bob Davis, id 300, parent 200)
    // 4. Further reply to Bob's reply (SASU, id 400, parent 300)
    final commentsList = [
      {
        'id': 100,
        'complaint_id': testComplaintId,
        'user_id': 99,
        'user_name': 'Bob Davis',
        'user_initials': 'BD',
        'comment': 'Water is over 2 feet deep near the intersection.',
        'content': 'Water is over 2 feet deep near the intersection.',
        'parent_comment_id': null,
        'created_at': DateTime.now().toIso8601String(),
        'is_deleted': false,
      },
      {
        'id': 200,
        'complaint_id': testComplaintId,
        'user_id': 50,
        'user_name': 'Alice Walker',
        'user_initials': 'AW',
        'comment': '@BobDavis Thanks for reporting, we noticed it this morning.',
        'content': '@BobDavis Thanks for reporting, we noticed it this morning.',
        'parent_comment_id': 100,
        'created_at': DateTime.now().toIso8601String(),
        'is_deleted': false,
      },
      {
        'id': 300,
        'complaint_id': testComplaintId,
        'user_id': 99,
        'user_name': 'Bob Davis',
        'user_initials': 'BD',
        'comment': '@AliceWalker Great, hopefully repair team reaches soon.',
        'content': '@AliceWalker Great, hopefully repair team reaches soon.',
        'parent_comment_id': 200,
        'created_at': DateTime.now().toIso8601String(),
        'is_deleted': false,
      },
      {
        'id': 400,
        'complaint_id': testComplaintId,
        'user_id': 60,
        'user_name': 'SASU',
        'user_initials': 'SA',
        'comment': '@BobDavis Municipal team dispatched.',
        'content': '@BobDavis Municipal team dispatched.',
        'parent_comment_id': 300,
        'created_at': DateTime.now().toIso8601String(),
        'is_deleted': false,
      },
    ];

    controller.setCommentsForTesting(commentsList);

    // Verify tree structure
    final tree = controller.getThreadedTree();
    expect(tree.length, equals(1)); // 1 root comment
    expect(tree[0].comment['id'], equals(100)); // Bob Davis root
    expect(tree[0].children.length, equals(1)); // Alice Walker (level 1)
    expect(tree[0].children[0].comment['id'], equals(200));
    expect(tree[0].children[0].children.length, equals(1)); // Bob Davis reply (level 2)
    expect(tree[0].children[0].children[0].comment['id'], equals(300));
    expect(tree[0].children[0].children[0].children.length, equals(1)); // SASU reply (level 3)
    expect(tree[0].children[0].children[0].children[0].comment['id'], equals(400));

    // Render widget
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PostCommentSection(
              complaintId: testComplaintId,
              initialCommentCount: 4,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify all 4 levels render correctly
    expect(find.text('Bob Davis'), findsNWidgets(2)); // root + level 2 reply
    expect(find.text('Alice Walker'), findsOneWidget); // level 1 reply
    expect(find.text('SASU'), findsOneWidget); // level 3 reply

    // Verify NO visible delete button is present in normal UI
    expect(find.text('Delete'), findsNothing);

    // Test Long-Press on Alice Walker's comment (someone else's comment)
    // Must NOT show contextual Delete action
    await tester.longPress(find.text('Alice Walker'));
    await tester.pumpAndSettle();
    expect(find.text('Delete'), findsNothing);

    // Test Long-Press on Bob Davis's own root comment (id 100)
    // Must show contextual Delete action menu
    await tester.longPress(find.textContaining('Water is over 2 feet deep', findRichText: true));
    await tester.pumpAndSettle();
    expect(find.text('Delete'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    // Tap Cancel to dismiss
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Delete'), findsNothing);

    // Test Long-Press on Bob Davis's own nested reply (id 300)
    // Must also show contextual Delete action menu
    await tester.longPress(find.textContaining('Great, hopefully repair team', findRichText: true));
    await tester.pumpAndSettle();
    expect(find.text('Delete'), findsOneWidget);

    // Tap Cancel to dismiss
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });
}
