// test/admin_authority_verification_test.dart
// Comprehensive tests for MEDAL Admin Authority Applications List and Verification Details workflow.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medal/core/services/api_service.dart';
import 'package:medal/routes/app_routes.dart';
import 'package:medal/modules/authority/screens/admin/admin_authority_applications_list_screen.dart';
import 'package:medal/modules/authority/screens/admin/admin_authority_verification_screen.dart';

String _buildMockJwt({required String role, required String sub}) {
  final header = base64Url.encode(utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'}))).replaceAll('=', '');
  final payload = base64Url.encode(utf8.encode(jsonEncode({
    'sub': sub,
    'role': role,
    'exp': (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600,
  }))).replaceAll('=', '');
  return '$header.$payload.mock_signature';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final mockApplications = [
    {
      'id': 101,
      'user_id': 201,
      'full_name': 'Mr. Ramesh Sundaram',
      'official_email': 'ramesh.sundaram@gov.in',
      'official_phone': '+91 98451 22301',
      'designation': 'Divisional Environmental Inspector',
      'department': 'Ward 14 Sanitation Dept',
      'jurisdiction': 'Pine River Regional Sector',
      'identity_number': '••••  ••••  8492',
      'clearance_level': 'Level 2 (Inspection & Resolution Lead)',
      'aadhaar_document_url': '/uploads/verification/aadhaar_ramesh.pdf',
      'employment_document_url': '/uploads/verification/gazette_ramesh.pdf',
      'status': 'pending',
      'created_at': '2026-10-24T10:00:00Z',
      'updated_at': '2026-10-24T10:00:00Z',
    },
    {
      'id': 102,
      'user_id': 202,
      'full_name': 'Officer Priya Sharma',
      'official_email': 'priya.sharma@gov.in',
      'official_phone': '+91 98765 43210',
      'designation': 'Senior Sanitation Officer',
      'department': 'Zone 2 Public Health Dept',
      'jurisdiction': 'North District Ward 8',
      'identity_number': '••••  ••••  1234',
      'clearance_level': 'Level 2 (Inspection & Resolution Lead)',
      'aadhaar_document_url': '/uploads/verification/aadhaar_priya.pdf',
      'employment_document_url': '/uploads/verification/gazette_priya.pdf',
      'status': 'approved',
      'created_at': '2026-10-23T10:00:00Z',
      'updated_at': '2026-10-24T10:00:00Z',
    },
    {
      'id': 103,
      'user_id': 203,
      'full_name': 'Vikram Singh',
      'official_email': 'vikram.singh@gov.in',
      'official_phone': '+91 91234 56789',
      'designation': 'Field Inspector',
      'department': 'Water Works Dept',
      'jurisdiction': 'South Zone Catchment',
      'identity_number': '••••  ••••  5678',
      'clearance_level': 'Level 1 (Field Officer & Site Inspector)',
      'aadhaar_document_url': '/uploads/verification/aadhaar_vikram.pdf',
      'employment_document_url': '/uploads/verification/gazette_vikram.pdf',
      'status': 'rejected',
      'rejection_reason': 'Identity document illegible',
      'created_at': '2026-10-22T10:00:00Z',
      'updated_at': '2026-10-23T10:00:00Z',
    },
  ];

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiService().logout();

    // Default admin session
    final adminJwt = _buildMockJwt(role: 'admin', sub: '232');
    await ApiService().setAuth(adminJwt, {
      'id': 232,
      'email': 'admin@medal.gov.in',
      'full_name': 'MEDAL System Administrator',
      'role': 'admin',
    });
  });

  tearDown(() async {
    await ApiService().logout();
  });

  Widget createAdminListTestApp() {
    return const MaterialApp(
      home: AdminAuthorityApplicationsListScreen(),
    );
  }

  Widget createAdminDetailsTestApp({Map<String, dynamic>? app}) {
    return MaterialApp(
      home: AdminAuthorityVerificationScreen(
        application: app ?? mockApplications.first,
      ),
    );
  }

  // ── 1. Applications List Screen Tests ─────────────────────────────────

  testWidgets('AdminAuthorityApplicationsListScreen loads real applications and supports tabs',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final mockClient = MockClient((request) async {
      if (request.url.path.endsWith('/admin/authority-applications')) {
        return http.Response(
          jsonEncode(mockApplications),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('{"detail": "Not found"}', 404);
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(createAdminListTestApp());
      await tester.pump();
      await tester.pumpAndSettle();

      // Header elements
      expect(find.text('MEdAL'), findsOneWidget);
      expect(find.text('Authority Applications'), findsOneWidget);
      expect(find.text('ADMIN CONSOLE'), findsOneWidget);

      // Tabs with counts: Pending (1), Approved (1), Rejected (1)
      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Approved'), findsOneWidget);
      expect(find.text('Rejected'), findsOneWidget);

      // Pending tab is selected by default: shows Ramesh Sundaram
      expect(find.text('Mr. Ramesh Sundaram'), findsOneWidget);
      expect(find.text('Divisional Environmental Inspector'), findsOneWidget);
      expect(find.text('Ward 14 Sanitation Dept'), findsOneWidget);
      expect(find.text('ramesh.sundaram@gov.in'), findsOneWidget);
      expect(find.text('PENDING'), findsOneWidget);

      // Officer Priya Sharma is approved, Vikram Singh is rejected; should not appear in Pending tab
      expect(find.text('Officer Priya Sharma'), findsNothing);
      expect(find.text('Vikram Singh'), findsNothing);

      // Switch to Approved tab
      await tester.tap(find.text('Approved'));
      await tester.pumpAndSettle();

      expect(find.text('Officer Priya Sharma'), findsOneWidget);
      expect(find.text('APPROVED'), findsOneWidget);
      expect(find.text('Mr. Ramesh Sundaram'), findsNothing);

      // Switch to Rejected tab
      await tester.tap(find.text('Rejected'));
      await tester.pumpAndSettle();

      expect(find.text('Vikram Singh'), findsOneWidget);
      expect(find.text('REJECTED'), findsOneWidget);
      expect(find.text('Officer Priya Sharma'), findsNothing);
    }, () => mockClient);
  });

  testWidgets('Applications list shows clear empty state when tab has no applications',
      (WidgetTester tester) async {
    final mockClient = MockClient((request) async {
      if (request.url.path.endsWith('/admin/authority-applications')) {
        return http.Response(
          jsonEncode([]),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('{"detail": "Not found"}', 404);
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(createAdminListTestApp());
      await tester.pumpAndSettle();

      expect(find.text('No Pending Applications'), findsOneWidget);
      expect(find.text('Refresh List'), findsOneWidget);
    }, () => mockClient);
  });

  testWidgets('Applications list displays error state and Retry button on network failure',
      (WidgetTester tester) async {
    bool retried = false;
    final mockClient = MockClient((request) async {
      if (!retried) {
        return http.Response(jsonEncode({'detail': 'Database connection timeout'}), 500);
      }
      return http.Response(jsonEncode(mockApplications), 200, headers: {'content-type': 'application/json'});
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(createAdminListTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Unable to load applications'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);

      retried = true;
      await tester.tap(find.text('Try Again'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Mr. Ramesh Sundaram'), findsOneWidget);
    }, () => mockClient);
  });

  // ── 2. Verification Details Screen Tests ──────────────────────────────

  testWidgets('AdminAuthorityVerificationScreen renders visual spec matching screenshot and processes approval',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    bool approvedCalled = false;

    final mockClient = MockClient((request) async {
      if (request.url.path.endsWith('/approve')) {
        approvedCalled = true;
        return http.Response(
          jsonEncode({
            'message': 'Officer onboarded and approved successfully',
            'application': {
              ...mockApplications.first,
              'status': 'approved',
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('{"detail": "Not found"}', 404);
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(createAdminDetailsTestApp());
      await tester.pumpAndSettle();

      // 1. Header
      expect(find.text('MEdAL'), findsOneWidget);
      expect(find.text('Authority verification'), findsOneWidget);
      expect(find.text('AWAITING APPROVAL'), findsOneWidget);

      // 2. Profile Card
      expect(find.text('Mr. Ramesh Sundaram'), findsOneWidget);
      expect(find.text('Divisional Environmental Inspector'), findsOneWidget);
      expect(find.text('Ward 14 Sanitation Dept'), findsOneWidget);
      expect(find.textContaining('Jurisdiction: Pine River Regional Sector'), findsOneWidget);

      // 3. Uploaded Documents
      expect(find.text('Uploaded Documents'), findsOneWidget);
      expect(find.text('2 Files Ready'), findsOneWidget);
      expect(find.text('Aadhaar Card Copy'), findsOneWidget);
      expect(find.text('IDENTITY CONFIRMED'), findsOneWidget);
      expect(find.text('View Full'), findsOneWidget);

      expect(find.text('Gov Employment Gazette'), findsOneWidget);
      expect(find.text('STAMP CERTIFIED'), findsOneWidget);
      expect(find.text('Inspect'), findsOneWidget);

      // 4. Details Card
      expect(find.text('DESIGNATION & DEPARTMENT'), findsOneWidget);
      expect(find.text('Gazette Verified'), findsOneWidget);
      expect(find.text('ramesh.sundaram@gov.in'), findsOneWidget);
      expect(find.text('+91 98451 22301'), findsOneWidget);

      // 5. Clearance Authority Level
      expect(find.text('Designated Clearance Authority Level'), findsOneWidget);
      expect(find.text('Level 2 (Inspection & Resolution Lead)'), findsOneWidget);
      expect(find.text('Grants authority to sign off on environmental grievance closures.'), findsOneWidget);

      // 6. Action buttons
      expect(find.text('Approve & Onboard Officer'), findsOneWidget);
      expect(find.text('Reject Submission'), findsOneWidget);

      // 7. Test Document Preview modal
      await tester.tap(find.text('View Full'));
      await tester.pumpAndSettle();

      expect(find.text('PDF Document Stored'), findsOneWidget);
      expect(find.text('Close Preview'), findsOneWidget);

      await tester.tap(find.text('Close Preview'));
      await tester.pumpAndSettle();

      // 8. Test Approve Action with confirmation dialog
      await tester.ensureVisible(find.text('Approve & Onboard Officer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Approve & Onboard Officer'));
      await tester.pumpAndSettle();

      // Confirmation dialog appears
      expect(find.text('Confirm Approval'), findsOneWidget);
      expect(find.textContaining('Are you sure you want to approve'), findsOneWidget);

      // Confirm approval
      await tester.tap(find.widgetWithText(ElevatedButton, 'Confirm Approval'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(approvedCalled, isTrue);
    }, () => mockClient);
  });

  testWidgets('AdminAuthorityVerificationScreen processes rejection with required reason',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    bool rejectCalled = false;
    String? capturedReason;

    final mockClient = MockClient((request) async {
      if (request.url.path.endsWith('/reject')) {
        rejectCalled = true;
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        capturedReason = body['reason'];
        return http.Response(
          jsonEncode({
            'message': 'Application rejected',
            'application': {
              ...mockApplications.first,
              'status': 'rejected',
              'rejection_reason': capturedReason,
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('{"detail": "Not found"}', 404);
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(createAdminDetailsTestApp());
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Reject Submission'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reject Submission'));
      await tester.pumpAndSettle();

      // Check dialog opened
      expect(find.textContaining('Provide an official administrative reason'), findsOneWidget);
      expect(find.text('Confirm Rejection'), findsOneWidget);

      // Enter rejection reason
      await tester.enterText(
        find.byType(TextField),
        'Gazette stamp is illegible. Please re-upload certified copy.',
      );
      await tester.pumpAndSettle();

      // Tap Confirm Rejection
      await tester.tap(find.text('Confirm Rejection'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(rejectCalled, isTrue);
      expect(capturedReason, contains('Gazette stamp is illegible'));
    }, () => mockClient);
  });

  testWidgets('Non-admin user session is strictly blocked from Admin applications list',
      (WidgetTester tester) async {
    final mockOfficialJwt = _buildMockJwt(role: 'official', sub: '99');
    await ApiService().setAuth(mockOfficialJwt, {
      'id': 99,
      'email': 'officer.test@corporation.gov.in',
      'full_name': 'Officer Test',
      'role': 'official',
    });

    expect(ApiService().userRole, equals('official'));

    await tester.pumpWidget(createAdminListTestApp());
    await tester.pumpAndSettle();

    expect(find.textContaining('Access Denied: Only authenticated System Administrators'), findsOneWidget);
    expect(find.text('Mr. Ramesh Sundaram'), findsNothing);
  });

  testWidgets('Admin can trigger logout dialog and exit safely to role selection',
      (WidgetTester tester) async {
    final mockClient = MockClient((request) async {
      return http.Response(jsonEncode([]), 200, headers: {'content-type': 'application/json'});
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(
        MaterialApp(
          routes: {
            '/': (context) => const AdminAuthorityApplicationsListScreen(),
            '/role-selection': (context) => const Scaffold(body: Text('Role Selection Screen')),
          },
        ),
      );
      await tester.pumpAndSettle();

      // Find and tap the logout button
      final logoutBtn = find.byKey(const Key('admin_logout_button'));
      expect(logoutBtn, findsOneWidget);
      await tester.tap(logoutBtn);
      await tester.pumpAndSettle();

      // Confirmation dialog appears
      expect(find.text('Admin Sign Out'), findsOneWidget);
      expect(find.text('Log Out'), findsOneWidget);

      // Confirm logout
      await tester.tap(find.text('Log Out'));
      await tester.pumpAndSettle();

      // Session cleared and navigated to role selection
      expect(ApiService().isAuthenticated, isFalse);
      expect(find.text('Role Selection Screen'), findsOneWidget);
    }, () => mockClient);
  });

  // ── 3. Regression Tests for Bug Fix ──────────────────────────────────

  testWidgets('Card tap navigates to details with correct ID and renders verification screen',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    bool requestedDetail = false;
    final mockClient = MockClient((request) async {
      if (request.url.path.endsWith('/admin/authority-applications')) {
        return http.Response(
          jsonEncode(mockApplications),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path.endsWith('/admin/authority-applications/101')) {
        requestedDetail = true;
        return http.Response(
          jsonEncode(mockApplications.first),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('{"detail": "Not found"}', 404);
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(
        initialRoute: AppRoutes.adminApplicationsList,
        routes: AppRoutes.routes,
      ));
      await tester.pump();
      await tester.pumpAndSettle();

      // Ensure application card is visible and tap it
      expect(find.text('Mr. Ramesh Sundaram'), findsOneWidget);
      await tester.tap(find.text('Mr. Ramesh Sundaram'));
      await tester.pump();
      await tester.pumpAndSettle();

      // Verify details screen opened and rendered correctly matching Screenshot 3
      expect(find.byType(AdminAuthorityVerificationScreen), findsOneWidget);
      expect(find.text('Authority verification'), findsOneWidget);
      expect(find.text('AWAITING APPROVAL'), findsOneWidget);
      expect(find.text('Ward 14 Sanitation Dept'), findsOneWidget);
      expect(find.text('Uploaded Documents'), findsOneWidget);
      expect(find.text('Approve & Onboard Officer'), findsOneWidget);
      expect(find.text('Reject Submission'), findsOneWidget);
      expect(requestedDetail, isTrue);
    }, () => mockClient);
  });

  testWidgets('AdminAuthorityVerificationScreen shows visible loading state before backend responds',
      (WidgetTester tester) async {
    final mockClient = MockClient((request) async {
      await Future.delayed(const Duration(milliseconds: 100));
      return http.Response(
        jsonEncode(mockApplications.first),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(
        home: AdminAuthorityVerificationScreen(applicationId: 101),
      ));

      // Pump 1 frame: loading state must be visible
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading application details...'), findsOneWidget);

      // Settle future
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();

      expect(find.text('Mr. Ramesh Sundaram'), findsOneWidget);
      expect(find.text('Authority verification'), findsOneWidget);
    }, () => mockClient);
  });

  testWidgets('AdminAuthorityVerificationScreen displays visible error and retry state on API failure (never blank)',
      (WidgetTester tester) async {
    bool hasFailed = true;
    final mockClient = MockClient((request) async {
      if (hasFailed) {
        return http.Response(
          jsonEncode({'detail': 'Internal Server Error fetching application'}),
          500,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response(
        jsonEncode(mockApplications.first),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(
        home: AdminAuthorityVerificationScreen(applicationId: 101),
      ));
      await tester.pump();
      await tester.pumpAndSettle();

      // Must display visible error state, NOT a blank white page
      expect(find.text('Unable to load application'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);
      expect(find.text('MEdAL'), findsOneWidget);

      // Tap Retry after fixing error
      hasFailed = false;
      await tester.tap(find.text('Try Again'));
      await tester.pump();
      await tester.pumpAndSettle();

      // Now data should display
      expect(find.text('Mr. Ramesh Sundaram'), findsOneWidget);
      expect(find.text('Authority verification'), findsOneWidget);
    }, () => mockClient);
  });

  testWidgets('Top Back button returns from details screen to authority applications list',
      (WidgetTester tester) async {
    final mockClient = MockClient((request) async {
      if (request.url.path.endsWith('/admin/authority-applications')) {
        return http.Response(
          jsonEncode(mockApplications),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path.endsWith('/admin/authority-applications/101')) {
        return http.Response(
          jsonEncode(mockApplications.first),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('{"detail": "Not found"}', 404);
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(
        initialRoute: AppRoutes.adminApplicationsList,
        routes: AppRoutes.routes,
      ));
      await tester.pumpAndSettle();

      // Tap to navigate to details
      await tester.tap(find.text('Mr. Ramesh Sundaram'));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.byType(AdminAuthorityVerificationScreen), findsOneWidget);

      // Tap the back button
      final backButton = find.byIcon(Icons.arrow_back);
      expect(backButton, findsOneWidget);
      await tester.tap(backButton);
      await tester.pump();
      await tester.pumpAndSettle();

      // Must be back on list screen
      expect(find.byType(AdminAuthorityApplicationsListScreen), findsOneWidget);
      expect(find.byType(AdminAuthorityVerificationScreen), findsNothing);
    }, () => mockClient);
  });

  testWidgets('System back navigation (handlePopRoute) returns from details screen to authority applications list',
      (WidgetTester tester) async {
    final mockClient = MockClient((request) async {
      if (request.url.path.endsWith('/admin/authority-applications')) {
        return http.Response(
          jsonEncode(mockApplications),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path.endsWith('/admin/authority-applications/101')) {
        return http.Response(
          jsonEncode(mockApplications.first),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('{"detail": "Not found"}', 404);
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(
        initialRoute: AppRoutes.adminApplicationsList,
        routes: AppRoutes.routes,
      ));
      await tester.pumpAndSettle();

      // Tap to navigate to details
      await tester.tap(find.text('Mr. Ramesh Sundaram'));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.byType(AdminAuthorityVerificationScreen), findsOneWidget);

      // Trigger hardware / system Back navigation
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pumpAndSettle();

      // Must be back on list screen
      expect(find.byType(AdminAuthorityApplicationsListScreen), findsOneWidget);
      expect(find.byType(AdminAuthorityVerificationScreen), findsNothing);
    }, () => mockClient);
  });

  testWidgets('Clearance level dropdown safely handles various clearance level values without assertion errors',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final customApp = {
      ...mockApplications.first,
      'clearance_level': 'Level 3 - Senior Regional Superintendent',
    };

    final mockClient = MockClient((request) async {
      return http.Response(
        jsonEncode(customApp),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(createAdminDetailsTestApp(app: customApp));
      await tester.pumpAndSettle();

      // Verify custom clearance level displays without Dropdown assertion error
      expect(find.text('Level 3 - Senior Regional Superintendent'), findsOneWidget);
      expect(find.text('Designated Clearance Authority Level'), findsOneWidget);
    }, () => mockClient);
  });
}
