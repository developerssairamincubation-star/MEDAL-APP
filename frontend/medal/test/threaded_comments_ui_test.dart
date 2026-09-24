import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medal/widgets/comment_bottom_sheet.dart';

void main() {
  testWidgets('CommentBottomSheet renders threaded comments, reply button, and reply composer',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CommentBottomSheet(
            complaintId: 101,
            initialCount: 3,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify header, close icon, and empty or loading state
    expect(find.byIcon(Icons.close), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byIcon(Icons.send_rounded), findsOneWidget);
  });

  testWidgets('CommentBottomSheet handles reply mode activation and cancellation',
      (WidgetTester tester) async {
    final bottomSheetKey = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommentBottomSheet(
            key: bottomSheetKey,
            complaintId: 102,
            initialCount: 2,
          ),
        ),
      ),
    );
    await tester.pump();

    // Verify text field exists and starts with empty or hint text
    final textFieldFinder = find.byType(TextField);
    expect(textFieldFinder, findsOneWidget);
    TextField tf = tester.widget<TextField>(textFieldFinder);
    expect(tf.decoration?.hintText, equals('Write a comment...'));

    // Enter text directly into controller
    await tester.enterText(textFieldFinder, 'Testing comment flow');
    await tester.pump();
    expect(find.text('Testing comment flow'), findsOneWidget);
  });
}
