import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medal/core/services/api_service.dart';

String _createMockJwt({required int expSeconds, String role = 'citizen', String sub = '123'}) {
  final header = base64Url.encode(utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'}))).replaceAll('=', '');
  final payload = base64Url.encode(utf8.encode(jsonEncode({
    'sub': sub,
    'role': role,
    'exp': expSeconds,
  }))).replaceAll('=', '');
  return '$header.$payload.mock_signature';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('JWT Expiration and Decoding Tests', () {
    test('isTokenExpired returns true for past exp', () {
      final pastTimestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000) - 3600; // 1 hour ago
      final expiredToken = _createMockJwt(expSeconds: pastTimestamp);

      expect(ApiService.isTokenExpired(expiredToken), isTrue);
    });

    test('isTokenExpired returns false for future exp', () {
      final futureTimestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600; // 1 hour in future
      final validToken = _createMockJwt(expSeconds: futureTimestamp);

      expect(ApiService.isTokenExpired(validToken), isFalse);
    });

    test('isTokenExpired returns true for malformed tokens', () {
      expect(ApiService.isTokenExpired('not.a.valid.jwt.token'), isTrue);
      expect(ApiService.isTokenExpired(''), isTrue);
      expect(ApiService.isTokenExpired('singlepart'), isTrue);
    });
  });

  group('Session Persistence & Restoration Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('setAuth persists token, user, and role to SharedPreferences', () async {
      final futureTimestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600;
      final token = _createMockJwt(expSeconds: futureTimestamp);
      final user = {
        'id': 1,
        'email': 'citizen@medal.app',
        'full_name': 'Test Citizen',
        'role': 'citizen',
      };

      await ApiService().setAuth(token, user);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('medal_auth_token'), equals(token));
      expect(prefs.getString('medal_auth_role'), equals('citizen'));
      expect(prefs.getString('medal_auth_user'), contains('citizen@medal.app'));
      expect(ApiService().isAuthenticated, isTrue);
      expect(ApiService().userRole, equals('citizen'));
    });

    test('logout clears in-memory state and SharedPreferences', () async {
      final futureTimestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600;
      final token = _createMockJwt(expSeconds: futureTimestamp);
      final user = {'id': 1, 'email': 'citizen@medal.app', 'role': 'citizen'};

      await ApiService().setAuth(token, user);
      expect(ApiService().isAuthenticated, isTrue);

      await ApiService().logout();

      expect(ApiService().token, isNull);
      expect(ApiService().currentUser, isNull);
      expect(ApiService().isAuthenticated, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('medal_auth_token'), isNull);
      expect(prefs.getString('medal_auth_user'), isNull);
      expect(prefs.getString('medal_auth_role'), isNull);
    });

    test('tryRestoreSession restores session when valid token exists', () async {
      final futureTimestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600;
      final token = _createMockJwt(expSeconds: futureTimestamp);
      final user = {
        'id': 10,
        'email': 'persisted@medal.app',
        'full_name': 'Persistent Citizen',
        'role': 'citizen',
      };

      SharedPreferences.setMockInitialValues({
        'medal_auth_token': token,
        'medal_auth_user': jsonEncode(user),
        'medal_auth_role': 'citizen',
      });

      // Clear in-memory state as if app just started
      ApiService().logout();

      final result = await ApiService().tryRestoreSession();

      expect(result.isValid, isTrue);
      expect(result.role, equals('citizen'));
      expect(ApiService().isAuthenticated, isTrue);
      expect(ApiService().token, equals(token));
      expect(ApiService().currentUser?['email'], equals('persisted@medal.app'));
    });

    test('tryRestoreSession rejects and wipes expired token on startup', () async {
      final pastTimestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000) - 3600; // Expired 1 hr ago
      final expiredToken = _createMockJwt(expSeconds: pastTimestamp);

      SharedPreferences.setMockInitialValues({
        'medal_auth_token': expiredToken,
        'medal_auth_user': jsonEncode({'id': 1, 'role': 'citizen'}),
        'medal_auth_role': 'citizen',
      });

      final result = await ApiService().tryRestoreSession();

      expect(result.isValid, isFalse);
      expect(ApiService().isAuthenticated, isFalse);
      expect(ApiService().token, isNull);

      // Verify expired token was cleaned from storage
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('medal_auth_token'), isNull);
    });

    test('tryRestoreSession preserves institutional role architecture', () async {
      final futureTimestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600;
      final token = _createMockJwt(expSeconds: futureTimestamp, role: 'principal');
      final user = {
        'id': 20,
        'email': 'principal@school.edu',
        'full_name': 'Principal Skinner',
        'role': 'principal',
      };

      SharedPreferences.setMockInitialValues({
        'medal_auth_token': token,
        'medal_auth_user': jsonEncode(user),
        'medal_auth_role': 'principal',
      });

      final result = await ApiService().tryRestoreSession();

      expect(result.isValid, isTrue);
      expect(result.role, equals('principal'));
      expect(ApiService().userRole, equals('principal'));
    });

    test('tryRestoreSession preserves official role architecture', () async {
      final futureTimestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600;
      final token = _createMockJwt(expSeconds: futureTimestamp, role: 'official');
      final user = {
        'id': 220,
        'email': 'rajesh.varma@corporation.gov.in',
        'full_name': 'Rajesh Varma',
        'role': 'official',
      };

      SharedPreferences.setMockInitialValues({
        'medal_auth_token': token,
        'medal_auth_user': jsonEncode(user),
        'medal_auth_role': 'official',
      });

      final result = await ApiService().tryRestoreSession();

      expect(result.isValid, isTrue);
      expect(result.role, equals('official'));
      expect(ApiService().userRole, equals('official'));
    });

    test('tryRestoreSession preserves admin role architecture', () async {
      final futureTimestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600;
      final token = _createMockJwt(expSeconds: futureTimestamp, role: 'admin');
      final user = {
        'id': 1,
        'email': 'admin@medal.gov.in',
        'full_name': 'Municipal Commissioner',
        'role': 'admin',
      };

      SharedPreferences.setMockInitialValues({
        'medal_auth_token': token,
        'medal_auth_user': jsonEncode(user),
        'medal_auth_role': 'admin',
      });

      final result = await ApiService().tryRestoreSession();

      expect(result.isValid, isTrue);
      expect(result.role, equals('admin'));
      expect(ApiService().userRole, equals('admin'));
    });
  });
}
