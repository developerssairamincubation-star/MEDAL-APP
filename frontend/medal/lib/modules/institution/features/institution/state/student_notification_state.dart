// Tracks which notifications the signed-in student has already seen.
// Seen ids are stored per user in SharedPreferences, so the bell's red dot
// stays cleared after a reload and only returns for notifications with new ids.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medal/core/services/api_service.dart';

class StudentNotificationState extends ChangeNotifier {
  StudentNotificationState._();
  static final StudentNotificationState instance = StudentNotificationState._();

  Set<String> _seenIds = {};
  Set<String> _knownIds = {};
  String? _loadedForUser;
  bool _loaded = false;
  bool _fetched = false;

  String get _userKey =>
      (ApiService().currentUser?['id'] ?? 'anonymous').toString();
  String get _prefsKey => 'student_notifications_seen_$_userKey';

  /// True while at least one known notification has not been seen by this user.
  /// Hidden until both the stored state and the server list have loaded.
  bool get hasUnread =>
      _loaded && _fetched && _knownIds.any((id) => !_seenIds.contains(id));

  Future<void> ensureLoaded() async {
    final user = _userKey;
    if (_loaded && _loadedForUser == user) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _seenIds = (prefs.getStringList(_prefsKey) ?? const <String>[]).toSet();
    } catch (_) {
      _seenIds = {};
    }
    _loadedForUser = user;
    _loaded = true;
    _knownIds = {};
    _fetched = false;
    notifyListeners();
  }

  /// Reads the current notification ids from the server.
  Future<void> refresh() async {
    await ensureLoaded();
    try {
      final token = ApiService().token;
      final resp = await http.get(
        Uri.parse('${ApiService().baseUrl}/student/notifications'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      );
      if (resp.statusCode == 200) {
        _knownIds = idsFrom(jsonDecode(resp.body));
        _fetched = true;
        notifyListeners();
      }
    } catch (_) {}
  }

  static Set<String> idsFrom(dynamic data) {
    final ids = <String>{};
    if (data is Map) {
      for (final key in const ['last_7_days', 'last_30_days']) {
        for (final n in (data[key] as List? ?? const [])) {
          if (n is Map && n['id'] != null) ids.add(n['id'].toString());
        }
      }
    }
    return ids;
  }

  /// Called when the Notifications page has loaded [data] (the API response).
  Future<void> markSeen(dynamic data) async {
    await ensureLoaded();
    final ids = idsFrom(data);
    _knownIds = {..._knownIds, ...ids};
    _fetched = true;
    _seenIds = {..._seenIds, ...ids};
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefsKey, _seenIds.toList());
    } catch (_) {}
  }

  /// Forget cached state (on login / logout).
  void reset() {
    _seenIds = {};
    _knownIds = {};
    _loaded = false;
    _fetched = false;
    _loadedForUser = null;
    notifyListeners();
  }
}
