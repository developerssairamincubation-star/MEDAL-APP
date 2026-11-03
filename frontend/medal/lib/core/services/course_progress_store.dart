// lib/core/services/course_progress_store.dart
// Per-user record of which course lessons the user has completed.
// Stored in SharedPreferences, keyed by the signed-in user's id, so progress
// (and the certificate that depends on it) survives restarts and never leaks
// between accounts. A course counts as completed only when every lesson is done.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';

class CourseProgressStore extends ChangeNotifier {
  CourseProgressStore._();
  static final CourseProgressStore instance = CourseProgressStore._();

  Set<String> _doneLessons = {};
  Map<String, DateTime> _completedAt = {};
  String? _loadedForUser;

  String get userKey =>
      (ApiService().currentUser?['id'] ?? 'anonymous').toString();
  String get _prefsKey => 'course_progress_$userKey';

  /// Loads the stored state for the current user (reloads if the user changed).
  Future<void> ensureLoaded() async {
    final user = userKey;
    if (_loadedForUser == user) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('course_progress_$user');
      if (raw != null) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        _doneLessons = ((data['lessons'] as List?) ?? const [])
            .map((e) => e.toString())
            .toSet();
        _completedAt = {
          for (final e in ((data['completed'] as Map?) ?? const {}).entries)
            e.key.toString(): DateTime.parse(e.value.toString()),
        };
      } else {
        _doneLessons = {};
        _completedAt = {};
      }
    } catch (_) {
      _doneLessons = {};
      _completedAt = {};
    }
    _loadedForUser = user;
    notifyListeners();
  }

  bool isLessonDone(String lessonKey) => _doneLessons.contains(lessonKey);

  /// When the user finished every lesson of [courseId]; null if not finished.
  DateTime? completedAt(String courseId) => _completedAt[courseId];

  /// Marks a lesson done / not done and re-evaluates course completion.
  Future<void> setLessonDone(
    String lessonKey,
    bool done, {
    required String courseId,
    required List<String> allLessonKeys,
  }) async {
    await ensureLoaded();
    if (done) {
      _doneLessons = {..._doneLessons, lessonKey};
    } else {
      _doneLessons = {..._doneLessons}..remove(lessonKey);
    }
    final finished = allLessonKeys.every(_doneLessons.contains);
    if (finished) {
      _completedAt = {..._completedAt, courseId: _completedAt[courseId] ?? DateTime.now()};
    } else {
      _completedAt = {..._completedAt}..remove(courseId);
    }
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        jsonEncode({
          'lessons': _doneLessons.toList(),
          'completed': {
            for (final e in _completedAt.entries)
              e.key: e.value.toIso8601String(),
          },
        }),
      );
    } catch (_) {}
  }

  /// Forget cached state (used on logout / in tests).
  void reset() {
    _doneLessons = {};
    _completedAt = {};
    _loadedForUser = null;
    notifyListeners();
  }
}
