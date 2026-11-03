// test/authority_module_test.dart
// Comprehensive widget and flow tests for the MEDAL Authority Module.

import 'package:medal/core/services/course_progress_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medal/modules/authority/models/authority_models.dart';
import 'package:medal/modules/authority/screens/auth/registration_role_selection_screen.dart';
import 'package:medal/modules/authority/screens/auth/authority_register_screen.dart';
import 'package:medal/modules/authority/screens/auth/authority_login_screen.dart';
import 'package:medal/modules/authority/screens/dashboard/authority_main_screen.dart';
import 'package:medal/modules/authority/screens/dashboard/authority_post_detail_screen.dart';
import 'package:medal/modules/authority/screens/dashboard/authority_comment_thread_screen.dart';
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

    // Scroll to and tap Reject button -> requires reason dialog
    await tester.ensureVisible(find.text('Reject'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reject'));
    await tester.pumpAndSettle();

    expect(find.text('Reject Complaint'), findsOneWidget);
    expect(find.text('A detailed reason is mandatory when rejecting a citizen grievance.'),
        findsOneWidget);

    // Dismiss dialog
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

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

  testWidgets('AuthorityLoginScreen renders portal inputs and sign in button without quick demo',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AuthorityLoginScreen(),
      ),
    );
    await tester.pump();

    expect(find.text('Authority Portal'), findsOneWidget);
    expect(find.text('Officer Sign In'), findsOneWidget);
    expect(find.text('Quick Demo Officer Login (Review Mode)'), findsNothing);
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

    // Scroll to and tap Redirect button
    await tester.ensureVisible(find.text('Redirect'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Redirect'));
    await tester.pumpAndSettle();

    expect(find.text('Redirect Complaint'), findsOneWidget);
    expect(find.text('Target Authority / Department'), findsOneWidget);
    expect(find.text('Redirection Reason (Mandatory)'), findsOneWidget);

    // Cancel dialog
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Redirection Reason (Mandatory)'), findsNothing);
  });

  testWidgets('AuthorityProfileScreen opens Logout confirmation dialog and respects No / Yes',
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

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.descendant(of: find.byType(Dialog), matching: find.text('Log Out')), findsOneWidget);
    expect(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.text('Are you sure\nyou want to log out?'),
        ),
        findsOneWidget);
    expect(find.descendant(of: find.byType(Dialog), matching: find.text('No')), findsOneWidget);
    expect(find.descendant(of: find.byType(Dialog), matching: find.text('Yes')), findsOneWidget);

    // Tap No -> closes dialog, remains on profile
    await tester.tap(find.descendant(of: find.byType(Dialog), matching: find.text('No')));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsNothing);
    expect(find.byType(AuthorityProfileScreen), findsOneWidget);

    // Open again and tap Yes -> logs out
    await tester.tap(find.text('Sign Out'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    await tester.tap(find.descendant(of: find.byType(Dialog), matching: find.text('Yes')));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('AuthorityComplaintDetailScreen back button exits directly when no unsaved changes',
      (WidgetTester tester) async {
    final complaint = MockAuthorityRepository.complaints.first;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => Navigator.push(
                ctx,
                MaterialPageRoute(
                  builder: (_) => AuthorityComplaintDetailScreen(complaint: complaint),
                ),
              ),
              child: const Text('Open Detail'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open Detail'));
    await tester.pumpAndSettle();

    expect(find.byType(AuthorityComplaintDetailScreen), findsOneWidget);

    // System back navigation with NO unsaved changes
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    await navigator.maybePop();
    await tester.pumpAndSettle();

    // Should pop directly without showing Cancel Reporting dialog
    expect(find.text('CANCEL REPORTING'), findsNothing);
    expect(find.byType(AuthorityComplaintDetailScreen), findsNothing);
  });

  testWidgets('AuthorityComplaintDetailScreen shows Cancel Reporting on unsaved note and respects No / Yes',
      (WidgetTester tester) async {
    final complaint = MockAuthorityRepository.complaints.first;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => Navigator.push(
                ctx,
                MaterialPageRoute(
                  builder: (_) => AuthorityComplaintDetailScreen(complaint: complaint),
                ),
              ),
              child: const Text('Open Detail'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open Detail'));
    await tester.pumpAndSettle();

    expect(find.byType(AuthorityComplaintDetailScreen), findsOneWidget);

    // Add note to create unsaved changes
    await tester.enterText(find.byType(TextField).first, 'New progress notes on canal waste');
    await tester.pumpAndSettle();

    // System back navigation with unsaved changes
    final navigator2 = tester.state<NavigatorState>(find.byType(Navigator));
    await navigator2.maybePop();
    await tester.pumpAndSettle();

    // Cancel Reporting dialog should appear
    expect(find.text('CANCEL REPORTING'), findsOneWidget);
    expect(
      find.text(
        'Are you sure to exit the reporting page?\nThe changes you have made will not be\nsaved.',
      ),
      findsOneWidget,
    );
    expect(find.text('No'), findsOneWidget);
    expect(find.text('Yes'), findsOneWidget);

    // Tap No -> dialog closes, user remains on report page with text intact
    await tester.tap(find.text('No'));
    await tester.pumpAndSettle();

    expect(find.text('CANCEL REPORTING'), findsNothing);
    expect(find.byType(AuthorityComplaintDetailScreen), findsOneWidget);
    expect(find.text('New progress notes on canal waste'), findsOneWidget);

    // Tap back button again via system back navigation
    await navigator2.maybePop();
    await tester.pumpAndSettle();

    expect(find.text('CANCEL REPORTING'), findsOneWidget);

    // Tap Yes -> dialog closes, changes discarded, user exits
    await tester.tap(find.text('Yes'));
    await tester.pumpAndSettle();

    expect(find.text('CANCEL REPORTING'), findsNothing);
    expect(find.byType(AuthorityComplaintDetailScreen), findsNothing);
  });

  testWidgets(
      'AuthorityAcademyScreen shows no certificate until the course is completed, then opens preview dialog',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    CourseProgressStore.instance.reset();
    await tester.pumpWidget(
      const MaterialApp(
        home: AuthorityAcademyScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Tap My Certificates tab: nothing completed yet -> empty state, no fake cards
    await tester.tap(find.text('My Certificates'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('no_certificates_state')), findsOneWidget);
    expect(find.text('View Credential'), findsNothing);

    // Completing every lesson issues the certificate
    await tester.runAsync(() async {
      for (final key in SeekCourseContent.allLessonKeys) {
        await CourseProgressStore.instance.setLessonDone(
          key,
          true,
          courseId: SeekCourseContent.courseId,
          allLessonKeys: SeekCourseContent.allLessonKeys,
        );
      }
    });
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('no_certificates_state')), findsNothing);
    expect(find.text('View Credential'), findsOneWidget);

    // Tap View Credential
    await tester.ensureVisible(find.text('View Credential').first);
    await tester.tap(find.text('View Credential').first);
    await tester.pumpAndSettle();

    expect(find.text('Certificate of Completion'), findsOneWidget);
    expect(find.text('Download PDF Certificate'), findsOneWidget);
    CourseProgressStore.instance.reset();
  });

  testWidgets(
      'Dashboard post tap navigates to Post Details, and tapping comment opens Comment Thread',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AuthorityMainScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Dashboard post is visible
    expect(
      find.text(
        'Critical waste management failure observed at the canal junction. Local community impact rising due to blockage.',
      ),
      findsOneWidget,
    );

    // Tap on the post card
    await tester.tap(
      find.text(
        'Critical waste management failure observed at the canal junction. Local community impact rising due to blockage.',
      ),
    );
    await tester.pumpAndSettle();

    // Verify AuthorityPostDetailScreen is opened (NOT AuthorityComplaintDetailScreen)
    expect(find.byType(AuthorityPostDetailScreen), findsOneWidget);
    expect(find.byType(AuthorityComplaintDetailScreen), findsNothing);

    // Verify Post Details elements
    // No official is tagged on this sample post, so nothing is invented for the "assigned" list.
    expect(find.text('Authorities assigned:'), findsNothing);
    expect(find.text('@elenarodriguez'), findsNothing);
    expect(find.text('Lisa Godwin'), findsOneWidget);
    expect(find.text('Kevin Xanty'), findsOneWidget);
    expect(find.text('Divya ken'), findsOneWidget);

    // Scroll to and tap on Kevin Xanty's comment to open Comment Thread
    await tester.ensureVisible(find.text('Kevin Xanty'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kevin Xanty'));
    await tester.pumpAndSettle();

    // Verify AuthorityCommentThreadScreen is opened
    expect(find.byType(AuthorityCommentThreadScreen), findsOneWidget);
    expect(find.text('Chia Sen'), findsOneWidget);
    expect(find.text('Steve Mark'), findsOneWidget);
    expect(find.text('Liya Fatima'), findsOneWidget);

    // System back navigation from Comment Thread back to Post Details
    final threadNavigator = tester.state<NavigatorState>(find.byType(Navigator));
    await threadNavigator.maybePop();
    await tester.pumpAndSettle();

    // Verify back to AuthorityPostDetailScreen
    expect(find.byType(AuthorityPostDetailScreen), findsOneWidget);
  });

  testWidgets(
      'AuthorityComplaintDetailScreen Submit Update saves changes, pops page, and updates parent state',
      (WidgetTester tester) async {
    final complaint = AuthorityComplaint(
      id: 'CMP-2026-4401',
      title: 'Critical Waste Management Failure',
      description: 'Critical waste management failure observed at canal junction.',
      category: 'Waste management',
      ward: 'Ward 62',
      address: 'Bharathiyar street',
      latitude: 13.0827,
      longitude: 80.2707,
      status: AuthorityComplaintStatus.inProgress,
      priority: AuthorityPriority.critical,
      sdg: const SdgInfo(
        number: 13,
        title: 'Climate Action',
        description: 'Take urgent action to combat climate change and its impacts.',
        color: Color(0xFF3F7E44),
      ),
      evidenceImages: ['assets/images/sample_waste_canal.jpg'],
      upvotes: 124,
      commentsCount: 12,
      reportedAt: DateTime.parse('2026-10-06 10:30:00'),
      reportedBy: 'James Doe',
      officerNotes: 'Initial note',
    );

    int savedId = 0;
    String savedStatus = '';
    String? savedNote;
    bool callbackInvoked = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => Navigator.push(
                ctx,
                MaterialPageRoute(
                  builder: (_) => AuthorityComplaintDetailScreen(
                    complaint: complaint,
                    onStatusChanged: () {
                      callbackInvoked = true;
                    },
                    onSaveStatus: (cid, status, note) async {
                      savedId = cid;
                      savedStatus = status;
                      savedNote = note;
                    },
                  ),
                ),
              ),
              child: const Text('Open Complaint Detail'),
            ),
          ),
        ),
      ),
    );

    // Open screen
    await tester.tap(find.text('Open Complaint Detail'));
    await tester.pumpAndSettle();

    expect(find.byType(AuthorityComplaintDetailScreen), findsOneWidget);

    // Select "Resolved" status pill
    await tester.ensureVisible(find.text('Resolved'));
    await tester.tap(find.text('Resolved'));
    await tester.pumpAndSettle();

    // Enter note
    await tester.enterText(
      find.byType(TextField).first,
      'Canal cleared by sanitation team and inspected.',
    );
    await tester.pumpAndSettle();

    // Tap "Submit Update"
    await tester.ensureVisible(find.text('Submit Update'));
    await tester.tap(find.text('Submit Update'));
    await tester.pumpAndSettle();

    // Verify backend call arguments
    expect(savedId, equals(4401));
    expect(savedStatus, equals('resolved'));
    expect(savedNote, equals('Canal cleared by sanitation team and inspected.'));

    // Verify callback was invoked and page popped
    expect(callbackInvoked, isTrue);
    expect(find.byType(AuthorityComplaintDetailScreen), findsNothing);
    expect(complaint.status, equals(AuthorityComplaintStatus.completed));
    expect(complaint.officerNotes, equals('Canal cleared by sanitation team and inspected.'));
  });

  testWidgets(
      'AuthorityComplaintDetailScreen Submit Update failure keeps user on page with entered data preserved',
      (WidgetTester tester) async {
    final complaint = AuthorityComplaint(
      id: 'CMP-2026-4401',
      title: 'Critical Waste Management Failure',
      description: 'Critical waste management failure observed at canal junction.',
      category: 'Waste management',
      ward: 'Ward 62',
      address: 'Bharathiyar street',
      latitude: 13.0827,
      longitude: 80.2707,
      status: AuthorityComplaintStatus.inProgress,
      priority: AuthorityPriority.critical,
      sdg: const SdgInfo(
        number: 13,
        title: 'Climate Action',
        description: 'Take urgent action to combat climate change and its impacts.',
        color: Color(0xFF3F7E44),
      ),
      evidenceImages: ['assets/images/sample_waste_canal.jpg'],
      upvotes: 124,
      commentsCount: 12,
      reportedAt: DateTime.parse('2026-10-06 10:30:00'),
      reportedBy: 'James Doe',
      officerNotes: '',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => Navigator.push(
                ctx,
                MaterialPageRoute(
                  builder: (_) => AuthorityComplaintDetailScreen(
                    complaint: complaint,
                    onSaveStatus: (cid, status, note) async {
                      throw Exception('Database lock timeout. Status not saved.');
                    },
                  ),
                ),
              ),
              child: const Text('Open Complaint Detail'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Complaint Detail'));
    await tester.pumpAndSettle();

    expect(find.byType(AuthorityComplaintDetailScreen), findsOneWidget);

    // Select "Assigned"
    await tester.ensureVisible(find.text('Assigned'));
    await tester.tap(find.text('Assigned'));
    await tester.pumpAndSettle();

    // Enter note
    const inputNote = 'Assigning priority response crew';
    await tester.enterText(find.byType(TextField).first, inputNote);
    await tester.pumpAndSettle();

    // Tap "Submit Update"
    await tester.ensureVisible(find.text('Submit Update'));
    await tester.tap(find.text('Submit Update'));
    await tester.pumpAndSettle();

    // Error message must be visible
    expect(find.text('Database lock timeout. Status not saved.'), findsOneWidget);

    // Detail page must REMAIN open
    expect(find.byType(AuthorityComplaintDetailScreen), findsOneWidget);

    // Entered text must be PRESERVED
    expect(find.text(inputNote), findsOneWidget);

    // Complaint object status was NOT mutated on failure
    expect(complaint.status, equals(AuthorityComplaintStatus.inProgress));
  });

  testWidgets(
      'Navigating from AuthorityComplaintsScreen to Detail, submitting update returns to Complaints with updated status',
      (WidgetTester tester) async {
    final firstComplaint = MockAuthorityRepository.complaints.first;
    firstComplaint.status = AuthorityComplaintStatus.reviewing;

    AuthorityComplaintDetailScreen.globalSaveStatusOverride =
        (cid, status, note) async {};
    addTearDown(() {
      AuthorityComplaintDetailScreen.globalSaveStatusOverride = null;
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: AuthorityComplaintsScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify initial screen is AuthorityComplaintsScreen
    expect(find.byType(AuthorityComplaintsScreen), findsOneWidget);
    expect(find.text(firstComplaint.title), findsWidgets);

    // Tap on the complaint card
    await tester.tap(find.text(firstComplaint.title).first);
    await tester.pumpAndSettle();

    // Verify AuthorityComplaintDetailScreen is pushed
    expect(find.byType(AuthorityComplaintDetailScreen), findsOneWidget);

    // Select "Resolved" status
    await tester.ensureVisible(find.text('Resolved'));
    await tester.tap(find.text('Resolved'));
    await tester.pumpAndSettle();

    // Enter an update note
    await tester.enterText(
      find.byType(TextField).first,
      'Field inspection completed. Issue resolved.',
    );
    await tester.pumpAndSettle();

    // Submit Update
    await tester.ensureVisible(find.text('Submit Update'));
    await tester.tap(find.text('Submit Update'));
    await tester.pumpAndSettle();

    // Verify returning to AuthorityComplaintsScreen (NOT Dashboard or other screen)
    expect(find.byType(AuthorityComplaintDetailScreen), findsNothing);
    expect(find.byType(AuthorityComplaintsScreen), findsOneWidget);

    // Verify updated complaint status in the list
    expect(firstComplaint.status, equals(AuthorityComplaintStatus.completed));
  });
}
