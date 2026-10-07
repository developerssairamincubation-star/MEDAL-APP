// lib/config/maps_config.dart
// ─────────────────────────────────────────────────────────────────────────────
// MEDAL — Google Maps & Google Places API Configuration
// ─────────────────────────────────────────────────────────────────────────────
//
// SECURITY:
// - Do NOT hardcode production API keys in source control.
// - For Android native Maps SDK: set MAPS_API_KEY in android/local.properties
//     MAPS_API_KEY=YOUR_KEY_HERE
// - For Flutter (Places & Geocoding): pass via --dart-define:
//     flutter run --dart-define=MAPS_API_KEY=YOUR_KEY_HERE
//   OR configure locally in this file for developer testing (do not commit secrets).

class MapsConfig {
  static const String _envApiKey = String.fromEnvironment('MAPS_API_KEY', defaultValue: '');
  static String _localApiKey = 'AIzaSyAsvRFbHTFCMbS7oPw0nGXygrnAWcp8U_s';

  /// Set key dynamically at runtime if fetched or configured
  static void setApiKey(String key) {
    _localApiKey = key.trim();
  }

  /// Active API key
  static String get apiKey {
    if (_envApiKey.trim().isNotEmpty) {
      return _envApiKey.trim();
    }
    return _localApiKey.trim();
  }

  /// Whether an API key has been supplied
  static bool get hasApiKey => apiKey.isNotEmpty;
}
