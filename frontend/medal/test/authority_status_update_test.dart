// test/authority_status_update_test.dart
// Dedicated tests for Authority Status Updates, Officer Notes, and Rejection Persistence.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medal/modules/authority/models/authority_models.dart';
import 'package:medal/modules/authority/screens/complaints/authority_complaint_detail_screen.dart';

void main() {
  AuthorityComplaint createTestComplaint({
    String id = 'CMP-2026-4401',
    int? backendId = 4401,
    String? officerNotes,
    String? rejectionReason,
  }) {
    return AuthorityComplaint(
      id: id,
      backendId: backendId,
      title: 'Water Main Burst',
      description: 'Pipeline rupture causing flooding on roadway.',
      category: 'water',
      ward: 'Ward 14',
      address: 'Main Avenue & 5th Cross',
      latitude: 13.0827,
      longitude: 80.2707,
      status: AuthorityComplaintStatus.reviewing,
      priority: AuthorityPriority.high,
      sdg: const SdgInfo(
        number: 6,
        title: 'Clean Water & Sanitation',
        description: 'Ensure availability of water and sanitation.',
        color: Color(0xFF00AED9),
      ),
      evidenceImages: ['assets/images/sample_waste_canal.jpg'],
      upvotes: 42,
      commentsCount: 3,
      reportedAt: DateTime.now().subtract(const Duration(hours: 1)),
      reportedBy: 'Citizen Ramesh',
      officerNotes: officerNotes,
      rejectionReason: rejectionReason,
    );
  }

  testWidgets(
      'AuthorityComplaintDetailScreen saves assigned status and officer notes',
      (WidgetTester tester) async {
    final complaint = createTestComplaint();
    int? savedId;
    String? savedStatus;
    String? savedNote;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AuthorityComplaintDetailScreen(
            complaint: complaint,
            onSaveStatus: (cid, status, note) async {
              savedId = cid;
              savedStatus = status;
              savedNote = note;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Select "Assigned" status pill
    await tester.ensureVisible(find.text('Assigned'));
    await tester.tap(find.text('Assigned'));
    await tester.pumpAndSettle();

    // Enter officer notes
    const testNote = 'Assigned to Ward 14 Rapid Response Pipeline Crew.';
    await tester.enterText(find.byType(TextField).first, testNote);
    await tester.pumpAndSettle();

    // Tap "Submit Update"
    await tester.ensureVisible(find.text('Submit Update'));
    await tester.tap(find.text('Submit Update'));
    await tester.pumpAndSettle();

    // Verify arguments passed to onSaveStatus
    expect(savedId, equals(4401));
    expect(savedStatus, equals('assigned'));
    expect(savedNote, equals(testNote));

    // Verify local complaint model updated
    expect(complaint.status, equals(AuthorityComplaintStatus.assigned));
    expect(complaint.officerNotes, equals(testNote));
  });

  testWidgets(
      'AuthorityComplaintDetailScreen saves rejected status and rejection reason via modal',
      (WidgetTester tester) async {
    final complaint = createTestComplaint();
    int? savedId;
    String? savedStatus;
    String? savedNote;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AuthorityComplaintDetailScreen(
            complaint: complaint,
            onSaveStatus: (cid, status, note) async {
              savedId = cid;
              savedStatus = status;
              savedNote = note;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap "Reject" button to open rejection reason modal
    await tester.ensureVisible(find.text('Reject'));
    await tester.tap(find.text('Reject'));
    await tester.pumpAndSettle();

    expect(find.text('Reject the complaint'), findsOneWidget);

    // Enter rejection reason in the modal text field
    const testReason = 'Private property issue outside municipal boundary.';
    final modalTextField = find.descendant(
      of: find.byType(Dialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(modalTextField, testReason);
    await tester.pumpAndSettle();

    // Submit modal
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    // Verify status update was submitted as 'rejected'
    expect(savedId, equals(4401));
    expect(savedStatus, equals('rejected'));
    expect(savedNote, isNull);
    expect(complaint.status, equals(AuthorityComplaintStatus.rejected));
    expect(complaint.rejectionReason, equals(testReason));
  });

  testWidgets(
      'AuthorityComplaintDetailScreen blocks submission on missing complaint ID and preserves UI state',
      (WidgetTester tester) async {
    // Missing backendId and non-numeric ID format
    final complaint = createTestComplaint(id: 'NON_NUMERIC_ID', backendId: null);
    bool saveCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AuthorityComplaintDetailScreen(
            complaint: complaint,
            onSaveStatus: (cid, status, note) async {
              saveCalled = true;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Select "Resolved"
    await tester.ensureVisible(find.text('Resolved'));
    await tester.tap(find.text('Resolved'));
    await tester.pumpAndSettle();

    // Enter note
    const pendingNote = 'Emergency inspection underway.';
    await tester.enterText(find.byType(TextField).first, pendingNote);
    await tester.pumpAndSettle();

    // Tap "Submit Update"
    await tester.ensureVisible(find.text('Submit Update'));
    await tester.tap(find.text('Submit Update'));
    await tester.pumpAndSettle();

    // Verification: onSaveStatus was NOT called
    expect(saveCalled, isFalse);

    // Error snackbar shown
    expect(
      find.text('Cannot update complaint: Missing or invalid complaint ID.'),
      findsOneWidget,
    );

    // Detail screen remains open with entered text preserved
    expect(find.byType(AuthorityComplaintDetailScreen), findsOneWidget);
    expect(find.text(pendingNote), findsOneWidget);
  });
}
