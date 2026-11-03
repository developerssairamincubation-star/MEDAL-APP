// lib/modules/institution/features/institution/services/institution_api.dart
// Live Principal / Staff endpoints (see backend app/routers/institution.py).

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:medal/core/services/api_service.dart';

import '../models/member.dart';

class InstitutionApi {
  const InstitutionApi();

  Map<String, String> get _headers {
    final token = ApiService().token;
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Uri _uri(String path) => Uri.parse('${ApiService().baseUrl}/institution$path');

  dynamic _decode(http.Response resp) {
    final body = resp.body.isEmpty ? null : jsonDecode(resp.body);
    if (resp.statusCode >= 200 && resp.statusCode < 300) return body;
    final detail = body is Map ? body['detail'] : null;
    throw ApiException(
      resp.statusCode,
      detail is String ? detail : 'Request failed (${resp.statusCode})',
    );
  }

  Future<InstitutionOverview> overview() async {
    final data = _decode(await http.get(_uri('/dashboard'), headers: _headers));
    return InstitutionOverview.fromJson(data as Map<String, dynamic>);
  }

  Future<List<InstitutionMember>> staff() async {
    final data = _decode(await http.get(_uri('/staff'), headers: _headers));
    return (data as List)
        .map((e) => InstitutionMember.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<InstitutionMember>> students() async {
    final data = _decode(await http.get(_uri('/students'), headers: _headers));
    return (data as List)
        .map((e) => InstitutionMember.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<MemberProgress> memberProgress(int id) async {
    final data =
        _decode(await http.get(_uri('/members/$id/progress'), headers: _headers));
    return MemberProgress.fromJson(data as Map<String, dynamic>);
  }

  /// Own SEEK progress and certificate count. These are the student endpoints:
  /// every account takes the same SEEK course and stores completions by user id.
  Future<OwnProgress> ownProgress() async {
    final base = '${ApiService().baseUrl}/student';
    final dash = _decode(await http.get(Uri.parse('$base/dashboard'), headers: _headers))
        as Map<String, dynamic>;
    final certs = _decode(await http.get(Uri.parse('$base/certificates'), headers: _headers))
        as List;
    final chapters = (dash['chapters'] ?? {}) as Map;
    return OwnProgress(
      completedChapters: (chapters['completed'] ?? 0) as int,
      totalChapters: (chapters['total'] ?? 0) as int,
      percent: (dash['overall_completion_pct'] ?? 0) as int,
      certificates: certs.length,
      recentChapters: ((dash['recent_activity'] ?? []) as List)
          .map((e) => '${(e as Map)['title']}')
          .toList(),
    );
  }

  Future<NewStaffResult> addStaff({
    required String name,
    required String email,
    String? department,
    String? designation,
  }) async {
    final data = _decode(await http.post(
      _uri('/staff'),
      headers: _headers,
      body: jsonEncode({
        'name': name,
        'email': email,
        if (department != null && department.isNotEmpty) 'department': department,
        if (designation != null && designation.isNotEmpty) 'designation': designation,
      }),
    )) as Map<String, dynamic>;
    return NewStaffResult(
      staff: InstitutionMember.fromJson(data['staff'] as Map<String, dynamic>),
      temporaryPassword: data['temporary_password'] as String,
    );
  }
}
