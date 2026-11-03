// Notifications page, bell visibility/read state, shared tabs and nav item,
// certificates page and profile photo crop.

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medal/modules/authority/screens/academy/authority_academy_screen.dart';
import 'package:medal/modules/authority/screens/dashboard/authority_main_screen.dart';
import 'package:medal/modules/authority/screens/notifications/authority_notifications_screen.dart';
import 'package:medal/modules/authority/state/authority_notification_state.dart';
import 'package:medal/modules/authority/widgets/authority_nav_item.dart';
import 'package:medal/widgets/profile_photo_cropper.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthorityNotificationState.instance.reset();
  });

  Future<void> openMain(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: AuthorityMainScreen()));
    await tester.pumpAndSettle();
  }

  testWidgets('Bell shows only on Dashboard and Profile tabs', (tester) async {
    await openMain(tester);
    expect(find.byKey(const Key('notification_bell')), findsOneWidget);

    await tester.tap(find.text('COMPLAINTS'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('notification_bell')), findsNothing);

    await tester.tap(find.text('ACADEMY'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('notification_bell')), findsNothing);

    await tester.tap(find.text('PROFILE'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('notification_bell')), findsOneWidget);
  });

  testWidgets('Red dot clears after opening Notifications, persists, back returns to caller', (tester) async {
    await openMain(tester);
    expect(find.byKey(const Key('notification_unread_dot')), findsOneWidget);

    await tester.tap(find.byKey(const Key('notification_bell')));
    await tester.pumpAndSettle();
    expect(find.byType(AuthorityNotificationsScreen), findsOneWidget);
    // No bottom navigation on the Notifications page
    expect(find.text('Dashboard'), findsNothing);
    expect(find.text('My Complaint'), findsNothing);

    await tester.tap(find.byKey(const Key('notifications_back_button')));
    await tester.pumpAndSettle();
    expect(find.byType(AuthorityNotificationsScreen), findsNothing);
    expect(find.byType(AuthorityMainScreen), findsOneWidget);
    expect(find.byKey(const Key('notification_unread_dot')), findsNothing);

    // "Reload": drop in-memory state; the stored per-user state must keep the dot cleared.
    AuthorityNotificationState.instance.reset();
    await tester.pumpWidget(const SizedBox());
    await openMain(tester);
    expect(find.byKey(const Key('notification_bell')), findsOneWidget);
    expect(find.byKey(const Key('notification_unread_dot')), findsNothing);
  });

  testWidgets('"My Complaint" label is fully shown, active and inactive, on a narrow tab', (tester) async {
    for (final selected in [true, false]) {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 80,
              height: 62,
              child: AuthorityNavItem(
                icon: Icons.article_outlined,
                label: 'My Complaint',
                isSelected: selected,
                onTap: () {},
              ),
            ),
          ),
        ),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
      final text = tester.widget<Text>(find.text('My Complaint'));
      expect(text.overflow, isNot(TextOverflow.ellipsis));
      final fitted = find.ancestor(of: find.text('My Complaint'), matching: find.byType(FittedBox));
      expect(fitted, findsOneWidget);
    }
  });

  testWidgets('Certificates tab has no category filters; Courses tab keeps them', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: AuthorityAcademyScreen())));
    expect(find.text('All Topics'), findsOneWidget);
    await tester.tap(find.text('My Certificates'));
    await tester.pumpAndSettle();
    expect(find.text('All Topics'), findsNothing);
    expect(find.text('Goal oriented'), findsNothing);
    expect(find.text('Top badges'), findsNothing);
  });

  testWidgets('Profile photo crop returns cropped PNG bytes', (tester) async {
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(const Rect.fromLTWH(0, 0, 300, 200), Paint()..color = Colors.teal);
      final img = await recorder.endRecording().toImage(300, 200);
      final png = (await img.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();

      late Future<dynamic> result;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => result = cropProfilePhoto(context, png),
            child: const Text('crop'),
          ),
        ),
      ));
      await tester.tap(find.text('crop'));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byKey(const Key('crop_zoom_slider')), findsOneWidget);
      expect(find.byKey(const Key('crop_shape_toggle')), findsOneWidget);
      await tester.tap(find.byKey(const Key('crop_done_button')));
      await tester.pump();
      final bytes = await result.timeout(const Duration(seconds: 10));
      expect(bytes, isNotNull);
      // PNG signature
      expect((bytes as List<int>).sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
    });
  });
}
