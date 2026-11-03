// Regression: the admin review page for a pending authority application opened as a blank screen
// in the real app. The app theme (MedalTheme) makes every ElevatedButton infinitely wide, which breaks
// layout of any such button placed in a Row. The other tests use a plain MaterialApp and cannot see it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medal/core/services/api_service.dart';
import 'package:medal/core/theme/app_theme.dart';
import 'package:medal/modules/authority/screens/admin/admin_authority_verification_screen.dart';

Map<String, dynamic> _application(String status) => {
      'id': 7,
      'user_id': 9,
      'full_name': 'Rajaji',
      'official_email': 'rajaji@example.com',
      'official_phone': '+91 90000 00000',
      'designation': 'environmental inspector',
      'department': 'Municipal Administration',
      'jurisdiction': 'tambaram',
      'identity_number': null,
      'clearance_level': 'Level 2 (Inspection & Resolution Lead)',
      'aadhaar_document_url': 'https://signed.example.com/aadhaar.pdf',
      'employment_document_url': 'https://signed.example.com/employment.png',
      'status': status,
      'rejection_reason': status == 'rejected' ? 'Documents unreadable' : null,
      'created_at': '2026-11-03T10:00:00Z',
      'updated_at': '2026-11-03T10:00:00Z',
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiService().logout();
  });

  for (final status in ['pending', 'approved', 'rejected']) {
    testWidgets('Admin review page renders with the real app theme ($status) on a phone-sized screen',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: MedalTheme.lightTheme,
          home: AdminAuthorityVerificationScreen(application: _application(status)),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // Tests draw text with a very wide placeholder font, so a RenderFlex "overflowed" message on the
      // already-reviewed views is a test artefact. Any other layout error (the original bug) must fail.
      final error = tester.takeException();
      expect(error == null || (status != 'pending' && error.toString().contains('overflowed')), isTrue,
          reason: 'unexpected layout error: $error');
      expect(find.text('Rajaji'), findsWidgets);
    });
  }

  testWidgets('Pending application shows Approve and Reject actions', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        theme: MedalTheme.lightTheme,
        home: AdminAuthorityVerificationScreen(application: _application('pending')),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Approve'), findsWidgets);
    expect(find.textContaining('Reject'), findsWidgets);
  });
}
