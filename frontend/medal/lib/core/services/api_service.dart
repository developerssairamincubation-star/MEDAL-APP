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

  /// Backend API Base URL — driven by lib/config/api_config.dart.
  /// To change the IP, update kPcWifiIp in that file and rebuild.
  /// For web/desktop, kLocalhostUrl is used automatically.
  String baseUrl = defaultTargetPlatform == TargetPlatform.android && !kIsWeb
      ? kAndroidLanUrl
      : kLocalhostUrl;

  /// Resolves image URLs for both local uploads and MinIO object storage.
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

      // Check if this is a MinIO URL (port 9000 or contains /medal-evidence/, /reports/, or /profiles/)
      if (uri.port == 9000 ||
          uri.path.contains('medal-evidence') ||
          uri.path.contains('/reports/') ||
          uri.path.contains('/profiles/')) {
        final port = uri.port > 0 ? uri.port : 9000;
        return Uri(
          scheme: targetScheme,
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

  String? get token => _token;
  Map<String, dynamic>? get currentUser => _currentUser;
  bool get isAuthenticated => _token != null && _token!.isNotEmpty;
  String get userRole => _currentUser?['role']?.toString() ?? 'citizen';

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
    await _persistSession();
  }

  Future<void> logout() async {
    _token = null;
    _currentUser = null;
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
        await logout();
        return const SessionRestoreResult(isValid: false);
      }

      // Restore session in memory
      _token = savedToken;
      if (savedUserStr != null && savedUserStr.isNotEmpty) {
        try {
          _currentUser = jsonDecode(savedUserStr) as Map<String, dynamic>;
        } catch (_) {
          _currentUser = null;
        }
      }

      // Verify token with backend /me endpoint if server is reachable
      try {
        final verifiedUser = await getMe().timeout(const Duration(seconds: 4));
        _currentUser = verifiedUser;
        final updatedRole = verifiedUser['role']?.toString() ?? savedRole;
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
          await logout();
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
      logout();
    }

    String errorMsg = 'An error occurred (${response.statusCode})';
    if (body is Map && body.containsKey('detail')) {
      final detail = body['detail'];
      if (detail is String) {
        errorMsg = detail;
      } else if (detail is List && detail.isNotEmpty) {
        errorMsg = detail[0]['msg'] ?? detail.toString();
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
      headers: _headers(withAuth: false),
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
            headers: _headers(withAuth: false),
            body: jsonEncode({
              'email': email.trim(),
              'password': password,
            }),
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              debugPrint('[MEDAL] LOGIN TIMEOUT after 15s');
              throw ApiException(
                0,
                'Server is taking too long to respond. Make sure the backend is running and your phone and PC are on the same Wi-Fi.',
              );
            },
          );
    } on ApiException {
      rethrow;
    } catch (e) {
      debugPrint('[MEDAL] LOGIN NETWORK ERROR: $e');
      throw ApiException(
        0,
        'Cannot connect to the MEDAL server. Make sure the backend is running on 0.0.0.0:8000 and your phone is on the same Wi-Fi.',
      );
    }

    debugPrint('[MEDAL] RESPONSE STATUS: ${response.statusCode}');
    debugPrint('[MEDAL] RESPONSE BODY: ${response.body}');

    final data = _handleResponse(response) as Map<String, dynamic>;
    if (data.containsKey('access_token')) {
      _token = data['access_token'];
      if (data.containsKey('data')) {
        _currentUser = Map<String, dynamic>.from(data['data']);
      }
      await _persistSession();
      debugPrint('[MEDAL] LOGIN SUCCESS — user=${_currentUser?['email']}');
    }
    return data;
  }


  /// GET /me
  Future<Map<String, dynamic>> getMe() async {
    final uri = Uri.parse('$baseUrl/me');
    final response = await http.get(uri, headers: _headers());
    final data = _handleResponse(response) as Map<String, dynamic>;
    _currentUser = data;
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

  /// PUT /users/me/profile-photo (Upload and update citizen profile photo in MinIO)
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

    final streamedResponse = await request.send();
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
      headers: _headers(withAuth: false),
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
      headers: _headers(withAuth: false),
      body: jsonEncode({
        'token': token.trim(),
        'new_password': newPassword,
      }),
    );
    final data = _handleResponse(response);
    return data as Map<String, dynamic>;
  }

  // ── Complaint Endpoints ──────────────────────────────────────────

  static MediaType _resolveMediaType(String filename, [String? mimeType]) {
    if (mimeType != null && mimeType.contains('/')) {
      final parts = mimeType.split('/');
      return MediaType(parts[0].trim(), parts[1].trim());
    }
    final ext = filename.contains('.') ? filename.split('.').last.toLowerCase() : '';
    switch (ext) {
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

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    final data = _handleResponse(response) as Map<String, dynamic>;
    return data['image_url'] as String;
  }

  /// POST /complaints
  Future<Map<String, dynamic>> createComplaint({
    required String title,
    required String description,
    required String category,
    required String location,
    String? imageUrl,
    String? sdgAlignment,
    String? impactLevel,
    String? equityClassification,
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
        if (imageUrl != null && imageUrl.isNotEmpty) 'image_url': imageUrl,
        if (sdgAlignment != null && sdgAlignment.isNotEmpty) 'sdg_alignment': sdgAlignment,
        if (impactLevel != null && impactLevel.isNotEmpty) 'impact_level': impactLevel,
        if (equityClassification != null && equityClassification.isNotEmpty)
          'equity_classification': equityClassification,
      }),
    );
    final data = _handleResponse(response);
    return data as Map<String, dynamic>;
  }

  /// GET /complaints/feed (Public Community Feed)
  Future<List<Map<String, dynamic>>> getCommunityFeed({
    String? category,
  }) async {
    final params = <String, String>{};
    if (category != null && category.isNotEmpty) params['category'] = category;

    final uri = Uri.parse('$baseUrl/complaints/feed').replace(queryParameters: params.isNotEmpty ? params : null);
    final response = await http.get(uri, headers: _headers(withAuth: false));
    final data = _handleResponse(response) as List;
    return data.map((e) => Map<String, dynamic>.from(e)).toList();
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
  Future<Map<String, dynamic>> updateComplaintStatus(int id, String status) async {
    final uri = Uri.parse('$baseUrl/complaints/$id/status');
    final response = await http.patch(
      uri,
      headers: _headers(),
      body: jsonEncode({'status': status}),
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
    final response = await http.get(uri, headers: _headers(withAuth: false));
    final data = _handleResponse(response) as List;
    return data.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// POST /complaints/{id}/comments
  Future<Map<String, dynamic>> addComment(
    int complaintId,
    String comment, {
    int? parentCommentId,
  }) async {
    final uri = Uri.parse('$baseUrl/complaints/$complaintId/comments');
    final Map<String, dynamic> payload = {
      'comment': comment.trim(),
      'content': comment.trim(),
    };
    if (parentCommentId != null) {
      payload['parent_comment_id'] = parentCommentId;
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
}

