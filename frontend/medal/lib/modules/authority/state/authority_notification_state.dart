// lib/modules/authority/state/authority_notification_state.dart
// Tracks which notifications the signed-in user has already seen.
// Seen ids are stored per user in SharedPreferences, so the bell's red dot
// stays cleared after a reload and only returns for notifications with new ids.

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/api_service.dart';
import '../models/authority_models.dart';

class AuthorityNotificationState extends ChangeNotifier {
  AuthorityNotificationState._();
  static final AuthorityNotificationState instance =
      AuthorityNotificationState._();

  Set<String> _seenIds = {};
  String? _loadedForUser;
  bool _loaded = false;

  String get _userKey =>
      (ApiService().currentUser?['id'] ?? 'anonymous').toString();
  String get _prefsKey => 'authority_notifications_seen_$_userKey';

  /// Ids of all notifications currently available to the user.
  Iterable<String> get _allIds =>
      MockAuthorityRepository.notifications.map((n) => n.id);

  /// True while at least one notification has not been seen by this user.
  /// Hidden until the stored state has loaded, to avoid a flash of the dot.
  bool get hasUnread => _loaded && _allIds.any((id) => !_seenIds.contains(id));

  /// Loads the stored state for the current user (reloads if the user changed).
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
    notifyListeners();
  }

  /// Called when the Notifications page is opened.
  Future<void> markAllSeen() async {
    await ensureLoaded();
    _seenIds = {..._seenIds, ..._allIds};
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefsKey, _seenIds.toList());
    } catch (_) {}
  }

  /// Forget cached state (used on logout / in tests).
  void reset() {
    _seenIds = {};
    _loaded = false;
    _loadedForUser = null;
    notifyListeners();
  }
}
