// Staff "Add Students": top-right button on the Students page, add one student by e-mail, or many from a CSV.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medal/modules/institution/features/institution/models/member.dart';
import 'package:medal/modules/institution/features/institution/providers/institution_provider.dart';
import 'package:medal/modules/institution/features/institution/screens/staff/add_students_screen.dart';
import 'package:medal/modules/institution/features/institution/screens/staff/my_class_screen.dart';
import 'package:medal/modules/institution/routes/app_routes.dart';
import 'package:medal/modules/institution/theme/app_theme.dart';

Map<String, dynamic> _student(int id, String name, String email) => {
      'id': id, 'name': name, 'email': email, 'role': 'student', 'teacher_id': 5,
      'completed_chapters': 0, 'total_chapters': 4, 'progress_pct': 0.0, 'status': 'not_started',
    };

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  // Tests draw text with a very wide placeholder font; ignore the resulting RenderFlex overflow reports.
  final old = FlutterError.onError;
  FlutterError.onError = (d) {
    if (!d.exception.toString().contains('overflowed')) old?.call(d);
  };
  addTearDown(() => FlutterError.onError = old);
}

Future<void> _tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
}

Widget _app({CsvPicker? picker}) => ProviderScope(
      overrides: [studentMembersProvider.overrideWith((ref) async => <InstitutionMember>[])],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: AddStudentsScreen(csvPicker: picker ?? () async => null),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Students page has an Add Students button at the top right that opens the add page', (tester) async {
    _phone(tester);
    final router = GoRouter(
      initialLocation: AppRoutes.staffMyClass,
      routes: [
        GoRoute(path: AppRoutes.staffMyClass, builder: (_, _) => const MyClassScreen()),
        GoRoute(path: AppRoutes.staffAddStudents, builder: (_, _) => const AddStudentsScreen()),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [studentMembersProvider.overrideWith((ref) async => <InstitutionMember>[])],
      child: MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
    ));
    await tester.pumpAndSettle();

    final button = find.byKey(const Key('add_students_button'));
    expect(button, findsOneWidget);
    // top-right: right half of the screen, near the top
    final center = tester.getCenter(button);
    expect(center.dx, greaterThan(360 / 2));
    expect(center.dy, lessThan(200));

    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.byType(AddStudentsScreen), findsOneWidget);
    expect(find.byKey(const Key('send_invite_button')), findsOneWidget);
  });

  testWidgets('Invite one student by e-mail: sends the request and confirms the invite', (tester) async {
    _phone(tester);
    Map<String, dynamic>? sent;
    await http.runWithClient(() async {
      await tester.pumpWidget(_app());
      await tester.enterText(find.byKey(const Key('student_name_field')), '  Asha Kumar ');
      await tester.enterText(find.byKey(const Key('student_email_field')), 'asha@example.com');
      await tester.enterText(find.byKey(const Key('student_department_field')), 'Science');
      await _tapKey(tester, 'send_invite_button');
      await tester.pumpAndSettle();
    }, () => MockClient((request) async {
      expect(request.url.path, '/institution/students/invite');
      sent = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(jsonEncode({
        'student': _student(9, 'Asha Kumar', 'asha@example.com'),
        'email_sent': true, 'temporary_password': null, 'message': 'Invite sent.', 'error': null,
      }), 201);
    }));

    expect(sent, {'name': 'Asha Kumar', 'email': 'asha@example.com', 'department': 'Science'});
    expect(find.text('Invite sent'), findsOneWidget);
    expect(find.textContaining('asha@example.com'), findsWidgets);
    expect(find.byKey(const Key('student_temporary_password')), findsNothing);

    await tester.tap(find.byKey(const Key('invite_result_done')));
    await tester.pumpAndSettle();
    expect(find.text('Invite sent'), findsNothing);
    expect(tester.widget<TextField>(find.byKey(const Key('student_name_field'))).controller!.text, isEmpty);
  });

  testWidgets('If the e-mail could not be sent the teacher is shown the temporary password', (tester) async {
    _phone(tester);
    await http.runWithClient(() async {
      await tester.pumpWidget(_app());
      await tester.enterText(find.byKey(const Key('student_name_field')), 'Bala');
      await tester.enterText(find.byKey(const Key('student_email_field')), 'bala@example.com');
      await _tapKey(tester, 'send_invite_button');
      await tester.pumpAndSettle();
    }, () => MockClient((request) async => http.Response(jsonEncode({
          'student': _student(10, 'Bala', 'bala@example.com'),
          'email_sent': false, 'temporary_password': 'Temp1234ab',
          'message': 'Student added, but the invite e-mail could not be sent.', 'error': 'provider down',
        }), 201)));

    expect(find.text('Student added'), findsOneWidget);
    expect(find.byKey(const Key('student_temporary_password')), findsOneWidget);
    expect(find.text('Temp1234ab'), findsOneWidget);
  });

  testWidgets('Validation and server errors are shown without crashing', (tester) async {
    _phone(tester);
    var calls = 0;
    await http.runWithClient(() async {
      await tester.pumpWidget(_app());
      await _tapKey(tester, 'send_invite_button');
      await tester.pump();
      expect(find.text("Please enter the student's name."), findsOneWidget);
      expect(calls, 0);
      // the floating snackbar sits over the button; dismiss it before the next tap
      ScaffoldMessenger.of(tester.element(find.byType(Scaffold).first)).clearSnackBars();
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('student_name_field')), 'Asha');
      await tester.enterText(find.byKey(const Key('student_email_field')), 'taken@example.com');
      await _tapKey(tester, 'send_invite_button');
      await tester.pumpAndSettle();
      expect(find.text('Email is already registered'), findsOneWidget);
    }, () => MockClient((request) async {
      calls++;
      return http.Response(jsonEncode({'detail': 'Email is already registered'}), 400);
    }));
    expect(calls, 1);
  });

  testWidgets('Upload a CSV: needs a file first, then shows how many were added and which rows failed', (tester) async {
    _phone(tester);
    List<int>? uploaded;
    final csv = utf8.encode('name,email,department\nA,a@example.com,\nB,bad,\nC,c@example.com,\n');
    await http.runWithClient(() async {
      await tester.pumpWidget(_app(picker: () async => PickedCsv('students.csv', csv)));
      await _tapKey(tester, 'mode_csv');
      await tester.pump();
      expect(find.byKey(const Key('csv_template_text')), findsOneWidget);
      expect(find.text('Choose CSV file'), findsOneWidget);
      // upload is disabled until a file is chosen
      expect(tester.widget<ElevatedButton>(find.descendant(
        of: find.byKey(const Key('upload_csv_button')), matching: find.byType(ElevatedButton))).onPressed, isNull);

      await _tapKey(tester, 'choose_csv_button');
      await tester.pump();
      expect(find.textContaining('students.csv'), findsOneWidget);

      await _tapKey(tester, 'upload_csv_button');
      await tester.pumpAndSettle();
    }, () => MockClient((request) async {
      expect(request.url.path, '/institution/students/bulk');
      uploaded = request.bodyBytes;
      return http.Response(jsonEncode({
        'total_rows': 3, 'created': 2, 'failed': 1, 'invites_queued': 2,
        'errors': [{'row': 3, 'email': 'bad', 'error': 'Invalid email address'}],
        'students': [_student(1, 'A', 'a@example.com'), _student(2, 'C', 'c@example.com')],
        'credentials': [],
      }), 200);
    }));

    expect(utf8.decode(uploaded!, allowMalformed: true), contains('a@example.com'));
    expect(find.text('Added 2 of 3 students'), findsOneWidget);
    expect(find.textContaining('being e-mailed to 2 students'), findsOneWidget);
    expect(find.text('Row 3 (bad): Invalid email address'), findsOneWidget);
  });

  testWidgets('CSV rejected by the server shows the reason', (tester) async {
    _phone(tester);
    await http.runWithClient(() async {
      await tester.pumpWidget(_app(picker: () async => PickedCsv('x.csv', utf8.encode('name\nA\n'))));
      await _tapKey(tester, 'mode_csv');
      await tester.pump();
      await _tapKey(tester, 'choose_csv_button');
      await tester.pump();
      await _tapKey(tester, 'upload_csv_button');
      await tester.pumpAndSettle();
    }, () => MockClient((request) async => http.Response(
        jsonEncode({'detail': 'Missing required column(s): email. Expected header: name,email,department'}), 400)));

    expect(find.textContaining('Missing required column(s): email'), findsOneWidget);
  });
}
