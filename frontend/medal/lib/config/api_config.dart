// lib/config/api_config.dart
// ─────────────────────────────────────────────────────────────────────────────
// MEDAL — Central API Base URL Configuration
// ─────────────────────────────────────────────────────────────────────────────
//
// HOW TO FIND YOUR PC'S WI-FI IP (Windows PowerShell):
//   Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notmatch '^127\.' -and $_.IPAddress -notmatch '^169\.' }
//   Look for the row where InterfaceAlias = "Wi-Fi"
//
// ── Deployment targets ───────────────────────────────────────────────────────
//  Physical Android phone on LAN  →  http://<PC_WIFI_IP>:8000
//  Android emulator               →  http://10.0.2.2:8000
//  Web / Desktop (localhost)      →  http://127.0.0.1:8000
//  Production server              →  https://your-domain.com
// ─────────────────────────────────────────────────────────────────────────────

/// ★ CHANGE ONLY THIS VALUE when your PC's Wi-Fi IP changes.
///   Run: Get-NetIPAddress -AddressFamily IPv4 in PowerShell
///   then look for the Wi-Fi row.
const String kPcWifiIp = '172.16.125.17';

/// Backend port — matches uvicorn startup port
const int kBackendPort = 8000;

/// ── Computed URLs (do not edit below unless changing architecture) ─────────

/// URL used by physical Android device on the same Wi-Fi as the PC
const String kAndroidLanUrl = 'http://$kPcWifiIp:$kBackendPort';

/// URL used by Android emulator (10.0.2.2 maps to PC localhost)
const String kAndroidEmulatorUrl = 'http://10.0.2.2:$kBackendPort';

/// URL used by Flutter Web / Desktop running on the same machine
const String kLocalhostUrl = 'http://127.0.0.1:$kBackendPort';

/// ── Active base URL (imported by ApiService) ──────────────────────────────
/// Switch between the constants above to match your environment.
/// Default: physical Android phone on LAN.
const String kActiveBaseUrl = kAndroidLanUrl;
