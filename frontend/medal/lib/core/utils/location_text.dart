// lib/core/utils/location_text.dart
// Picks a human-readable place name for a complaint/feed item.

final RegExp _coordPattern = RegExp(r'^\s*-?\d{1,3}(\.\d+)?\s*[,;\s]\s*-?\d{1,3}(\.\d+)?\s*$');

final RegExp _coordNoise =
    RegExp(r'\b(latitude|longitude|lat|lng|lon|long)\b|[:°]|(?<=[\d°])\s*[NSEW]\b', caseSensitive: false);

/// True for "12.97, 80.27", "Lat: 12.97, Lng: 80.27", "12.97° N, 80.27° E" (and empty/null).
bool looksLikeCoordinates(String? text) =>
    text == null ||
    text.trim().isEmpty ||
    _coordPattern.hasMatch(text.replaceAll(_coordNoise, ' ').trim());

/// Prefers a real place name over a raw "lat, lng" string. Falls back to the
/// coordinates (legacy rows not yet migrated) and finally to [fallback].
String displayLocation(Map<String, dynamic> item, {String fallback = 'Location not specified'}) {
  final address = item['location_address']?.toString();
  final location = item['location']?.toString();
  if (!looksLikeCoordinates(address)) return address!.trim();
  if (!looksLikeCoordinates(location)) return location!.trim();
  if (address != null && address.trim().isNotEmpty) return address.trim();
  if (location != null && location.trim().isNotEmpty) return location.trim();
  return fallback;
}
