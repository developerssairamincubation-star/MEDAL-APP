import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:medal/core/services/api_service.dart';
import 'package:medal/modules/citizen/authentication/login.dart';
import 'package:medal/modules/citizen/screens/profile.dart';
import 'package:medal/modules/institution/features/institution/services/auth_service.dart';
import 'package:medal/modules/institution/features/institution/screens/student/student_dashboard_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiService().logout();
  });

  tearDown(() async {
    await ApiService().logout();
  });

  group('Role Isolation & Logout Confirmation Tests', () {
    test('Citizen account attempting to log in via Institution AuthService is strictly denied', () async {
      final mockToken = _buildMockJwt(role: 'citizen', sub: '99');
      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/login')) {
          return http.Response(
            jsonEncode({
              'message': 'Login successful',
              'access_token': mockToken,
              'token_type': 'bearer',
              'data': {
                'id': 99,
                'email': 'citizen@example.com',
                'full_name': 'Test Citizen',
                'role': 'citizen',
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{"detail": "Not found"}', 404);
      });

      await http.runWithClient(() async {
        const authService = AuthService();
        final result = await authService.login(
          email: 'citizen@example.com',
          password: 'Password123!',
        );

        expect(result.success, isFalse);
        expect(result.error, contains('Citizen accounts cannot log in to the Institution Portal'));
        expect(ApiService().isAuthenticated, isFalse);
      }, () => mockClient);
    });

    testWidgets('Student account attempting to log in via Citizen LoginScreen is strictly denied',
        (WidgetTester tester) async {
      final mockToken = _buildMockJwt(role: 'student', sub: '501');
      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/login')) {
          return http.Response(
            jsonEncode({
              'message': 'Login successful',
              'access_token': mockToken,
              'token_type': 'bearer',
              'data': {
                'id': 501,
                'email': 'student@medal.gov',
                'full_name': 'Test Student',
                'role': 'student',
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{"detail": "Not found"}', 404);
      });

      await http.runWithClient(() async {
        await tester.pumpWidget(
          const MaterialApp(
            home: LoginScreen(),
          ),
        );
        await tester.pumpAndSettle();

        // Enter student credentials
        await tester.enterText(
          find.widgetWithText(TextField, 'Email Address'),
          'student@medal.gov',
        );
        await tester.enterText(
          find.widgetWithText(TextField, 'Password'),
          'Password123!',
        );

        await tester.tap(find.text('Sign In'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();

        expect(find.text('Access denied: Institution accounts cannot log in through the Citizen Portal. Please use the Institution Portal.'), findsOneWidget);
        expect(ApiService().isAuthenticated, isFalse);
      }, () => mockClient);
    });

    testWidgets('Citizen Profile screen logout button opens confirmation dialog asking "Are you sure you want to log out?"',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ProfileScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll to Log Out button and tap it
      final logoutBtn = find.text('Log Out');
      expect(logoutBtn, findsOneWidget);
      await tester.ensureVisible(logoutBtn);
      await tester.pumpAndSettle();
      await tester.tap(logoutBtn);
      await tester.pumpAndSettle();

      // Confirm dialog appears
      expect(find.text('Are you sure you want to log out?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // Tap Cancel to dismiss dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Are you sure you want to log out?'), findsNothing);
    });

    testWidgets('StudentDashboardScreen renders interactive course cards and stat cards',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: StudentDashboardScreen(showInitialPopup: false),
        ),
      );
      await tester.pumpAndSettle();

      // Check stat cards exist
      expect(find.text('Certification Ready'), findsOneWidget);
      expect(find.text('Enrolled Courses'), findsOneWidget);
      expect(find.text('Credits Earned'), findsOneWidget);
      expect(find.text('Enrollment Pending'), findsOneWidget);

      // Check course cards exist and have View indicators
      expect(find.text('SEEK COURSE 1'), findsOneWidget);
      expect(find.text('SEEK COURSE 2'), findsOneWidget);
      expect(find.text('View'), findsNWidgets(2));
    });
  });
}
