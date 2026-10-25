// test/authority_register_ui_test.dart
// Comprehensive tests for AuthorityRegisterScreen:
// Document selection, file validation, editable profile fields, masking,
// replace/remove documents, view preview modal, validation errors, and backend submission.

import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medal/core/services/api_service.dart';
import 'package:medal/modules/authority/screens/auth/authority_register_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiService().logout();
  });

  tearDown(() async {
    await ApiService().logout();
  });

  testWidgets('Validation: Submitting with missing documents or empty fields shows clear errors',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 1500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        home: AuthorityRegisterScreen(),
      ),
    );
    await tester.pump();

    // Submit with no documents selected
    await tester.ensureVisible(find.text('Submit for Admin Review'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit for Admin Review'));
    await tester.pumpAndSettle();

    expect(find.text('Please select and upload your Aadhaar document.'), findsOneWidget);
  });

  testWidgets('Document selection, preview dialog, replace, and remove functionality',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 1500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    int pickCount = 0;
    final testFiles = [
      PlatformFile(
        name: 'aadhaar_card_original.pdf',
        size: 1024,
        bytes: Uint8List.fromList(utf8.encode('%PDF-1.4 sample aadhaar content')),
      ),
      PlatformFile(
        name: 'aadhaar_card_replaced.pdf',
        size: 2048,
        bytes: Uint8List.fromList(utf8.encode('%PDF-1.4 replaced content')),
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: AuthorityRegisterScreen(
          filePickerOverride: () async {
            final file = testFiles[pickCount % testFiles.length];
            pickCount++;
            return FilePickerResult([file]);
          },
        ),
      ),
    );
    await tester.pump();

    // Verify initial "Upload" buttons
    expect(find.text('Upload'), findsNWidgets(2));
    expect(find.text('No file selected'), findsNWidgets(2));

    // 1. Pick first document (Aadhaar)
    await tester.tap(find.text('Upload').first);
    await tester.pumpAndSettle();

    // Document is now attached
    expect(find.text('aadhaar_card_original.pdf'), findsOneWidget);
    expect(find.text('View'), findsOneWidget);

    // 2. Open Preview Dialog
    await tester.tap(find.text('View'));
    await tester.pumpAndSettle();

    expect(find.text('Document Preview'), findsOneWidget);
    expect(find.text('aadhaar_card_original.pdf'), findsWidgets);
    expect(find.text('Done'), findsOneWidget);
    expect(find.text('Replace'), findsOneWidget);
    expect(find.text('Remove'), findsOneWidget);

    // 3. Test Replace inside preview
    await tester.tap(find.text('Replace'));
    await tester.pumpAndSettle();

    // Document replaced with replaced.pdf
    expect(find.text('aadhaar_card_replaced.pdf'), findsOneWidget);

    // 4. Test Remove from preview
    await tester.tap(find.text('View'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    // Reset back to No file selected
    expect(find.text('aadhaar_card_replaced.pdf'), findsNothing);
    expect(find.text('No file selected'), findsNWidgets(2));
  });

  testWidgets('Invalid file extension and oversized file validation',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 1500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    bool returnOversized = false;

    await tester.pumpWidget(
      MaterialApp(
        home: AuthorityRegisterScreen(
          filePickerOverride: () async {
            if (returnOversized) {
              return FilePickerResult([
                PlatformFile(
                  name: 'huge_document.pdf',
                  size: 20 * 1024 * 1024, // 20 MB > 15 MB
                  bytes: Uint8List.fromList([1, 2, 3]),
                )
              ]);
            } else {
              return FilePickerResult([
                PlatformFile(
                  name: 'malicious_script.sh',
                  size: 500,
                  bytes: Uint8List.fromList(utf8.encode('echo script')),
                )
              ]);
            }
          },
        ),
      ),
    );
    await tester.pump();

    // 1. Test invalid extension (.sh)
    await tester.tap(find.text('Upload').first);
    await tester.pumpAndSettle();

    expect(find.textContaining("Invalid file type '.sh'"), findsOneWidget);

    // Dismiss first SnackBar
    await tester.pump(const Duration(seconds: 5));

    // 2. Test oversized file (> 15 MB)
    returnOversized = true;
    await tester.tap(find.text('Upload').first);
    await tester.pumpAndSettle();

    expect(find.textContaining('File size exceeds 15 MB limit'), findsOneWidget);
  });

  testWidgets('Editable profile fields: typing name, masked Aadhaar formatting, and details',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 1500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        home: AuthorityRegisterScreen(),
      ),
    );
    await tester.pump();

    // Edit Name
    final nameField = find.widgetWithText(TextFormField, 'e.g. Dr. Ramesh Sundaram');
    expect(nameField, findsOneWidget);
    await tester.enterText(nameField, 'Smt. Priya Ananth');
    await tester.pumpAndSettle();
    expect(find.text('Smt. Priya Ananth'), findsOneWidget);

    // Edit Aadhaar number and verify automatic masking
    final aadhaarField = find.widgetWithText(TextFormField, '••••  ••••  8492');
    expect(aadhaarField, findsOneWidget);
    await tester.enterText(aadhaarField, '5678');
    await tester.pumpAndSettle();
    expect(find.text('••••  ••••  5678'), findsOneWidget);

    // Edit Designation & Department
    final desigField = find.widgetWithText(
      TextFormField,
      'e.g. Divisional Environmental Inspector, Ward 14 Sanitation Dept',
    );
    expect(desigField, findsOneWidget);
    await tester.enterText(desigField, 'Assistant Health Officer, North Division');
    await tester.pumpAndSettle();
    expect(find.text('Assistant Health Officer, North Division'), findsOneWidget);

    // Edit Email
    final emailField = find.widgetWithText(TextFormField, 'e.g. ramesh.sundaram@gov.in');
    expect(emailField, findsOneWidget);
    await tester.enterText(emailField, 'priya.ananth@corporation.gov.in');
    await tester.pumpAndSettle();
    expect(find.text('priya.ananth@corporation.gov.in'), findsOneWidget);
  });

  testWidgets('Successful registration: Uploads documents, creates pending application, and shows Reference ID dialog',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 1500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    bool registerCalled = false;
    Map<String, dynamic>? registerPayload;

    final mockClient = MockClient((request) async {
      if (request.url.path.endsWith('/authority/upload-document')) {
        return http.Response(
          jsonEncode({
            'message': 'Document uploaded',
            'document_url': '/uploads/verification/test_doc_${DateTime.now().millisecondsSinceEpoch}.pdf',
            'filename': 'test_doc.pdf',
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path.endsWith('/authority/register')) {
        registerCalled = true;
        registerPayload = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'message': 'Authority application submitted successfully.',
            'reference_id': 'AUTH-REV-2026-5541',
            'status': 'pending',
            'data': {
              'id': 5541,
              'user_id': 991,
              'full_name': registerPayload!['full_name'],
              'official_email': registerPayload!['official_email'],
              'status': 'pending',
              'created_at': '2026-10-24T12:00:00Z',
              'updated_at': '2026-10-24T12:00:00Z',
              'designation': registerPayload!['designation'],
              'department': registerPayload!['department'],
              'jurisdiction': registerPayload!['jurisdiction'],
              'identity_number': registerPayload!['identity_number'],
              'clearance_level': registerPayload!['clearance_level'],
              'aadhaar_document_url': registerPayload!['aadhaar_document_url'],
              'employment_document_url': registerPayload!['employment_document_url'],
            },
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('{"detail": "Not found"}', 404);
    });

    int pickIndex = 0;
    final docs = [
      PlatformFile(
        name: 'aadhaar_doc.pdf',
        size: 2048,
        bytes: Uint8List.fromList(utf8.encode('%PDF-1.4 aadhaar verified')),
      ),
      PlatformFile(
        name: 'gazette_order.pdf',
        size: 4096,
        bytes: Uint8List.fromList(utf8.encode('%PDF-1.4 gazette certified')),
      ),
    ];

    await http.runWithClient(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: AuthorityRegisterScreen(
            filePickerOverride: () async {
              final doc = docs[pickIndex % docs.length];
              pickIndex++;
              return FilePickerResult([doc]);
            },
          ),
        ),
      );
      await tester.pump();

      // 1. Pick Aadhaar
      await tester.tap(find.text('Upload').first);
      await tester.pumpAndSettle();

      // 2. Pick Employment ID
      await tester.tap(find.text('Upload').first);
      await tester.pumpAndSettle();

      expect(find.text('aadhaar_doc.pdf'), findsOneWidget);
      expect(find.text('gazette_order.pdf'), findsOneWidget);

      // 3. Fill profile fields
      await tester.enterText(
        find.widgetWithText(TextFormField, 'e.g. Dr. Ramesh Sundaram'),
        'Inspector Ramesh Sundaram',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, '••••  ••••  8492'),
        '8492',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'e.g. Divisional Environmental Inspector, Ward 14 Sanitation Dept'),
        'Divisional Inspector, Sanitation Dept',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'e.g. ramesh.sundaram@gov.in'),
        'ramesh.sundaram@corporation.gov.in',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'e.g. Zone 4, Pine River Catchment, Sector 9'),
        'Ward 14, River District',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'e.g. +91 98451 22301'),
        '+91 98451 22301',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Enter password (min 6 characters)'),
        'OfficerSecret2026!',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Re-enter password to confirm'),
        'OfficerSecret2026!',
      );
      await tester.pumpAndSettle();

      // 4. Tap Submit for Admin Review
      await tester.ensureVisible(find.text('Submit for Admin Review'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Submit for Admin Review'));
      await tester.pump();
      await tester.pumpAndSettle();

      // 5. Verify API called with real values
      expect(registerCalled, isTrue);
      expect(registerPayload!['full_name'], equals('Inspector Ramesh Sundaram'));
      expect(registerPayload!['official_email'], equals('ramesh.sundaram@corporation.gov.in'));
      expect(registerPayload!['password'], equals('OfficerSecret2026!'));
      expect(registerPayload!['designation'], equals('Divisional Inspector'));
      expect(registerPayload!['department'], equals('Sanitation Dept'));
      expect(registerPayload!['identity_number'], contains('8492'));
      expect(registerPayload!['aadhaar_document_url'], contains('uploads/verification'));
      expect(registerPayload!['employment_document_url'], contains('uploads/verification'));

      // 6. Verify success dialog
      expect(find.text('Application Submitted for Review'), findsOneWidget);
      expect(find.text('STATUS: PENDING ADMIN REVIEW'), findsOneWidget);
      expect(find.text('Reference ID: AUTH-REV-2026-5541'), findsOneWidget);
      expect(find.text('Return to Sign In'), findsOneWidget);
    }, () => mockClient);
  });

  testWidgets('AuthorityRegisterScreen renders completely without blank page, displaying Step 1 of 2, Document Verification, and Official Profile Data',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AuthorityRegisterScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Brand Header and Top Nav Bar
    expect(find.text('MEDAL'), findsOneWidget);
    expect(find.text('Authority Sign Up'), findsOneWidget);

    // Verify Step 1 of 2 card
    expect(find.text('Step 1 of 2'), findsOneWidget);
    expect(find.text('Authority Credentials & Identity Verification'), findsOneWidget);

    // Verify Document Verification card
    expect(find.text('Document Verification'), findsOneWidget);
    expect(find.text('1. National Identity Proof (Aadhaar)'), findsOneWidget);
    expect(find.text('2. Official Employment ID Card'), findsOneWidget);

    // Verify Official Profile Data card
    expect(find.text('Official Profile Data'), findsOneWidget);
    expect(find.text('FULL LEGAL NAME'), findsOneWidget);
    expect(find.text('AADHAAR UID NUMBER'), findsOneWidget);
    expect(find.text('DESIGNATION & DEPARTMENT'), findsOneWidget);
    expect(find.text('OFFICIAL GOVERNMENT EMAIL'), findsOneWidget);
    expect(find.text('JURISDICTION BOUNDARY'), findsOneWidget);
    expect(find.text('SECURE CONTACT PHONE'), findsOneWidget);
    expect(find.text('OFFICIAL ACCOUNT PASSWORD'), findsOneWidget);
    expect(find.text('CONFIRM PASSWORD'), findsOneWidget);

    // Verify Submit button
    expect(find.text('Submit for Admin Review'), findsOneWidget);
  });

  testWidgets('AuthorityRegisterScreen displays useful error and retry UI when error occurs',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        routes: {
          '/': (context) => const AuthorityRegisterScreen(
                initialErrorMessage: 'Connection failed: Backend server unreachable',
              ),
          '/authority/login': (context) => const Scaffold(body: Text('Authority Login Screen')),
        },
      ),
    );
    await tester.pumpAndSettle();

    // Verify error UI is displayed instead of empty white screen
    expect(find.text('Unable to Load Registration Portal'), findsOneWidget);
    expect(find.text('Connection failed: Backend server unreachable'), findsOneWidget);
    expect(find.text('Try Again'), findsOneWidget);
    expect(find.text('Return to Official Sign In'), findsOneWidget);

    // Tap Try Again clears the error and restores the form
    await tester.tap(find.text('Try Again'));
    await tester.pumpAndSettle();

    expect(find.text('Document Verification'), findsOneWidget);
    expect(find.text('Official Profile Data'), findsOneWidget);
  });
}
