import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medal/widgets/comment_bottom_sheet.dart';
import 'package:medal/widgets/comments_controller.dart';
import 'package:medal/widgets/post_comment_section.dart';

void main() {
  group('Comment Photo Attachment & Rendering Flow Tests', () {
    testWidgets('ThreadedCommentNodeWidget renders text-only comment without image container',
        (WidgetTester tester) async {
      final controller = ComplaintCommentsController.forComplaint(999);
      controller.setCommentsForTesting([
        {
          'id': 1,
          'complaint_id': 999,
          'user_id': 1,
          'user_name': 'Test User',
          'user_initials': 'TU',
          'comment': 'This is a pure text comment',
          'created_at': DateTime.now().toIso8601String(),
          'image_url': null,
          'parent_comment_id': null,
        }
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ThreadedCommentNodeWidget(
              node: controller.getThreadedTree().first,
              controller: controller,
              onReply: (_) {},
              onDelete: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('This is a pure text comment', findRichText: true), findsOneWidget);
      // No Image widget should be present for text-only comments
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('ThreadedCommentNodeWidget renders comment with image_url correctly',
        (WidgetTester tester) async {
      final controller = ComplaintCommentsController.forComplaint(998);
      controller.setCommentsForTesting([
        {
          'id': 2,
          'complaint_id': 998,
          'user_id': 2,
          'user_name': 'Reporter User',
          'user_initials': 'RU',
          'comment': 'Here is photo evidence of the broken pipe',
          'created_at': DateTime.now().toIso8601String(),
          'image_url': 'http://127.0.0.1:9000/medal-evidence/reports/pipe.jpg',
          'parent_comment_id': null,
        }
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ThreadedCommentNodeWidget(
              node: controller.getThreadedTree().first,
              controller: controller,
              onReply: (_) {},
              onDelete: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('Here is photo evidence of the broken pipe', findRichText: true), findsOneWidget);
      // Image widget must be present inside ClipRRect
      expect(find.byType(Image), findsOneWidget);
      expect(find.byType(ClipRRect), findsWidgets);
    });

    testWidgets('ThreadedCommentNodeWidget hides image when comment is deleted',
        (WidgetTester tester) async {
      final controller = ComplaintCommentsController.forComplaint(997);
      controller.setCommentsForTesting([
        {
          'id': 3,
          'complaint_id': 997,
          'user_id': 3,
          'user_name': 'Reporter User',
          'user_initials': 'RU',
          'comment': 'This comment was deleted',
          'created_at': DateTime.now().toIso8601String(),
          'image_url': 'http://127.0.0.1:9000/medal-evidence/reports/pipe.jpg',
          'parent_comment_id': null,
          'is_deleted': true,
        }
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ThreadedCommentNodeWidget(
              node: controller.getThreadedTree().first,
              controller: controller,
              onReply: (_) {},
              onDelete: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('This comment was deleted'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('PostCommentSection has photo/image attachment icon',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PostCommentSection(
              complaintId: 996,
              initialCommentCount: 0,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
    });

    testWidgets('CommentBottomSheet has photo/image attachment action',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CommentBottomSheet(
              complaintId: 995,
              initialCount: 0,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
      expect(find.byIcon(Icons.send_rounded), findsOneWidget);
    });
  });
}
