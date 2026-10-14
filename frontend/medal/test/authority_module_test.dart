// test/authority_module_test.dart
// Comprehensive widget and flow tests for the MEDAL Authority Module.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medal/modules/authority/models/authority_models.dart';
import 'package:medal/modules/authority/screens/auth/registration_role_selection_screen.dart';
import 'package:medal/modules/authority/screens/auth/authority_register_screen.dart';
import 'package:medal/modules/authority/screens/auth/authority_login_screen.dart';
import 'package:medal/modules/authority/screens/dashboard/authority_main_screen.dart';
import 'package:medal/modules/authority/screens/complaints/authority_complaints_screen.dart';
import 'package:medal/modules/authority/screens/complaints/authority_complaint_detail_screen.dart';
import 'package:medal/modules/authority/screens/academy/authority_academy_screen.dart';
import 'package:medal/modules/authority/screens/profile/authority_profile_screen.dart';
import 'package:medal/modules/authority/screens/notifications/authority_notifications_screen.dart';
import 'package:medal/modules/citizen/authentication/register.dart';

void main() {
  testWidgets('RegistrationRoleSelectionScreen offers Citizen and Authority paths',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: RegistrationRoleSelectionScreen(),
      ),
    );
    await tester.pump();

    // Verify Title and Subtitle
    expect(find.text('Join MEdAL'), findsOneWidget);
    expect(find.text('Citizen Account'), findsOneWidget);
    expect(find.text('Department Authority'), findsOneWidget);
    expect(find.text('Register as Citizen'), findsOneWidget);
    expect(find.text('Register as Authority'), findsOneWidget);

    // Tap "Register as Citizen" -> navigates to RegisterScreen
    await tester.tap(find.text('Register as Citizen'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(RegisterScreen), findsOneWidget);
  });

  testWidgets('AuthorityRegisterScreen renders required fields and review notice',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AuthorityRegisterScreen(),
      ),
    );
    await tester.pump();

    // Verify Review Notice Banner
    expect(find.text('Submission Pending Administrative Review'), findsOneWidget);

    // Verify Official Profile form labels
    expect(find.text('Official Profile Details'), findsOneWidget);
    expect(find.text('Legal Full Name'), findsOneWidget);
    expect(find.text('Identity Proof Number (Masked)'), findsOneWidget);
    expect(find.text('Designation'), findsOneWidget);
    expect(find.text('Department'), findsOneWidget);
    expect(find.text('Official Email Address'), findsOneWidget);
    expect(find.text('Jurisdiction / Assigned Ward'), findsOneWidget);
    expect(find.text('Official Contact Phone'), findsOneWidget);

    // Verify Document Verification section
    expect(find.text('Document Verification'), findsOneWidget);
    expect(find.text('Identity Proof (Aadhaar / National ID)'), findsOneWidget);
    expect(find.text('Official Employment ID / Department Badge'), findsOneWidget);

    // Verify Submit for Admin Review button
    expect(find.text('Submit for Admin Review'), findsOneWidget);
  });

  testWidgets('AuthorityMainScreen navigates between Dashboard, Complaints, Academy, Profile',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AuthorityMainScreen(),
      ),
    );
    await tester.pump();

    // Verify App Header
    expect(find.text('MEdAL'), findsOneWidget);
    expect(find.text('AUTHORITY'), findsOneWidget);

    // Verify Dashboard stat cards
    expect(find.text('Total Assigned'), findsOneWidget);
    expect(find.text('In Progress'), findsOneWidget);
    expect(find.text('Under Review'), findsOneWidget);
    expect(find.text('Resolved'), findsOneWidget);

    // Tap Complaints tab
    await tester.tap(find.text('COMPLAINTS'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(AuthorityComplaintsScreen), findsOneWidget);
    expect(find.text('My Complaints'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Assigned'), findsOneWidget);
    expect(find.text('Reviewing'), findsOneWidget);
    expect(find.text('In Progress'), findsOneWidget);

    // Tap Academy tab
    await tester.tap(find.text('ACADEMY'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(AuthorityAcademyScreen), findsOneWidget);
    expect(find.text('My Courses'), findsOneWidget);
    expect(find.text('My Certificates'), findsOneWidget);

    // Tap Profile tab
    await tester.tap(find.text('PROFILE'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(AuthorityProfileScreen), findsOneWidget);
    expect(find.text('Authority Details'), findsOneWidget);
    expect(find.text('Password Management'), findsOneWidget);
    expect(find.text('Sign Out'), findsOneWidget);
  });

  testWidgets('AuthorityComplaintsScreen filters complaints by status',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AuthorityComplaintsScreen(),
      ),
    );
    await tester.pump();

    // Tap "In Progress" filter
    await tester.tap(find.text('In Progress'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Verify In Progress complaint is shown
    expect(find.text('CMP-2026-4401'), findsOneWidget);
  });

  testWidgets(
      'AuthorityComplaintDetailScreen displays evidence, SDG, and rejection reason dialog',
      (WidgetTester tester) async {
    final complaint = MockAuthorityRepository.complaints.first;

    await tester.pumpWidget(
      MaterialApp(
        home: AuthorityComplaintDetailScreen(complaint: complaint),
      ),
    );
    await tester.pump();

    // Verify ID and Title
    expect(find.text('CMP-2026-4401'), findsOneWidget);
    expect(find.text('Citizen Grievance Description'), findsOneWidget);
    expect(find.text('United Nations SDG Alignment'), findsOneWidget);
    expect(find.text('Clean Water & Sanitation'), findsOneWidget);

    // Verify Action Buttons
    expect(find.text('In Progress'), findsWidgets);
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('Reject'), findsOneWidget);
    expect(find.text('Redirect'), findsOneWidget);

    // Tap Reject button -> requires reason dialog
    await tester.tap(find.text('Reject'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Reject Complaint'), findsOneWidget);
    expect(find.text('A detailed reason is mandatory when rejecting a citizen grievance.'),
        findsOneWidget);

    // Dismiss dialog
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('A detailed reason is mandatory when rejecting a citizen grievance.'),
        findsNothing);
  });

  testWidgets('AuthorityNotificationsScreen displays notification alerts',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AuthorityNotificationsScreen(),
      ),
    );
    await tester.pump();

    expect(find.text('Authority Alerts'), findsOneWidget);
    expect(find.text('Mark All Read'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Urgent / SLA'), findsOneWidget);
  });

  testWidgets('AuthorityLoginScreen renders portal inputs and demo login button',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AuthorityLoginScreen(),
      ),
    );
    await tester.pump();

    expect(find.text('Authority Portal'), findsOneWidget);
    expect(find.text('Officer Sign In'), findsOneWidget);
    expect(find.text('Quick Demo Officer Login (Review Mode)'), findsOneWidget);
    expect(find.text('Sign In as Authority'), findsOneWidget);
  });

  testWidgets('AuthorityComplaintDetailScreen opens Redirect Complaint dialog with mandatory validation',
      (WidgetTester tester) async {
    final complaint = MockAuthorityRepository.complaints.first;

    await tester.pumpWidget(
      MaterialApp(
        home: AuthorityComplaintDetailScreen(complaint: complaint),
      ),
    );
    await tester.pump();

    // Tap Redirect button
    await tester.tap(find.text('Redirect'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Redirect Complaint'), findsOneWidget);
    expect(find.text('Target Authority / Department'), findsOneWidget);
    expect(find.text('Redirection Reason (Mandatory)'), findsOneWidget);

    // Cancel dialog
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Redirection Reason (Mandatory)'), findsNothing);
  });

  testWidgets('AuthorityProfileScreen opens Logout confirmation dialog',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AuthorityProfileScreen(),
      ),
    );
    await tester.pump();

    // Tap Sign Out
    await tester.ensureVisible(find.text('Sign Out'));
    await tester.tap(find.text('Sign Out'));
    await tester.pumpAndSettle();

    expect(find.text('Sign Out of Authority'), findsOneWidget);
    expect(
        find.text(
            'Are you sure you want to end your official session? You will need to sign in again with your official credentials.'),
        findsOneWidget);

    // Tap Cancel
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Sign Out of Authority'), findsNothing);
  });

  testWidgets('AuthorityAcademyScreen shows certificates and opens preview dialog',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AuthorityAcademyScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Tap My Certificates tab
    await tester.tap(find.text('My Certificates'));
    await tester.pumpAndSettle();

    expect(find.text('View Credential'), findsWidgets);

    // Tap View Credential
    await tester.ensureVisible(find.text('View Credential').first);
    await tester.tap(find.text('View Credential').first);
    await tester.pumpAndSettle();

    expect(find.text('Certificate of Completion'), findsOneWidget);
    expect(find.text('Download PDF Certificate'), findsOneWidget);
  });
}
