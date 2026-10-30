// test/authority_login_test.dart
// Comprehensive unit, widget, and role enforcement tests for AuthorityLoginScreen.

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medal/core/services/api_service.dart';
import 'package:medal/modules/authority/screens/auth/authority_login_screen.dart';
import 'package:medal/modules/authority/screens/dashboard/authority_main_screen.dart';
import 'package:medal/modules/authority/screens/admin/admin_authority_applications_list_screen.dart';
import 'package:medal/routes/app_routes.dart';

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

  Widget createLoginTestApp() {
    return const MaterialApp(
      home: AuthorityLoginScreen(),
    );
  }

  testWidgets('Validation SnackBar is displayed when submitting empty credentials',
      (WidgetTester tester) async {
    await tester.pumpWidget(createLoginTestApp());
    await tester.pumpAndSettle();

    // Tap "Sign In as Authority" with empty fields
    await tester.tap(find.text('Sign In as Authority'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter your official email/badge ID and password.'), findsOneWidget);
    expect(find.byType(AuthorityMainScreen), findsNothing);
    expect(ApiService().isAuthenticated, isFalse);
  });

  testWidgets('Official login succeeds, stores JWT/role in session, and navigates to AuthorityMainScreen',
      (WidgetTester tester) async {
    final mockToken = _buildMockJwt(role: 'official', sub: '220');
    final mockClient = MockClient((request) async {
      if (request.url.path.endsWith('/login')) {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['email'], equals('officer@corporation.gov.in'));
        expect(body['password'], equals('OfficerPass123!'));

        return http.Response(
          jsonEncode({
            'message': 'Login successful',
            'access_token': mockToken,
            'token_type': 'bearer',
            'data': {
              'id': 220,
              'email': 'officer@corporation.gov.in',
              'full_name': 'Officer Rajesh Varma',
              'role': 'official',
              'is_active': true,
              'is_verified': true,
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('{"detail": "Not found"}', 404);
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(createLoginTestApp());
      await tester.pumpAndSettle();

      // Enter official credentials
      await tester.enterText(
        find.widgetWithText(TextField, 'officer@corporation.gov.in'),
        'officer@corporation.gov.in',
      );
      await tester.enterText(
        find.widgetWithText(TextField, '••••••••'),
        'OfficerPass123!',
      );
      await tester.pumpAndSettle();

      // Tap Sign In button
      await tester.tap(find.text('Sign In as Authority'));
      await tester.pumpAndSettle();

      // Verify Welcome SnackBar
      expect(find.text('Welcome, Officer Rajesh Varma! Authority session verified.'), findsOneWidget);

      // Verify navigation to AuthorityMainScreen
      expect(find.byType(AuthorityMainScreen), findsOneWidget);

      // Verify Session Persistence
      expect(ApiService().isAuthenticated, isTrue);
      expect(ApiService().token, equals(mockToken));
      expect(ApiService().userRole, equals('official'));
      expect(ApiService().currentUserId, equals(220));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('medal_auth_token'), equals(mockToken));
      expect(prefs.getString('medal_auth_role'), equals('official'));
    }, () => mockClient);
  });

  testWidgets('Admin account login succeeds and navigates to AdminAuthorityApplicationsListScreen',
      (WidgetTester tester) async {
    final mockToken = _buildMockJwt(role: 'admin', sub: '1');
    final mockClient = MockClient((request) async {
      if (request.url.path.endsWith('/login')) {
        return http.Response(
          jsonEncode({
            'message': 'Login successful',
            'access_token': mockToken,
            'token_type': 'bearer',
            'data': {
              'id': 1,
              'email': 'commissioner@corporation.gov.in',
              'full_name': 'Municipal Commissioner',
              'role': 'admin',
              'is_active': true,
              'is_verified': true,
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path.contains('/admin/authority-applications')) {
        return http.Response(
          jsonEncode([]),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('{"detail": "Not found"}', 404);
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(createLoginTestApp());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'officer@corporation.gov.in'),
        'commissioner@corporation.gov.in',
      );
      await tester.enterText(
        find.widgetWithText(TextField, '••••••••'),
        'AdminPass123!',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign In as Authority'));
      await tester.pumpAndSettle();

      expect(find.text('Welcome, Municipal Commissioner! Authority session verified.'), findsOneWidget);
      expect(find.byType(AdminAuthorityApplicationsListScreen), findsOneWidget);

      expect(ApiService().isAuthenticated, isTrue);
      expect(ApiService().userRole, equals('admin'));
    }, () => mockClient);
  });

  testWidgets('Citizen account is strictly DENIED access, session wiped, and remains on AuthorityLoginScreen',
      (WidgetTester tester) async {
    final mockCitizenToken = _buildMockJwt(role: 'citizen', sub: '55');
    final mockClient = MockClient((request) async {
      if (request.url.path.endsWith('/login')) {
        return http.Response(
          jsonEncode({
            'message': 'Login successful',
            'access_token': mockCitizenToken,
            'token_type': 'bearer',
            'data': {
              'id': 55,
              'email': 'citizen@example.com',
              'full_name': 'Ordinary Citizen',
              'role': 'citizen',
              'is_active': true,
              'is_verified': true,
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('{"detail": "Not found"}', 404);
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(createLoginTestApp());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'officer@corporation.gov.in'),
        'citizen@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextField, '••••••••'),
        'CitizenSecret123!',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign In as Authority'));
      await tester.pumpAndSettle();

      // Verify Access Denied message
      expect(
        find.text('Access denied: This portal is restricted to Municipal Authorities and Officials.'),
        findsOneWidget,
      );

      // Verify user is NOT permitted into AuthorityMainScreen
      expect(find.byType(AuthorityMainScreen), findsNothing);
      expect(find.byType(AuthorityLoginScreen), findsOneWidget);

      // Verify unauthorized session was cleared completely
      expect(ApiService().isAuthenticated, isFalse);
      expect(ApiService().token, isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('medal_auth_token'), isNull);
      expect(prefs.getString('medal_auth_role'), isNull);

      // Verify entered credentials remain preserved in text fields
      expect(find.text('citizen@example.com'), findsOneWidget);
      expect(find.text('CitizenSecret123!'), findsOneWidget);
    }, () => mockClient);
  });

  testWidgets('Invalid credentials (401) displays error SnackBar and preserves entered credentials',
      (WidgetTester tester) async {
    final mockClient = MockClient((request) async {
      if (request.url.path.endsWith('/login')) {
        return http.Response(
          jsonEncode({'detail': 'Invalid email or password'}),
          401,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('{"detail": "Not found"}', 404);
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(createLoginTestApp());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'officer@corporation.gov.in'),
        'officer.test@corporation.gov.in',
      );
      await tester.enterText(
        find.widgetWithText(TextField, '••••••••'),
        'WrongPassword!',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign In as Authority'));
      await tester.pumpAndSettle();

      expect(find.text('Invalid official email or password. Please try again.'), findsOneWidget);
      expect(find.byType(AuthorityMainScreen), findsNothing);
      expect(ApiService().isAuthenticated, isFalse);

      // Credentials remain preserved in input fields
      expect(find.text('officer.test@corporation.gov.in'), findsOneWidget);
      expect(find.text('WrongPassword!'), findsOneWidget);
    }, () => mockClient);
  });

  testWidgets('Server error (500) displays server error message and preserves inputs',
      (WidgetTester tester) async {
    final mockClient = MockClient((request) async {
      if (request.url.path.endsWith('/login')) {
        return http.Response(
          'Internal Server Error',
          500,
          headers: {'content-type': 'text/plain'},
        );
      }
      return http.Response('Not found', 404);
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(createLoginTestApp());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'officer@corporation.gov.in'),
        'officer.server@corporation.gov.in',
      );
      await tester.enterText(
        find.widgetWithText(TextField, '••••••••'),
        'Password123!',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign In as Authority'));
      await tester.pumpAndSettle();

      expect(find.text('Server error (500). Please try again later.'), findsOneWidget);
      expect(find.byType(AuthorityMainScreen), findsNothing);
      expect(find.text('officer.server@corporation.gov.in'), findsOneWidget);
    }, () => mockClient);
  });

  testWidgets('Network connection failure displays friendly connection error',
      (WidgetTester tester) async {
    final mockClient = MockClient((request) async {
      throw const SocketException('Connection refused');
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(createLoginTestApp());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'officer@corporation.gov.in'),
        'officer.net@corporation.gov.in',
      );
      await tester.enterText(
        find.widgetWithText(TextField, '••••••••'),
        'Password123!',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign In as Authority'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Cannot connect to the MEDAL server'),
        findsOneWidget,
      );
      expect(find.byType(AuthorityMainScreen), findsNothing);
      expect(find.text('officer.net@corporation.gov.in'), findsOneWidget);
    }, () => mockClient);
  });

  testWidgets('Authority login screen does not show Quick Demo option and authenticates via credentials',
      (WidgetTester tester) async {
    final mockToken = _buildMockJwt(role: 'official', sub: '220');
    final mockClient = MockClient((request) async {
      if (request.url.path.endsWith('/login')) {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['email'], equals('rajesh.varma@corporation.gov.in'));
        expect(body['password'], equals('Officer@2026'));

        return http.Response(
          jsonEncode({
            'message': 'Login successful',
            'access_token': mockToken,
            'token_type': 'bearer',
            'data': {
              'id': 220,
              'email': 'rajesh.varma@corporation.gov.in',
              'full_name': 'Rajesh Varma',
              'role': 'official',
              'is_active': true,
              'is_verified': true,
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('{"detail": "Not found"}', 404);
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(createLoginTestApp());
      await tester.pumpAndSettle();

      // Verify Quick Demo button is removed
      expect(find.text('Quick Demo Officer Login (Review Mode)'), findsNothing);

      // Enter credentials manually and tap Sign In
      await tester.enterText(
        find.widgetWithText(TextField, 'officer@corporation.gov.in'),
        'rajesh.varma@corporation.gov.in',
      );
      await tester.enterText(
        find.widgetWithText(TextField, '••••••••'),
        'Officer@2026',
      );
      await tester.tap(find.text('Sign In as Authority'));
      await tester.pumpAndSettle();

      expect(find.text('Welcome, Rajesh Varma! Authority session verified.'), findsOneWidget);
      expect(find.byType(AuthorityMainScreen), findsOneWidget);
      expect(ApiService().isAuthenticated, isTrue);
      expect(ApiService().userRole, equals('official'));
    }, () => mockClient);
  });

  testWidgets('Pending authority login is denied with awaiting approval message',
      (WidgetTester tester) async {
    final mockClient = MockClient((request) async {
      if (request.url.path.endsWith('/login')) {
        return http.Response(
          jsonEncode({'detail': 'Your application is awaiting Admin approval.'}),
          403,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('{"detail": "Not found"}', 404);
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(createLoginTestApp());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'officer@corporation.gov.in'),
        'pending.officer@corporation.gov.in',
      );
      await tester.enterText(
        find.widgetWithText(TextField, '••••••••'),
        'OfficerSecret123!',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign In as Authority'));
      await tester.pumpAndSettle();

      expect(find.text('Your application is awaiting Admin approval.'), findsOneWidget);
      expect(find.byType(AuthorityMainScreen), findsNothing);
      expect(ApiService().isAuthenticated, isFalse);
    }, () => mockClient);
  });

  testWidgets('Rejected authority login is denied with stored rejection reason',
      (WidgetTester tester) async {
    final mockClient = MockClient((request) async {
      if (request.url.path.endsWith('/login')) {
        return http.Response(
          jsonEncode({'detail': 'Your Authority application was rejected: Identity badge expired.'}),
          403,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('{"detail": "Not found"}', 404);
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(createLoginTestApp());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'officer@corporation.gov.in'),
        'rejected.officer@corporation.gov.in',
      );
      await tester.enterText(
        find.widgetWithText(TextField, '••••••••'),
        'OfficerSecret123!',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign In as Authority'));
      await tester.pumpAndSettle();

      expect(find.text('Your Authority application was rejected: Identity badge expired.'), findsOneWidget);
      expect(find.byType(AuthorityMainScreen), findsNothing);
      expect(ApiService().isAuthenticated, isFalse);
    }, () => mockClient);
  });

  testWidgets('RoleSelectionScreen does not display System Administrator Login button (removed per spec)',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        initialRoute: AppRoutes.roleSelection,
        routes: AppRoutes.routes,
      ),
    );
    await tester.pumpAndSettle();

    final adminBtnFinder = find.byKey(const Key('admin_login_option'));
    expect(adminBtnFinder, findsNothing);
    expect(find.text('System Administrator Login'), findsNothing);

    // Both Citizen and Institution cards must be present on the same page
    expect(find.text('Citizen'), findsOneWidget);
    expect(find.text('Institution'), findsOneWidget);
  });

  testWidgets('Citizen Login screen has dedicated Admin Portal button navigating to admin login',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        initialRoute: AppRoutes.citizenLogin,
        routes: AppRoutes.routes,
      ),
    );
    await tester.pumpAndSettle();

    // Verify Institution option was removed
    expect(find.text('Institution / Official Portal'), findsNothing);

    // Verify Authority Portal and Admin Portal exist
    expect(find.text('Authority Portal'), findsOneWidget);

    final adminBtnFinder = find.byKey(const Key('citizen_screen_admin_login_button'));
    expect(adminBtnFinder, findsOneWidget);
    expect(find.text('Admin Portal'), findsOneWidget);

    await tester.ensureVisible(adminBtnFinder);
    await tester.pumpAndSettle();
    await tester.tap(adminBtnFinder);
    await tester.pumpAndSettle();

    expect(find.byType(AuthorityLoginScreen), findsOneWidget);
  });

  testWidgets('Authority/Admin credentials entered on Citizen LoginScreen are strictly DENIED access',
      (WidgetTester tester) async {
    final mockToken = _buildMockJwt(role: 'admin', sub: '232');
    final mockClient = MockClient((request) async {
      if (request.url.path.endsWith('/login')) {
        return http.Response(
          jsonEncode({
            'message': 'Login successful',
            'access_token': mockToken,
            'token_type': 'bearer',
            'data': {
              'id': 232,
              'email': 'admin@medal.gov.in',
              'full_name': 'Chief Administrator',
              'role': 'admin',
              'is_active': true,
              'is_verified': true,
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
        MaterialApp(
          initialRoute: AppRoutes.citizenLogin,
          routes: AppRoutes.routes,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'user@example.com'),
        'admin@medal.gov.in',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Password'),
        'AdminSecretPass123!',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
      await tester.pumpAndSettle();

      expect(find.byType(AdminAuthorityApplicationsListScreen), findsNothing);
      expect(find.textContaining('Authority accounts cannot log in through the Citizen Portal'), findsOneWidget);
      expect(ApiService().isAuthenticated, isFalse);
    }, () => mockClient);
  });
}
