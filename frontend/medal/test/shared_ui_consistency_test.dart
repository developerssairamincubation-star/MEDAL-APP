import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medal/modules/citizen/screens/feed_details.dart';
import 'package:medal/widgets/medal_dialog.dart';
import 'package:medal/widgets/mention_text_field.dart';
import 'package:medal/widgets/post_subject.dart';
import 'package:medal/widgets/profile_ui.dart';

const _officials = [
  {'id': 1, 'full_name': 'Ravi Kumar', 'designation': 'Ward Officer', 'department': 'Sanitation'},
  {'id': 2, 'full_name': 'Meena Iyer', 'designation': 'Engineer', 'department': 'Roads'},
  {'id': 3, 'full_name': 'Rajesh Rao', 'designation': 'Inspector', 'department': 'Water'},
];

Future<List<Map<String, dynamic>>> _fakeFetch(String q) async {
  final t = q.toLowerCase();
  return [
    for (final o in _officials)
      if (o['full_name'].toString().toLowerCase().contains(t)) Map<String, dynamic>.from(o),
  ];
}

void main() {
  testWidgets('shared dialog centres Cancel + Delete under the dialog', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showMedalConfirmDialog(
                context,
                title: 'Delete Report',
                message: 'This cannot be undone.',
                confirmLabel: 'Delete',
                destructive: true,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final dialog = tester.getRect(find.byType(MedalDialogFrame));
    final cancel = tester.getRect(find.widgetWithText(TextButton, 'Cancel'));
    final delete = tester.getRect(find.widgetWithText(ElevatedButton, 'Delete'));
    final group = cancel.expandToInclude(delete);
    expect((group.center.dx - dialog.center.dx).abs(), lessThan(1.0));
    expect(cancel.right, lessThan(delete.left));
  });

  testWidgets('MedalAlertDialog keeps a Row title centred and actions centred', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MedalAlertDialog(
            title: const Row(children: [Icon(Icons.logout_rounded), SizedBox(width: 8), Text('Log Out')]),
            content: const Text('Are you sure?'),
            actions: [TextButton(onPressed: () {}, child: const Text('Cancel'))],
          ),
        ),
      ),
    );
    final dialog = tester.getRect(find.byType(MedalDialogFrame));
    final title = tester.getRect(find.text('Log Out'));
    expect(title.center.dx, closeTo(dialog.center.dx + 12, 14)); // icon + gap shift it slightly
    final cancel = tester.getRect(find.text('Cancel'));
    expect(cancel.center.dx, closeTo(dialog.center.dx, 1.0));
  });

  testWidgets('PostSubject shows above description and hides when it would repeat it', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(children: [
            PostSubject(title: 'Broken pipe', description: 'Water leaking on Main Road'),
            Text('Water leaking on Main Road'),
            PostSubject(title: 'Same text', description: 'Same text'),
          ]),
        ),
      ),
    );
    expect(find.byKey(const Key('post_subject')), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Broken pipe')).dy,
      lessThan(tester.getTopLeft(find.text('Water leaking on Main Road')).dy),
    );
  });

  testWidgets('citizen post detail: subject, location on its own line above SDG, no ellipsis', (tester) async {
    const longLocation =
        'Plot 14, Bharathiyar Road, near the old railway overbridge, Gandhipuram, Coimbatore, Tamil Nadu 641012';
    await tester.pumpWidget(
      MaterialApp(
        home: FeedDetailScreen(feedData: {
          'id': 1,
          'title': 'Broken Water Pipe',
          'description': 'Water leaking near main road intersection.',
          'citizen_name': 'Saicharan',
          'citizen_initials': 'SC',
          'created_at': '2026-09-21T09:00:00Z',
          'status': 'submitted',
          'location': longLocation,
          'sdg_alignment': 'SDG 6',
        }),
      ),
    );
    await tester.pumpAndSettle();

    final loc = find.byKey(const Key('post_location'));
    final locText = tester.widget<Text>(loc);
    expect(locText.maxLines, isNull);
    expect(locText.overflow, isNot(TextOverflow.ellipsis));
    expect(find.text(longLocation), findsOneWidget);
    // SDG chip sits below the location, not beside it.
    expect(tester.getTopLeft(find.text('SDG 6')).dy, greaterThan(tester.getBottomLeft(loc).dy - 1));
    // subject before description
    expect(
      tester.getTopLeft(find.text('Broken Water Pipe')).dy,
      lessThan(tester.getTopLeft(find.text('Water leaking near main road intersection.')).dy),
    );
  });

  group('MentionTextField', () {
    Future<(TextEditingController, List<MentionedOfficial> Function())> pump(WidgetTester tester) async {
      final controller = TextEditingController();
      var mentions = <MentionedOfficial>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: MentionTextField(
                controller: controller,
                fetchOfficials: _fakeFetch,
                onMentionsChanged: (m) => mentions = m,
              ),
            ),
          ),
        ),
      );
      return (controller, () => mentions);
    }

    testWidgets('typing @ opens the list, filters as you type, touch selection inserts a tag', (tester) async {
      final (controller, mentions) = await pump(tester);
      await tester.enterText(find.byType(TextField), 'Leak near @');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(find.byKey(const Key('mention_panel')), findsOneWidget);
      expect(find.byKey(const Key('mention_option_2')), findsOneWidget); // all three listed

      await tester.enterText(find.byType(TextField), 'Leak near @ra');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(find.byKey(const Key('mention_option_1')), findsOneWidget);
      expect(find.byKey(const Key('mention_option_2')), findsNothing);
      expect(find.text('Meena Iyer'), findsNothing); // filtered out

      await tester.tap(find.byKey(const Key('mention_option_0')));
      await tester.pump();
      expect(controller.text, 'Leak near @Ravi Kumar ');
      expect(mentions(), [const MentionedOfficial(id: 1, name: 'Ravi Kumar')]);
      expect(find.byKey(const Key('mention_panel')), findsNothing);
    });

    testWidgets('no match shows a message; keyboard arrows + Enter select', (tester) async {
      final (controller, mentions) = await pump(tester);
      await tester.enterText(find.byType(TextField), '@zzz');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(find.byKey(const Key('mention_no_match')), findsOneWidget);
      expect(find.textContaining('zzz'), findsWidgets);

      await tester.enterText(find.byType(TextField), '@r');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      // "r" lists Ravi, Meena, Rajesh in that order: down, down -> Rajesh
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(controller.text, '@Rajesh Rao ');
      expect(mentions().single.id, 3);
    });

    testWidgets('deleting the tag text drops the stored mention; plain email text opens nothing', (tester) async {
      final (controller, mentions) = await pump(tester);
      await tester.enterText(find.byType(TextField), '@');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      await tester.tap(find.byKey(const Key('mention_option_0'))); // Ravi Kumar
      await tester.pump();
      expect(mentions().length, 1);

      controller.text = 'cleared';
      await tester.pump();
      expect(mentions(), isEmpty);

      await tester.enterText(find.byType(TextField), 'mail me at a@b.com');
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('mention_panel')), findsNothing);
    });
  });

  testWidgets('profile certificates section shows an empty state with no completed courses', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileCertificatesSection(certificates: const [], onDownload: (_) {}),
        ),
      ),
    );
    expect(find.byKey(const Key('profile_no_certificates')), findsOneWidget);
    expect(find.text('Certificate No.'), findsNothing);
  });
}
