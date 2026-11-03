// lib/core/services/api_service.dart
// Centralized HTTP service for connecting the Flutter application to the FastAPI backend.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medal/config/api_config.dart';

class SessionRestoreResult {
  final bool isValid;
  final String role;
  final Map<String, dynamic>? user;

  const SessionRestoreResult({
    required this.isValid,
    this.role = 'citizen',
    this.user,
  });
}

class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  static bool get isDesktopOrWeb {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  /// Backend API Base URL — driven by lib/config/api_config.dart.
  /// Uses production Render HTTPS URL by default, or environment override via APP_ENV.
  String baseUrl = ApiConfig.baseUrl;

  /// Resolves image URLs for both Cloudinary HTTPS, local uploads and MinIO object storage.
  /// Dynamically maps localhost/LAN hosts to the active server host for web, desktop, and mobile.
  String resolveImageUrl(String? url) {
    if (url == null || url.trim().isEmpty) return '';
    final trimmed = url.trim();

    final apiUri = Uri.tryParse(baseUrl);
    final targetHost = (apiUri != null && apiUri.host.isNotEmpty) ? apiUri.host : '127.0.0.1';
    final targetScheme = (apiUri != null && apiUri.scheme.isNotEmpty) ? apiUri.scheme : 'http';

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      final uri = Uri.tryParse(trimmed);
      if (uri == null) return trimmed;

      // Cloudinary or external CDN URLs are direct secure HTTPS URLs
      if (uri.host.contains('cloudinary.com') || uri.host.contains('res.cloudinary.com')) {
        return trimmed;
      }

      // Check if this is a MinIO URL (port 9000 or contains /medal-evidence/, /reports/, or /profiles/)
      if (uri.port == 9000 ||
          uri.path.contains('medal-evidence') ||
          uri.path.contains('/reports/') ||
          uri.path.contains('/profiles/')) {
        final port = uri.port > 0 ? uri.port : 9000;
        final scheme = targetHost.contains('onrender.com') ? 'http' : targetScheme;
        return Uri(
          scheme: scheme,
          host: targetHost,
          port: port,
          path: uri.path,
          query: uri.query.isNotEmpty ? uri.query : null,
        ).toString();
      }

      // Check if this is a backend static upload URL (port 8000 or path starts with /uploads)
      if (uri.port == 8000 || uri.path.startsWith('/uploads')) {
        final port = (apiUri != null && apiUri.port > 0) ? apiUri.port : 8000;
        return Uri(
          scheme: targetScheme,
          host: targetHost,
          port: port,
          path: uri.path,
          query: uri.query.isNotEmpty ? uri.query : null,
        ).toString();
      }

      // External HTTP image (e.g. Unsplash, CDN)
      return trimmed;
    }

    // Relative paths
    if (trimmed.startsWith('/medal-evidence') || trimmed.startsWith('medal-evidence/')) {
      final cleanPath = trimmed.startsWith('/') ? trimmed : '/$trimmed';
      return '$targetScheme://$targetHost:9000$cleanPath';
    }

    if (trimmed.startsWith('/reports/') ||
        trimmed.startsWith('reports/') ||
        trimmed.startsWith('/profiles/') ||
        trimmed.startsWith('profiles/')) {
      final cleanPath = trimmed.startsWith('/') ? trimmed : '/$trimmed';
      return '$targetScheme://$targetHost:9000/medal-evidence$cleanPath';
    }

    if (trimmed.startsWith('/')) {
      return '$baseUrl$trimmed';
    }

    return '$baseUrl/$trimmed';
  }

  static const String _kAuthTokenKey = 'medal_auth_token';
  static const String _kAuthUserKey = 'medal_auth_user';
  static const String _kAuthRoleKey = 'medal_auth_role';

  String? _token;
  Map<String, dynamic>? _currentUser;
  String? _cachedRole;

  String? get token => _token;
  Map<String, dynamic>? get currentUser => _currentUser;
  bool get isAuthenticated => _token != null && _token!.isNotEmpty;

  String get userRole {
    if (_currentUser != null && _currentUser!['role'] != null) {
      return _currentUser!['role'].toString().trim().toLowerCase();
    }
    if (_token != null) {
      try {
        final parts = _token!.split('.');
        if (parts.length == 3) {
          final payload = jsonDecode(_decodeBase64(parts[1]));
          if (payload is Map && payload['role'] != null) {
            return payload['role'].toString().trim().toLowerCase();
          }
        }
      } catch (_) {}
    }
    if (_cachedRole != null && _cachedRole!.isNotEmpty) {
      return _cachedRole!.trim().toLowerCase();
    }
    return 'citizen';
  }

  int? get currentUserId {
    if (_currentUser != null && _currentUser!['id'] != null) {
      if (_currentUser!['id'] is int) return _currentUser!['id'];
      return int.tryParse(_currentUser!['id'].toString());
    }
    if (_token != null) {
      try {
        final parts = _token!.split('.');
        if (parts.length == 3) {
          final payload = jsonDecode(_decodeBase64(parts[1]));
          if (payload is Map && payload['sub'] != null) {
            return int.tryParse(payload['sub'].toString());
          }
        }
      } catch (_) {}
    }
    return null;
  }

  Future<void> setAuth(String token, Map<String, dynamic> user) async {
    _token = token;
    _currentUser = user;
    _cachedRole = user['role']?.toString();
    await _persistSession();
  }

  /// Ends the session: tells the server to revoke the token (best effort), then clears local state.
  /// Pass [revokeOnServer] = false when the token is already known to be dead (401 / expired).
  Future<void> logout({bool revokeOnServer = true}) async {
    final token = _token;
    if (revokeOnServer && token != null && token.isNotEmpty) {
      try {
        await http.post(
          Uri.parse('$baseUrl/logout'),
          headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
        ).timeout(const Duration(seconds: 4));
      } catch (e) {
        debugPrint('Server-side logout failed (token will expire on its own): $e');
      }
    }
    _token = null;
    _currentUser = null;
    _cachedRole = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kAuthTokenKey);
      await prefs.remove(_kAuthUserKey);
      await prefs.remove(_kAuthRoleKey);
    } catch (e) {
      debugPrint('Error clearing local session: $e');
    }
  }

  Future<void> _persistSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_token != null && _token!.isNotEmpty) {
        await prefs.setString(_kAuthTokenKey, _token!);
      } else {
        await prefs.remove(_kAuthTokenKey);
      }

      if (_currentUser != null) {
        await prefs.setString(_kAuthUserKey, jsonEncode(_currentUser));
        final role = _currentUser?['role']?.toString() ?? 'citizen';
        await prefs.setString(_kAuthRoleKey, role);
      } else {
        await prefs.remove(_kAuthUserKey);
        await prefs.remove(_kAuthRoleKey);
      }
    } catch (e) {
      debugPrint('Error persisting local session: $e');
    }
  }

  /// Checks if a JWT token has expired by inspecting the 'exp' claim in its payload.
  static bool isTokenExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      final payloadStr = _decodeBase64(parts[1]);
      final payload = jsonDecode(payloadStr);
      if (payload is Map<String, dynamic> && payload.containsKey('exp')) {
        final exp = payload['exp'];
        if (exp is num) {
          final expiryDate = DateTime.fromMillisecondsSinceEpoch(
            exp.toInt() * 1000,
            isUtc: true,
          );
          return DateTime.now().toUtc().isAfter(
                expiryDate.subtract(const Duration(seconds: 10)),
              );
        }
      }
      return false;
    } catch (_) {
      return true;
    }
  }

  static String _decodeBase64(String str) {
    String output = str.replaceAll('-', '+').replaceAll('_', '/');
    switch (output.length % 4) {
      case 0:
        break;
      case 2:
        output += '==';
        break;
      case 3:
        output += '=';
        break;
      default:
        throw Exception('Illegal base64url string!');
    }
    return utf8.decode(base64Url.decode(output));
  }

  /// Attempts to restore the session from SharedPreferences.
  /// Validates expiration, restores in-memory state, and checks with backend /me.
  Future<SessionRestoreResult> tryRestoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedToken = prefs.getString(_kAuthTokenKey);
      final savedUserStr = prefs.getString(_kAuthUserKey);
      final savedRole = prefs.getString(_kAuthRoleKey) ?? 'citizen';

      if (savedToken == null || savedToken.isEmpty) {
        return const SessionRestoreResult(isValid: false);
      }

      // Check if JWT token has expired according to its claim
      if (isTokenExpired(savedToken)) {
        _token = savedToken;
        await logout(revokeOnServer: false);
        return const SessionRestoreResult(isValid: false);
      }

      // Restore session in memory
      _token = savedToken;
      _cachedRole = savedRole;
      if (savedUserStr != null && savedUserStr.isNotEmpty) {
        try {
          _currentUser = jsonDecode(savedUserStr) as Map<String, dynamic>;
        } catch (_) {
          _currentUser = null;
        }
      }
      if (_currentUser == null) {
        _currentUser = {'role': savedRole};
      } else if (_currentUser!['role'] == null) {
        _currentUser!['role'] = savedRole;
      }

      // Verify token with backend /me endpoint if server is reachable
      try {
        final verifiedUser = await getMe().timeout(const Duration(seconds: 4));
        _currentUser = verifiedUser;
        final updatedRole = verifiedUser['role']?.toString() ?? savedRole;
        _cachedRole = updatedRole;
        await prefs.setString(_kAuthUserKey, jsonEncode(verifiedUser));
        await prefs.setString(_kAuthRoleKey, updatedRole);
        return SessionRestoreResult(
          isValid: true,
          role: updatedRole,
          user: verifiedUser,
        );
      } on ApiException catch (e) {
        if (e.statusCode == 401) {
          // Token rejected by server as unauthorized
          await logout(revokeOnServer: false);
          return const SessionRestoreResult(isValid: false);
        }
        return SessionRestoreResult(
          isValid: true,
          role: savedRole,
          user: _currentUser,
        );
      } catch (_) {
        // Network timeout / offline: token is valid according to JWT claims, retain session
        return SessionRestoreResult(
          isValid: true,
          role: savedRole,
          user: _currentUser,
        );
      }
    } catch (e) {
      debugPrint('Error restoring session: $e');
      return const SessionRestoreResult(isValid: false);
    }
  }

  Map<String, String> _headers({bool withAuth = true}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (withAuth && _token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  dynamic _handleResponse(http.Response response) {
    dynamic body;
    try {
      if (response.body.isNotEmpty) {
        body = jsonDecode(response.body);
      }
    } catch (_) {
      body = response.body;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    // Auto-clear invalid session on 401 Unauthorized
    if (response.statusCode == 401) {
      logout(revokeOnServer: false);
    }

    String errorMsg = 'An error occurred (${response.statusCode})';
    if (response.statusCode == 401) {
      errorMsg = 'Incorrect email or password, or session has expired.';
    } else if (response.statusCode == 403) {
      errorMsg = 'Access denied. You do not have permission to perform this action.';
    } else if (response.statusCode == 404) {
      errorMsg = 'The requested resource was not found on the server.';
    } else if (response.statusCode == 422) {
      errorMsg = 'Validation failed. Please verify the submitted information.';
    } else if (response.statusCode == 429) {
      errorMsg = 'Too many requests. Please wait a moment before trying again.';
    } else if (response.statusCode == 502 || response.statusCode == 503) {
      errorMsg = 'MEDAL Cloud Service is temporarily unavailable or starting up. Please try again in a few moments.';
    } else if (response.statusCode >= 500) {
      errorMsg = 'Internal server error. Please try again shortly.';
    }

    if (body is Map && body.containsKey('detail')) {
      final detail = body['detail'];
      if (detail is String && detail.trim().isNotEmpty) {
        errorMsg = detail.trim();
      } else if (detail is List && detail.isNotEmpty) {
        final firstError = detail[0];
        if (firstError is Map && firstError.containsKey('msg')) {
          errorMsg = firstError['msg']?.toString() ?? detail.toString();
        } else {
          errorMsg = detail.toString();
        }
      }
    }

    throw ApiException(response.statusCode, errorMsg);
  }

  // ── Authentication Endpoints ─────────────────────────────────────

  /// POST /register
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String fullName,
    String? phone,
  }) async {
    final uri = Uri.parse('$baseUrl/register');
    final response = await http.post(
      uri,
      headers: _headers(),
      body: jsonEncode({
        'email': email.trim(),
        'password': password,
        'full_name': fullName.trim(),
        'phone': phone?.trim().isNotEmpty == true ? phone!.trim() : null,
      }),
    );
    final data = _handleResponse(response);
    return data as Map<String, dynamic>;
  }

  /// POST /login
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse('$baseUrl/login');
    debugPrint('[MEDAL] LOGIN STARTED — URL: $uri');
    debugPrint('[MEDAL] REQUEST: email=$email');

    late http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: _headers(),
            body: jsonEncode({
              'email': email.trim(),
              'password': password,
            }),
          )
          .timeout(
            const Duration(seconds: 45),
            onTimeout: () {
              debugPrint('[MEDAL] LOGIN TIMEOUT after 45s');
              throw ApiException(
                0,
                uri.host.contains('onrender.com')
                    ? 'Connection to MEDAL server timed out. The cloud server may be waking from sleep; please retry in a few moments.'
                    : 'Connection to MEDAL server timed out ($baseUrl). Please check that your backend is running and reachable.',
              );
            },
          );
    } on ApiException {
      rethrow;
    } catch (e) {
      debugPrint('[MEDAL] LOGIN NETWORK ERROR: $e');
      throw ApiException(
        0,
        uri.host.contains('onrender.com')
            ? 'Cannot connect to the MEDAL server ($baseUrl). Please check your internet connection and try again.'
            : 'Cannot connect to the MEDAL server ($baseUrl). Make sure the backend is running on 0.0.0.0:8000, your phone is on the same Wi-Fi, and Windows Firewall permits connections.',
      );
    }

    debugPrint('[MEDAL] RESPONSE STATUS: ${response.statusCode} from ${uri.host}');

    final data = _handleResponse(response) as Map<String, dynamic>;
    if (data.containsKey('access_token')) {
      _token = data['access_token'];
      if (data.containsKey('data')) {
        _currentUser = Map<String, dynamic>.from(data['data']);
        _cachedRole = _currentUser?['role']?.toString();
      }
      _cachedRole ??= userRole;
      await _persistSession();
      debugPrint('[MEDAL] LOGIN SUCCESS — user=${_currentUser?['email']} role=$userRole');
    }
    return data;
  }


  /// GET /me
  Future<Map<String, dynamic>> getMe() async {
    final uri = Uri.parse('$baseUrl/me');
    final response = await http.get(uri, headers: _headers());
    final data = _handleResponse(response) as Map<String, dynamic>;
    _currentUser = data;
    if (data['role'] != null) {
      _cachedRole = data['role']?.toString();
    }
    await _persistSession();
    return data;
  }

  /// PATCH /me (Update authenticated citizen profile)
  Future<Map<String, dynamic>> updateProfile({
    String? fullName,
    String? phone,
  }) async {
    final uri = Uri.parse('$baseUrl/me');
    final body = <String, dynamic>{};
    if (fullName != null) body['full_name'] = fullName;
    if (phone != null) body['phone'] = phone;

    final response = await http.patch(
      uri,
      headers: _headers(),
      body: jsonEncode(body),
    );
    final data = _handleResponse(response) as Map<String, dynamic>;
    if (_currentUser != null) {
      _currentUser = {..._currentUser!, ...data};
    } else {
      _currentUser = data;
    }
    await _persistSession();
    return data;
  }

  /// PUT /users/me/profile-photo (Upload and update citizen profile photo in Cloudinary)
  Future<Map<String, dynamic>> updateProfilePhoto({
    required List<int> fileBytes,
    required String filename,
    String? mimeType,
  }) async {
    final uri = Uri.parse('$baseUrl/users/me/profile-photo');
    final request = http.MultipartRequest('PUT', uri);

    if (_token != null) {
      request.headers['Authorization'] = 'Bearer $_token';
    }

    String safeFilename = filename.trim().isNotEmpty ? filename.trim() : 'profile.jpg';
    if (!safeFilename.contains('.')) {
      safeFilename = '$safeFilename.jpg';
    }

    final mediaType = _resolveMediaType(safeFilename, mimeType);

    final multipartFile = http.MultipartFile.fromBytes(
      'file',
      fileBytes,
      filename: safeFilename,
      contentType: mediaType,
    );
    request.files.add(multipartFile);
    final streamedResponse = await request.send().timeout(
      const Duration(seconds: 45),
      onTimeout: () {
        throw ApiException(
          0,
          'Profile photo upload timed out. Please check your network connection and try again.',
        );
      },
    );
    final response = await http.Response.fromStream(streamedResponse);
    final data = _handleResponse(response) as Map<String, dynamic>;

    if (data.containsKey('data') && data['data'] is Map) {
      _currentUser = Map<String, dynamic>.from(data['data']);
    } else {
      if (_currentUser != null) {
        _currentUser = {..._currentUser!, ...data};
      } else {
        _currentUser = data;
      }
    }
    await _persistSession();
    return data;
  }

  /// POST /forgot-password
  Future<Map<String, dynamic>> forgotPassword({
    required String email,
  }) async {
    final uri = Uri.parse('$baseUrl/forgot-password');
    final response = await http.post(
      uri,
      headers: _headers(),
      body: jsonEncode({
        'email': email.trim(),
      }),
    );
    final data = _handleResponse(response);
    return data as Map<String, dynamic>;
  }

  /// POST /verify-otp
  Future<Map<String, dynamic>> verifyOtp({
    required String email,
    required String otp,
  }) async {
    final uri = Uri.parse('$baseUrl/verify-otp');
    final response = await http.post(
      uri,
      headers: _headers(),
      body: jsonEncode({
        'email': email.trim(),
        'otp': otp.trim(),
      }),
    );
    final data = _handleResponse(response);
    return data as Map<String, dynamic>;
  }

  /// POST /resend-otp
  Future<Map<String, dynamic>> resendOtp({
    required String email,
  }) async {
    final uri = Uri.parse('$baseUrl/resend-otp');
    final response = await http.post(
      uri,
      headers: _headers(),
      body: jsonEncode({
        'email': email.trim(),
      }),
    );
    final data = _handleResponse(response);
    return data as Map<String, dynamic>;
  }

  /// POST /reset-password
  Future<Map<String, dynamic>> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    final uri = Uri.parse('$baseUrl/reset-password');
    final response = await http.post(
      uri,
      headers: _headers(),
      body: jsonEncode({
        'token': token.trim(),
        'new_password': newPassword,
      }),
    );
    final data = _handleResponse(response);
    return data as Map<String, dynamic>;
  }

  /// POST /student/manage-password — change the signed-in institution user's password.
  /// The server then revokes every existing session, so the caller must sign in again.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final uri = Uri.parse('$baseUrl/student/manage-password');
    final response = await http.post(
      uri,
      headers: _headers(),
      body: jsonEncode({
        'current_password': currentPassword,
        'new_password': newPassword,
      }),
    );
    _handleResponse(response);
  }

  // ── Complaint Endpoints ──────────────────────────────────────────

  static MediaType _resolveMediaType(String filename, [String? mimeType]) {
    if (mimeType != null && mimeType.contains('/')) {
      final parts = mimeType.split('/');
      return MediaType(parts[0].trim(), parts[1].trim());
    }
    final ext = filename.contains('.') ? filename.split('.').last.toLowerCase() : '';
    switch (ext) {
      case 'pdf':
        return MediaType('application', 'pdf');
      case 'png':
        return MediaType('image', 'png');
      case 'webp':
        return MediaType('image', 'webp');
      case 'gif':
        return MediaType('image', 'gif');
      case 'bmp':
        return MediaType('image', 'bmp');
      case 'svg':
        return MediaType('image', 'svg+xml');
      case 'jpg':
      case 'jpeg':
      default:
        return MediaType('image', 'jpeg');
    }
  }

  /// POST /complaints/upload-evidence
  Future<String> uploadEvidence({
    required List<int> fileBytes,
    required String filename,
    String? mimeType,
  }) async {
    final uri = Uri.parse('$baseUrl/complaints/upload-evidence');
    final request = http.MultipartRequest('POST', uri);

    if (_token != null) {
      request.headers['Authorization'] = 'Bearer $_token';
    }

    String safeFilename = filename.trim().isNotEmpty ? filename.trim() : 'evidence.jpg';
    if (!safeFilename.contains('.')) {
      safeFilename = '$safeFilename.jpg';
    }

    final mediaType = _resolveMediaType(safeFilename, mimeType);

    final multipartFile = http.MultipartFile.fromBytes(
      'file',
      fileBytes,
      filename: safeFilename,
      contentType: mediaType,
    );
    request.files.add(multipartFile);
    final streamedResponse = await request.send().timeout(
      const Duration(seconds: 45),
      onTimeout: () {
        throw ApiException(
          0,
          'Evidence upload timed out. Please check your network connection and try again.',
        );
      },
    );
    final response = await http.Response.fromStream(streamedResponse);
    final data = _handleResponse(response) as Map<String, dynamic>;
    return data['image_url'] as String;
  }

  /// POST /complaints/analyze-sdg
  /// Multimodal AI evaluation of civic grievance to recommend UN SDGs (1-17)
  Future<Map<String, dynamic>> analyzeSdg({
    required String subject,
    required String category,
    required String description,
    List<int>? evidenceBytes,
    String? evidenceFilename,
    String? evidenceMimeType,
    String? imageUrl,
  }) async {
    final uri = Uri.parse('$baseUrl/complaints/analyze-sdg');
    final request = http.MultipartRequest('POST', uri);

    if (_token != null) {
      request.headers['Authorization'] = 'Bearer $_token';
    }

    request.fields['subject'] = subject.trim();
    request.fields['category'] = category.trim();
    request.fields['description'] = description.trim();
    if (imageUrl != null && imageUrl.trim().isNotEmpty) {
      request.fields['image_url'] = imageUrl.trim();
    }

    if (evidenceBytes != null && evidenceBytes.isNotEmpty) {
      String safeFilename = (evidenceFilename != null && evidenceFilename.trim().isNotEmpty)
          ? evidenceFilename.trim()
          : 'evidence.jpg';
      if (!safeFilename.contains('.')) {
        safeFilename = '$safeFilename.jpg';
      }
      final mediaType = _resolveMediaType(safeFilename, evidenceMimeType);
      request.files.add(http.MultipartFile.fromBytes(
        'evidence',
        evidenceBytes,
        filename: safeFilename,
        contentType: mediaType,
      ));
    }

    final streamedResponse = await request.send().timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        throw ApiException(
          0,
          'AI analysis request timed out. You can select the SDG manually.',
        );
      },
    );
    final response = await http.Response.fromStream(streamedResponse);
    final data = _handleResponse(response) as Map<String, dynamic>;
    return data;
  }

  /// POST /complaints
  Future<Map<String, dynamic>> createComplaint({
    required String title,
    required String description,
    required String category,
    required String location,
    double? latitude,
    double? longitude,
    String? locationAddress,
    String? imageUrl,
    String? sdgAlignment,
    String? impactLevel,
    String? equityClassification,
    List<int> mentionIds = const [],
  }) async {
    final uri = Uri.parse('$baseUrl/complaints');
    final response = await http.post(
      uri,
      headers: _headers(),
      body: jsonEncode({
        'title': title.trim(),
        'description': description.trim(),
        'category': category.trim().toLowerCase(),
        'location': location.trim(),
        'latitude': ?latitude,
        'longitude': ?longitude,
        if (locationAddress != null && locationAddress.isNotEmpty)
          'location_address': locationAddress.trim(),
        if (imageUrl != null && imageUrl.isNotEmpty) 'image_url': imageUrl,
        if (sdgAlignment != null && sdgAlignment.isNotEmpty) 'sdg_alignment': sdgAlignment,
        if (impactLevel != null && impactLevel.isNotEmpty) 'impact_level': impactLevel,
        if (equityClassification != null && equityClassification.isNotEmpty)
          'equity_classification': equityClassification,
        if (mentionIds.isNotEmpty) 'mentions': mentionIds,
      }),
    );
    final data = _handleResponse(response);
    return data as Map<String, dynamic>;
  }

  /// GET /officials?q= — approved officials for the "@" tag autocomplete
  Future<List<Map<String, dynamic>>> searchOfficials(String query, {int limit = 8}) async {
    final uri = Uri.parse('$baseUrl/officials').replace(
      queryParameters: {'q': query, 'limit': '$limit'},
    );
    final response = await http.get(uri, headers: _headers());
    final data = _handleResponse(response);
    return List<Map<String, dynamic>>.from(data as List);
  }

  /// GET /complaints/feed (Public Community Feed)
  Future<List<Map<String, dynamic>>> getCommunityFeed({
    String? category,
    int? limit,
    int? offset,
  }) async {
    final params = <String, String>{};
    if (category != null &&
        category.trim().isNotEmpty &&
        category.trim().toLowerCase() != 'all reports' &&
        category.trim().toLowerCase() != 'all') {
      params['category'] = category.trim();
    }
    if (limit != null) params['limit'] = limit.toString();
    if (offset != null) params['offset'] = offset.toString();

    final uri = Uri.parse('$baseUrl/complaints/feed').replace(queryParameters: params.isNotEmpty ? params : null);
    try {
      final response = await http
          .get(uri, headers: _headers())
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw ApiException(
                0,
                'Request timed out while loading the community feed. Please check your network connection.',
              );
            },
          );
      final data = _handleResponse(response) as List;
      return data.map((e) => Map<String, dynamic>.from(e)).toList();
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(0, 'Failed to connect to feed service: $e');
    }
  }

  /// POST /complaints/{id}/upvote
  Future<Map<String, dynamic>> toggleUpvote(int complaintId) async {
    final uri = Uri.parse('$baseUrl/complaints/$complaintId/upvote');
    final response = await http.post(uri, headers: _headers());
    final data = _handleResponse(response);
    return data as Map<String, dynamic>;
  }

  /// GET /complaints/{id}/upvote-status
  Future<Map<String, dynamic>> getUpvoteStatus(int complaintId) async {
    final uri = Uri.parse('$baseUrl/complaints/$complaintId/upvote-status');
    final response = await http.get(uri, headers: _headers());
    final data = _handleResponse(response);
    return data as Map<String, dynamic>;
  }

  /// POST /complaints/{id}/repost  — one repost per user per complaint
  Future<Map<String, dynamic>> repostComplaint(int complaintId) async {
    final uri = Uri.parse('$baseUrl/complaints/$complaintId/repost');
    final response = await http.post(uri, headers: _headers());
    final data = _handleResponse(response);
    return data as Map<String, dynamic>;
  }

  /// GET /complaints/{id}/repost-status
  Future<Map<String, dynamic>> getRepostStatus(int complaintId) async {
    final uri = Uri.parse('$baseUrl/complaints/$complaintId/repost-status');
    final response = await http.get(uri, headers: _headers());
    final data = _handleResponse(response);
    return data as Map<String, dynamic>;
  }


  /// GET /complaints/stats (Official/Admin Dashboard Analytics)
  Future<Map<String, dynamic>> getComplaintStats() async {
    final uri = Uri.parse('$baseUrl/complaints/stats');
    final response = await http.get(uri, headers: _headers());
    final data = _handleResponse(response);
    return data as Map<String, dynamic>;
  }

  /// GET /complaints
  Future<List<Map<String, dynamic>>> getComplaints({
    String? status,
    String? category,
  }) async {
    final params = <String, String>{};
    if (status != null && status.isNotEmpty) params['status'] = status;
    if (category != null && category.isNotEmpty) params['category'] = category;

    final uri = Uri.parse('$baseUrl/complaints').replace(queryParameters: params.isNotEmpty ? params : null);
    final response = await http.get(uri, headers: _headers());
    final data = _handleResponse(response) as List;
    return data.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// GET /complaints/{id}
  Future<Map<String, dynamic>> getComplaintDetails(int id) async {
    final uri = Uri.parse('$baseUrl/complaints/$id');
    final response = await http.get(uri, headers: _headers());
    final data = _handleResponse(response);
    return data as Map<String, dynamic>;
  }

  /// PATCH /complaints/{id}/status
  Future<Map<String, dynamic>> updateComplaintStatus(
    int id,
    String status, {
    String? officerNotes,
    String? rejectionReason,
  }) async {
    final uri = Uri.parse('$baseUrl/complaints/$id/status');
    final Map<String, dynamic> body = {'status': status};
    if (officerNotes != null && officerNotes.trim().isNotEmpty) {
      body['officer_notes'] = officerNotes.trim();
    }
    if (rejectionReason != null && rejectionReason.trim().isNotEmpty) {
      body['rejection_reason'] = rejectionReason.trim();
    }
    final response = await http.patch(
      uri,
      headers: _headers(),
      body: jsonEncode(body),
    );
    final data = _handleResponse(response);
    return data as Map<String, dynamic>;
  }

  /// GET /users (Admin)
  Future<List<Map<String, dynamic>>> getUsers() async {
    final uri = Uri.parse('$baseUrl/users');
    final response = await http.get(uri, headers: _headers());
    final data = _handleResponse(response) as List;
    return data.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// GET /complaints/{id}/comments
  Future<List<Map<String, dynamic>>> getComments(int complaintId) async {
    final uri = Uri.parse('$baseUrl/complaints/$complaintId/comments');
    final response = await http.get(uri, headers: _headers());
    final data = _handleResponse(response) as List;
    return data.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// POST /complaints/{id}/comments
  Future<Map<String, dynamic>> addComment(
    int complaintId,
    String comment, {
    int? parentCommentId,
    String? imageUrl,
  }) async {
    final uri = Uri.parse('$baseUrl/complaints/$complaintId/comments');
    final Map<String, dynamic> payload = {
      'comment': comment.trim(),
      'content': comment.trim(),
    };
    if (parentCommentId != null) {
      payload['parent_comment_id'] = parentCommentId;
    }
    if (imageUrl != null && imageUrl.trim().isNotEmpty) {
      payload['image_url'] = imageUrl.trim();
    }
    final response = await http.post(
      uri,
      headers: _headers(),
      body: jsonEncode(payload),
    );
    final data = _handleResponse(response);
    return data as Map<String, dynamic>;
  }

  /// DELETE /complaints/{complaintId}/comments/{commentId}
  Future<Map<String, dynamic>> deleteComment(int complaintId, int commentId) async {
    final uri = Uri.parse('$baseUrl/complaints/$complaintId/comments/$commentId');
    final response = await http.delete(uri, headers: _headers());
    final data = _handleResponse(response);
    return data is Map<String, dynamic> ? data : {'message': 'Comment deleted'};
  }

  /// DELETE /complaints/{complaintId}
  Future<Map<String, dynamic>> deleteComplaint(int complaintId) async {
    final uri = Uri.parse('$baseUrl/complaints/$complaintId');
    final response = await http.delete(uri, headers: _headers());
    final data = _handleResponse(response);
    return data is Map<String, dynamic> ? data : {'message': 'Complaint deleted successfully'};
  }

  // ── Authority Onboarding Endpoints ──────────────────────────────

  /// POST /authority/upload-document
  Future<Map<String, dynamic>> uploadAuthorityDocument({
    required List<int> fileBytes,
    required String filename,
    String? mimeType,
  }) async {
    final uri = Uri.parse('$baseUrl/authority/upload-document');
    final request = http.MultipartRequest('POST', uri);

    String safeFilename = filename.trim().isNotEmpty ? filename.trim() : 'document.pdf';
    final mediaType = _resolveMediaType(safeFilename, mimeType);

    final multipartFile = http.MultipartFile.fromBytes(
      'file',
      fileBytes,
      filename: safeFilename,
      contentType: mediaType,
    );
    request.files.add(multipartFile);
    final streamedResponse = await request.send().timeout(
      const Duration(seconds: 45),
      onTimeout: () {
        throw ApiException(
          0,
          'Document upload timed out. Please check your network connection and try again.',
        );
      },
    );
    final response = await http.Response.fromStream(streamedResponse);
    final data = _handleResponse(response) as Map<String, dynamic>;
    return data;
  }

  /// POST /authority/register
  Future<Map<String, dynamic>> registerAuthority({
    required String fullName,
    required String officialEmail,
    required String password,
    String? officialPhone,
    required String designation,
    required String department,
    required String jurisdiction,
    String? identityNumber,
    String clearanceLevel = 'Level 2 (Inspection & Resolution Lead)',
    required String aadhaarDocumentUrl,
    required String employmentDocumentUrl,
  }) async {
    final uri = Uri.parse('$baseUrl/authority/register');
    final response = await http.post(
      uri,
      headers: _headers(),
      body: jsonEncode({
        'full_name': fullName.trim(),
        'official_email': officialEmail.trim(),
        'password': password,
        'official_phone': officialPhone?.trim().isNotEmpty == true ? officialPhone!.trim() : null,
        'designation': designation.trim(),
        'department': department.trim(),
        'jurisdiction': jurisdiction.trim(),
        'identity_number': identityNumber?.trim().isNotEmpty == true ? identityNumber!.trim() : null,
        'clearance_level': clearanceLevel.trim(),
        'aadhaar_document_url': aadhaarDocumentUrl.trim(),
        'employment_document_url': employmentDocumentUrl.trim(),
      }),
    );
    final data = _handleResponse(response);
    return data as Map<String, dynamic>;
  }

  /// GET /authority/application-status
  Future<Map<String, dynamic>> getAuthorityApplicationStatus(String email) async {
    final uri = Uri.parse('$baseUrl/authority/application-status?email=${Uri.encodeComponent(email.trim())}');
    final response = await http.get(uri, headers: _headers());
    final data = _handleResponse(response);
    return data as Map<String, dynamic>;
  }

  // ── Admin Verification & Approval Endpoints ─────────────────────

  /// GET /admin/authority-applications
  Future<List<Map<String, dynamic>>> getAuthorityApplications({String? status}) async {
    final query = status != null && status.isNotEmpty ? '?status=${Uri.encodeComponent(status)}' : '';
    final uri = Uri.parse('$baseUrl/admin/authority-applications$query');
    try {
      final response = await http
          .get(uri, headers: _headers())
          .timeout(const Duration(seconds: 15));
      final data = _handleResponse(response);
      if (data is List) {
        return data.map((item) => Map<String, dynamic>.from(item as Map)).toList();
      }
      return [];
    } on ApiException {
      rethrow;
    } catch (e) {
      debugPrint('[MEDAL] GET AUTHORITY APPLICATIONS NETWORK ERROR: $e');
      throw ApiException(
        0,
        'Cannot connect to the MEDAL server ($baseUrl). Please check that your server is running and reachable.',
      );
    }
  }

  /// GET /admin/authority-applications/{id}
  Future<Map<String, dynamic>> getAuthorityApplication(int id) async {
    final uri = Uri.parse('$baseUrl/admin/authority-applications/$id');
    try {
      final response = await http
          .get(uri, headers: _headers())
          .timeout(const Duration(seconds: 15));
      final data = _handleResponse(response);
      return data as Map<String, dynamic>;
    } on ApiException {
      rethrow;
    } catch (e) {
      debugPrint('[MEDAL] GET AUTHORITY APPLICATION DETAIL NETWORK ERROR: $e');
      throw ApiException(
        0,
        'Cannot connect to the MEDAL server ($baseUrl). Please check that your server is running and reachable.',
      );
    }
  }

  /// POST /admin/authority-applications/{id}/approve
  Future<Map<String, dynamic>> approveAuthorityApplication(
    int id, {
    String? clearanceLevel,
  }) async {
    final uri = Uri.parse('$baseUrl/admin/authority-applications/$id/approve');
    final payload = <String, dynamic>{};
    if (clearanceLevel != null && clearanceLevel.trim().isNotEmpty) {
      payload['clearance_level'] = clearanceLevel.trim();
    }
    try {
      final response = await http
          .post(
            uri,
            headers: _headers(),
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));
      final data = _handleResponse(response);
      return data as Map<String, dynamic>;
    } on ApiException {
      rethrow;
    } catch (e) {
      debugPrint('[MEDAL] APPROVE AUTHORITY APPLICATION NETWORK ERROR: $e');
      throw ApiException(
        0,
        'Cannot connect to the MEDAL server ($baseUrl). Please check your connection.',
      );
    }
  }

  /// POST /admin/authority-applications/{id}/reject
  Future<Map<String, dynamic>> rejectAuthorityApplication(
    int id, {
    required String reason,
  }) async {
    final uri = Uri.parse('$baseUrl/admin/authority-applications/$id/reject');
    try {
      final response = await http
          .post(
            uri,
            headers: _headers(),
            body: jsonEncode({
              'reason': reason.trim(),
            }),
          )
          .timeout(const Duration(seconds: 15));
      final data = _handleResponse(response);
      return data as Map<String, dynamic>;
    } on ApiException {
      rethrow;
    } catch (e) {
      debugPrint('[MEDAL] REJECT AUTHORITY APPLICATION NETWORK ERROR: $e');
      throw ApiException(
        0,
        'Cannot connect to the MEDAL server ($baseUrl). Please check your connection.',
      );
    }
  }
}

