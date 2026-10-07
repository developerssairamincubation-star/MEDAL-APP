import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medal/modules/citizen/screens/components.dart';
import 'package:medal/modules/citizen/screens/profile.dart';

void main() {
  testWidgets('MainScreen profile tab switches and renders without layout errors',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MainScreen(initialIndex: 0),
      ),
    );
    await tester.pump();

    // Tap Profile tab
    final profileTabFinder = find.text('PROFILE');
    expect(profileTabFinder, findsOneWidget);
    await tester.tap(profileTabFinder);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Check if ProfileScreen is in tree and visible
    expect(find.byType(ProfileScreen), findsOneWidget);

    // Verify CITIZEN badge is shown and AUTHORITY is NOT shown
    expect(find.text('CITIZEN'), findsOneWidget);
    expect(find.text('AUTHORITY'), findsNothing);

    // Tap somewhere on ProfileScreen to trigger hitTest
    await tester.tap(find.text("Earned Certifications"));
    await tester.pump();

    // Scroll the profile screen
    await tester.drag(find.byType(ProfileScreen), const Offset(0, -300));
    await tester.pump();
  });
}
