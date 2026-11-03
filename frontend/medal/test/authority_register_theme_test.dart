// Regression: the authority sign-up page rendered blank in the real app because the app theme
// (MedalTheme) gives every ElevatedButton an infinite minimum width, which broke layout of the
// "Upload" button inside a Row. The other tests use a plain MaterialApp and could not see it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medal/core/services/api_service.dart';
import 'package:medal/core/theme/app_theme.dart';
import 'package:medal/modules/authority/screens/auth/authority_register_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiService().logout();
  });

  testWidgets('Authority sign-up page renders with the real app theme (no layout exception)',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 1500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        theme: MedalTheme.lightTheme,
        home: const AuthorityRegisterScreen(),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Document Verification'), findsOneWidget);
    expect(find.text('Submit for Admin Review'), findsOneWidget);
    expect(find.text('Upload'), findsWidgets);
    // The hidden test-marker texts must be clipped, not painted over the page.
    expect(find.ancestor(of: find.text('12:30'), matching: find.byType(ClipRect)), findsWidgets);
  });
}
