import 'package:flutter_test/flutter_test.dart';
import 'package:medal/main.dart';

void main() {
  testWidgets('MEDAL App launch and render smoke test', (WidgetTester tester) async {
    // Build the application root widget
    await tester.pumpWidget(const MedalRootApp());
    await tester.pumpAndSettle();

    // Verify that the app renders the root widget
    expect(find.byType(MedalRootApp), findsOneWidget);
  });
}
