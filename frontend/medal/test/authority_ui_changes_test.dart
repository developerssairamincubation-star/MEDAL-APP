// Tests for the authority/login UI changes (back buttons, action bar state,
// SEEK academy content, read-only profile).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medal/modules/authority/models/authority_models.dart';
import 'package:medal/modules/authority/screens/academy/authority_academy_screen.dart';
import 'package:medal/modules/authority/screens/academy/authority_seek_course_screen.dart';
import 'package:medal/modules/authority/screens/dashboard/authority_post_detail_screen.dart';
import 'package:medal/modules/authority/screens/profile/authority_edit_profile_screen.dart';
import 'package:medal/core/utils/location_text.dart';
import 'package:medal/widgets/post_action_bar.dart';

void main() {
  testWidgets('PostActionBar: grey by default, blue and bold when active', (tester) async {
    Future<void> pump({required bool up, required bool re}) => tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: PostActionBar(
              upvotes: 3,
              comments: 1,
              reposts: 2,
              isUpvoted: up,
              isReposted: re,
              onUpvote: () {},
              onComment: () {},
              onRepost: () {},
            ),
          ),
        ));

    TextStyle? styleOf(String text) => tester.widget<Text>(find.text(text)).style;

    await pump(up: false, re: false);
    expect(styleOf('Upvote (3)')!.color, const Color(0xFF5D6478));
    expect(styleOf('Repost(2)')!.color, const Color(0xFF5D6478));
    expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsOneWidget);

    await pump(up: true, re: true);
    expect(styleOf('Upvote (3)')!.color, const Color(0xFF0467B6));
    expect(styleOf('Upvote (3)')!.fontWeight, FontWeight.w800);
    expect(styleOf('Repost(2)')!.color, const Color(0xFF0467B6));
    expect(styleOf('Repost(2)')!.fontWeight, FontWeight.w800);
  });

  testWidgets('Post detail has a back button that pops to the previous screen', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AuthorityPostDetailScreen(
                  complaintId: 1,
                  complaintData: {
                    'id': 1,
                    'description': 'Test post',
                    'location_address': 'A very long place name, Some Locality, Some City, Some State, India',
                    'sdg_alignment': 'SDG 11',
                  },
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    tester.takeException();
    expect(find.byKey(const Key('post_detail_back_button')), findsOneWidget);
    await tester.tap(find.byKey(const Key('post_detail_back_button')));
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
  });

  test('displayLocation prefers readable place names over coordinates', () {
    expect(displayLocation({'location_address': '12.9716, 77.5946', 'location': 'MG Road, Bengaluru'}),
        'MG Road, Bengaluru');
    expect(displayLocation({'location_address': 'Anna Nagar, Chennai'}), 'Anna Nagar, Chennai');
    expect(displayLocation({'location': '12.9716, 77.5946'}), '12.9716, 77.5946');
    expect(displayLocation({}), 'Location not specified');
  });

  testWidgets('Academy has no lorem ipsum and Continue Learning opens SEEK content', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: AuthorityAcademyScreen())));
    expect(find.textContaining('Lorem'), findsNothing);
    await tester.tap(find.text('Continue Learning'));
    await tester.pumpAndSettle();
    expect(find.byType(AuthoritySeekCourseScreen), findsOneWidget);
    expect(find.textContaining('Module 1'), findsOneWidget);
    await tester.tap(find.byKey(const Key('seek_course_back_button')));
    await tester.pumpAndSettle();
    expect(find.byType(AuthoritySeekCourseScreen), findsNothing);

    await tester.tap(find.text('My Certificates'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Lorem'), findsNothing);
  });

  test('complainant role label', () {
    expect(AuthorityComplaint.roleLabelFor('citizen'), 'Citizen');
    expect(AuthorityComplaint.roleLabelFor('official'), 'Authority');
    expect(AuthorityComplaint.roleLabelFor(null), 'Citizen');
  });

  testWidgets('Profile opens read-only; Edit unlocks fields with Save/Cancel', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AuthorityEditProfileScreen(onProfileUpdated: () {}),
    ));
    await tester.pump();

    TextField nameField() => tester.widget<TextField>(find.byType(TextField).first);
    expect(nameField().readOnly, isTrue);
    expect(find.byKey(const Key('profile_save_button')), findsNothing);
    expect(find.text('Edit profile picture'), findsNothing);

    await tester.ensureVisible(find.byKey(const Key('profile_edit_button')));
    await tester.tap(find.byKey(const Key('profile_edit_button')));
    await tester.pump();
    expect(nameField().readOnly, isFalse);
    expect(find.byKey(const Key('profile_save_button')), findsOneWidget);
    expect(find.byKey(const Key('profile_cancel_button')), findsOneWidget);
    expect(find.text('Edit profile picture'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Changed Name');
    await tester.ensureVisible(find.byKey(const Key('profile_cancel_button')));
    await tester.tap(find.byKey(const Key('profile_cancel_button')));
    await tester.pump();
    expect(nameField().readOnly, isTrue);
    expect(find.text('Changed Name'), findsNothing);
  });
}
