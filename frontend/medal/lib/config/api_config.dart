// lib/config/api_config.dart
// ─────────────────────────────────────────────────────────────────────────────
// MEDAL — Central API Base URL Configuration
// ─────────────────────────────────────────────────────────────────────────────
//
// HOW TO SELECT ENVIRONMENTS:
//   Production (default):
//     flutter run (or flutter build apk --release)
//   Physical Android Phone on Wi-Fi LAN:
//     flutter run --dart-define=APP_ENV=lan
//   Android Emulator (10.0.2.2):
//     flutter run --dart-define=APP_ENV=emulator
//   Localhost Desktop / Web:
//     flutter run -d windows --dart-define=APP_ENV=local
//   Custom Base URL:
//     flutter run --dart-define=BASE_URL=https://your-custom-domain.com
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';

/// Production backend URL deployed on Render
const String kRenderUrl = 'https://medal-backend.onrender.com';

/// Backend port — matches uvicorn startup port for local dev
const int kBackendPort = 8000;

/// Local PC Wi-Fi IP for local physical device development
const String kPcWifiIp = '10.70.114.158';

/// URL used by physical Android device on the same Wi-Fi as the PC
const String kAndroidLanUrl = 'http://$kPcWifiIp:$kBackendPort';

/// URL used by Android emulator (10.0.2.2 maps to host PC localhost)
const String kAndroidEmulatorUrl = 'http://10.0.2.2:$kBackendPort';

/// URL used by Flutter Web / Desktop running on the same machine
const String kLocalhostUrl = 'http://127.0.0.1:$kBackendPort';

/// Set to true ONLY if you explicitly want debug APK builds to force local LAN.
/// Defaults to false so production Render URL is used reliably.
const bool kUseLocalLanForApk = false;

/// ─────────────────────────────────────────────────────────────────────────────
/// Centralized Environment-Aware API Configuration
/// ─────────────────────────────────────────────────────────────────────────────
class ApiConfig {
  /// The official production Render backend URL
  static const String productionUrl = kRenderUrl;

  /// Active environment specified via `--dart-define=APP_ENV=...`
  /// Supported values: 'production' (default), 'local', 'lan', 'emulator'.
  static const String environment = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'production',
  );

  /// Custom base URL specified via `--dart-define=BASE_URL=...`
  static const String customBaseUrl = String.fromEnvironment('BASE_URL');

  /// Custom local URL specified via `--dart-define=LOCAL_API_URL=...`
  static const String localApiUrl = String.fromEnvironment('LOCAL_API_URL');

  /// Evaluates and returns the active API base URL.
  static String get baseUrl {
    // 1. Explicit BASE_URL override takes highest precedence
    if (customBaseUrl.isNotEmpty) {
      return customBaseUrl;
    }

    // 2. Legacy override flag if explicitly set to true
    if (kUseLocalLanForApk && !kReleaseMode) {
      return kAndroidLanUrl;
    }

    // 3. Resolve by environment
    switch (environment.toLowerCase()) {
      case 'lan':
      case 'device':
      case 'wifi':
        return kAndroidLanUrl;

      case 'emulator':
        return kAndroidEmulatorUrl;

      case 'local':
      case 'desktop':
        if (localApiUrl.isNotEmpty) return localApiUrl;
        return kLocalhostUrl;

      case 'production':
      case 'prod':
      default:
        return productionUrl;
    }
  }

  /// Whether current active configuration targets the production cloud service
  static bool get isProduction =>
      customBaseUrl.isNotEmpty
          ? customBaseUrl.contains('onrender.com') || customBaseUrl.startsWith('https://')
          : (environment.toLowerCase() == 'production' || environment.isEmpty);
}

/// Active base URL imported by ApiService and related components
String get kActiveBaseUrl => ApiConfig.baseUrl;

