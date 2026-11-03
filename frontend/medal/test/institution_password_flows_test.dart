// Principal / Staff password flows: forgot password (code by e-mail) and Manage Password.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medal/core/services/api_service.dart';
import 'package:medal/modules/institution/features/institution/widgets/password_dialogs.dart';
import 'package:medal/modules/institution/theme/app_theme.dart';

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  final old = FlutterError.onError;
  FlutterError.onError = (d) {
    if (!d.exception.toString().contains('overflowed')) old?.call(d);
  };
  addTearDown(() => FlutterError.onError = old);
}

Widget _host() {
  final router = GoRouter(
    initialLocation: '/profile',
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, _) => Scaffold(
          body: Column(children: [
            const Text('LOGIN PAGE'),
            TextButton(onPressed: () => showForgotPasswordFlow(context, initialEmail: 'teach@example.com'), child: const Text('forgot')),
          ]),
        ),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, _) => Scaffold(
          body: Column(children: [
            const Text('PROFILE PAGE'),
            TextButton(onPressed: () => showManagePasswordDialog(context), child: const Text('manage')),
          ]),
        ),
      ),
    ],
  );
  return ProviderScope(child: MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router));
}

http.Response _json(Object body, [int status = 200]) => http.Response(jsonEncode(body), status);

Future<void> _type(WidgetTester tester, String key, String text) async {
  await tester.enterText(find.byKey(Key(key)), text);
  await tester.pump();
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiService().logout(revokeOnServer: false);
  });

  testWidgets('Forgot password: e-mail -> code -> new password resets it', (tester) async {
    _phone(tester);
    final calls = <String>[];
    final bodies = <String, Map<String, dynamic>>{};
    await http.runWithClient(() async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();
      GoRouter.of(tester.element(find.text('PROFILE PAGE'))).go('/login');
      await tester.pumpAndSettle();
      await tester.tap(find.text('forgot'));
      await tester.pumpAndSettle();

      expect(find.text('Reset Password'), findsWidgets);
      expect(tester.widget<TextField>(find.byKey(const Key('forgot_email_field'))).controller!.text, 'teach@example.com');
      await _tap(tester, 'forgot_primary');                       // Send Code
      expect(find.text('Enter the code'), findsOneWidget);

      await _type(tester, 'forgot_code_field', '123456');
      await _tap(tester, 'forgot_primary');                       // Verify
      expect(find.text('Choose a new password'), findsOneWidget);

      await _type(tester, 'forgot_new_password', 'newpass1');
      await _type(tester, 'forgot_confirm_password', 'newpass1');
      await _tap(tester, 'forgot_primary');                       // Reset
    }, () => MockClient((request) async {
      calls.add(request.url.path);
      bodies[request.url.path] = jsonDecode(request.body) as Map<String, dynamic>;
      switch (request.url.path) {
        case '/forgot-password':
          return _json({'message': 'If this email is registered, a 6-digit verification code has been sent.', 'delivery_status': 'sent'});
        case '/verify-otp':
          return _json({'message': 'ok', 'reset_token': 'tok-123'});
        case '/reset-password':
          return _json({'message': 'Password reset successfully.'});
      }
      return _json({}, 404);
    }));

    expect(calls, ['/forgot-password', '/verify-otp', '/reset-password']);
    expect(bodies['/forgot-password'], {'email': 'teach@example.com'});
    expect(bodies['/verify-otp'], {'email': 'teach@example.com', 'otp': '123456'});
    expect(bodies['/reset-password'], {'token': 'tok-123', 'new_password': 'newpass1'});
    expect(find.text('Choose a new password'), findsNothing);               // dialog closed
    expect(find.text('Password reset. Sign in with your new password.'), findsOneWidget);
    expect(find.text('LOGIN PAGE'), findsOneWidget);
  });

  testWidgets('Forgot password: bad input is blocked, server errors are shown, code can be re-sent', (tester) async {
    _phone(tester);
    var requests = 0;
    var resent = 0;
    await http.runWithClient(() async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();
      GoRouter.of(tester.element(find.text('PROFILE PAGE'))).go('/login');
      await tester.pumpAndSettle();
      await tester.tap(find.text('forgot'));
      await tester.pumpAndSettle();

      await _type(tester, 'forgot_email_field', 'nope');
      await _tap(tester, 'forgot_primary');
      expect(find.text('Please enter a valid email address.'), findsOneWidget);
      expect(requests, 0);

      await _type(tester, 'forgot_email_field', 'teach@example.com');
      await _tap(tester, 'forgot_primary');
      expect(find.text('Enter the code'), findsOneWidget);

      await _type(tester, 'forgot_code_field', '12');
      await _tap(tester, 'forgot_primary');
      expect(find.text('Enter the 6-digit code from the email.'), findsOneWidget);

      await _type(tester, 'forgot_code_field', '000000');
      await _tap(tester, 'forgot_primary');
      expect(find.text('Invalid verification code. 4 attempt(s) remaining.'), findsOneWidget);
      expect(find.text('Enter the code'), findsOneWidget);                   // still on the code step

      await _tap(tester, 'forgot_resend');
      expect(resent, 1);

      await _tap(tester, 'forgot_cancel');
      expect(find.text('Enter the code'), findsNothing);
    }, () => MockClient((request) async {
      requests++;
      switch (request.url.path) {
        case '/forgot-password':
          return _json({'message': 'sent', 'delivery_status': 'sent'});
        case '/verify-otp':
          return _json({'detail': 'Invalid verification code. 4 attempt(s) remaining.'}, 400);
        case '/resend-otp':
          resent++;
          return _json({'message': 'A new code has been sent.', 'cooldown_seconds': 60});
      }
      return _json({}, 404);
    }));
  });

  testWidgets('Forgot password: short or mismatched passwords never reach the server', (tester) async {
    _phone(tester);
    final calls = <String>[];
    await http.runWithClient(() async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();
      GoRouter.of(tester.element(find.text('PROFILE PAGE'))).go('/login');
      await tester.pumpAndSettle();
      await tester.tap(find.text('forgot'));
      await tester.pumpAndSettle();
      await _tap(tester, 'forgot_primary');
      await _type(tester, 'forgot_code_field', '123456');
      await _tap(tester, 'forgot_primary');

      await _type(tester, 'forgot_new_password', 'abc');
      await _type(tester, 'forgot_confirm_password', 'abc');
      await _tap(tester, 'forgot_primary');
      expect(find.text('Password must be at least 6 characters.'), findsOneWidget);

      await _type(tester, 'forgot_new_password', 'abcdef1');
      await _type(tester, 'forgot_confirm_password', 'abcdef2');
      await _tap(tester, 'forgot_primary');
      expect(find.text('Passwords do not match.'), findsOneWidget);
    }, () => MockClient((request) async {
      calls.add(request.url.path);
      if (request.url.path == '/verify-otp') return _json({'message': 'ok', 'reset_token': 't'});
      return _json({'message': 'sent'});
    }));
    expect(calls.contains('/reset-password'), isFalse);
  });

  testWidgets('Manage Password: validates, shows the server error, then changes it and signs out', (tester) async {
    _phone(tester);
    Map<String, dynamic>? sent;
    var attempts = 0;
    await http.runWithClient(() async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();
      await tester.tap(find.text('manage'));
      await tester.pumpAndSettle();
      expect(find.text('Manage Password'), findsOneWidget);

      await _tap(tester, 'manage_submit');
      expect(find.text('Enter your current password.'), findsOneWidget);

      await _type(tester, 'manage_current_password', 'oldpass');
      await _type(tester, 'manage_new_password', 'abc');
      await _type(tester, 'manage_confirm_password', 'abc');
      await _tap(tester, 'manage_submit');
      expect(find.text('New password must be at least 6 characters.'), findsOneWidget);

      await _type(tester, 'manage_new_password', 'newpass1');
      await _type(tester, 'manage_confirm_password', 'different');
      await _tap(tester, 'manage_submit');
      expect(find.text('New passwords do not match.'), findsOneWidget);
      expect(attempts, 0);

      await _type(tester, 'manage_confirm_password', 'newpass1');
      await _tap(tester, 'manage_submit');
      expect(find.text('Current password is incorrect'), findsOneWidget);    // server said no; dialog stays
      expect(attempts, 1);

      await _type(tester, 'manage_current_password', 'oldpass2');
      await _tap(tester, 'manage_submit');
    }, () => MockClient((request) async {
      if (request.url.path == '/student/manage-password') {
        attempts++;
        sent = jsonDecode(request.body) as Map<String, dynamic>;
        return attempts == 1
            ? _json({'detail': 'Current password is incorrect'}, 400)
            : _json({'message': 'Password updated successfully'});
      }
      return _json({'message': 'Logged out'});                               // /logout etc.
    }));

    expect(attempts, 2);
    expect(sent, {'current_password': 'oldpass2', 'new_password': 'newpass1'});
    expect(find.text('LOGIN PAGE'), findsOneWidget);                         // signed out, back at login
    expect(find.text('Password updated. Please sign in again with your new password.'), findsOneWidget);
  });
}
