// lib/core/services/location_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:medal/config/maps_config.dart';
import 'package:medal/core/models/selected_location.dart';

class PlaceSuggestion {
  final String placeId;
  final String mainText;
  final String secondaryText;
  final String fullText;

  const PlaceSuggestion({
    required this.placeId,
    required this.mainText,
    required this.secondaryText,
    required this.fullText,
  });

  @override
  String toString() => fullText;
}

class LocationServiceException implements Exception {
  final String message;
  final String? technicalDetails;

  LocationServiceException(this.message, [this.technicalDetails]);

  @override
  String toString() => message;
}

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  /// Default fallback location (Chennai centre) if GPS is completely unavailable
  static const double defaultLat = 12.917142;
  static const double defaultLng = 80.192384;

  /// Check permissions and fetch current GPS device location
  Future<Position> getCurrentPosition() async {
    bool serviceEnabled;
    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
    } catch (e) {
      serviceEnabled = true;
    }

    if (!serviceEnabled) {
      throw LocationServiceException(
        'Location services (GPS) are disabled on your device. Please turn on GPS.',
      );
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw LocationServiceException(
          'Location permission was denied. You can still search or select a location manually on the map.',
        );
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw LocationServiceException(
        'Location permission is permanently denied in device settings. You can still search or select manually on the map.',
      );
    }

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 12),
      );
    } on TimeoutException {
      // Fallback to last known position on timeout
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) return lastKnown;
      throw LocationServiceException(
        'GPS request timed out. Please check device location settings or select manually on the map.',
      );
    } catch (e) {
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) return lastKnown;
      throw LocationServiceException(
        'Could not obtain current GPS coordinates: $e',
      );
    }
  }

  /// Reads Google's JSON error body (Places API New) into a short description.
  /// Never includes the request URL, so the API key can't leak into messages.
  static String _describeNewApiError(http.Response response) {
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final err = (body['error'] as Map?)?.cast<String, dynamic>() ?? const {};
      final status = err['status']?.toString() ?? 'HTTP ${response.statusCode}';
      final message = err['message']?.toString() ?? '';
      String reason = '';
      final details = err['details'];
      if (details is List) {
        for (final d in details) {
          if (d is Map && d['reason'] != null) {
            reason = d['reason'].toString();
            break;
          }
        }
      }
      return [status, if (reason.isNotEmpty) reason, message]
          .where((e) => e.isNotEmpty)
          .join(' | ');
    } catch (_) {
      return 'HTTP ${response.statusCode}';
    }
  }

  /// Turns Google's error text into the exact Cloud Console fix.
  static String explainPlacesFailure(String newApiError, String legacyError) {
    final all = '$newApiError $legacyError'.toLowerCase();
    if (all.contains('billing')) {
      return 'Google Places is blocked because billing is not enabled on the '
          'Google Cloud project. Enable billing for the project that owns the API key.';
    }
    if (all.contains('service_disabled') ||
        all.contains('has not been used') ||
        all.contains('is not enabled') ||
        all.contains('api project is not authorized')) {
      return 'The Places API is not enabled for this API key\'s project. In Google Cloud '
          'Console enable "Places API (New)" (and "Geocoding API").';
    }
    if (all.contains('android_app_blocked') ||
        all.contains('android client application') ||
        all.contains('ip_address_blocked') ||
        all.contains('referer') ||
        all.contains('referrer') ||
        all.contains('api_key_http_referrer_blocked')) {
      return 'The API key\'s application restriction is rejecting this request. '
          'Places web-service calls from the app need a key with no Android/HTTP-referrer '
          'restriction (restrict it by API instead), or add the app\'s package name and SHA-1.';
    }
    if (all.contains('api_key_service_blocked') ||
        all.contains('api_target_blocked') ||
        all.contains('requests to this api') ) {
      return 'The API key\'s "API restrictions" do not include Places API (New). '
          'Add "Places API (New)" and "Geocoding API" to the key\'s allowed APIs.';
    }
    if (all.contains('api key not valid') || all.contains('invalid')) {
      return 'The Google Maps API key is invalid. Check MAPS_API_KEY.';
    }
    return 'Google Places rejected the request. Verify the API key, enabled APIs, '
        'billing and key restrictions in Google Cloud Console.';
  }

  /// Search locations using Google Places API (supports both Places API New & Legacy)
  Future<List<PlaceSuggestion>> searchPlaces(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    final apiKey = MapsConfig.apiKey;
    if (apiKey.isEmpty) {
      throw LocationServiceException(
        'Google Maps API Key is not configured. Please supply MAPS_API_KEY in local.properties or launch flags.',
      );
    }

    // 1. Try Places API (New) autocomplete
    String newApiError = '';
    try {
      final uri = Uri.parse('https://places.googleapis.com/v1/places:autocomplete');
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'X-Goog-Api-Key': apiKey,
            },
            body: jsonEncode({
              'input': cleanQuery,
            }),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final suggestions = data['suggestions'] as List<dynamic>?;
        if (suggestions != null) {
          final results = <PlaceSuggestion>[];
          for (final item in suggestions) {
            final pred = item['placePrediction'] as Map<String, dynamic>?;
            if (pred == null) continue;
            final placeId = (pred['placeId'] ?? pred['place'] ?? '').toString();
            final structured = pred['structuredFormat'] as Map<String, dynamic>?;
            final mainText = structured?['mainText']?['text']?.toString() ??
                pred['text']?['text']?.toString() ??
                '';
            final secondaryText = structured?['secondaryText']?['text']?.toString() ?? '';
            final fullText = pred['text']?['text']?.toString() ??
                (secondaryText.isNotEmpty ? '$mainText, $secondaryText' : mainText);

            if (placeId.isNotEmpty && fullText.isNotEmpty) {
              results.add(PlaceSuggestion(
                placeId: placeId.replaceFirst('places/', ''),
                mainText: mainText,
                secondaryText: secondaryText,
                fullText: fullText,
              ));
            }
          }
          if (results.isNotEmpty) return results;
        }
      } else {
        // Keep Google's reason so the failure can be explained if legacy fails too.
        newApiError = _describeNewApiError(response);
        debugPrint('[MEDAL] Places API (New) autocomplete failed: $newApiError');
      }
    } on SocketException {
      throw LocationServiceException(
        'Network error: Unable to connect to Google Places. Please check your internet connection.',
      );
    } catch (_) {
      // Fall through to legacy
    }

    // 2. Fallback to Google Places Legacy Autocomplete
    try {
      final legacyUri = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=${Uri.encodeComponent(cleanQuery)}&key=$apiKey',
      );
      final response = await http.get(legacyUri).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final status = data['status'] as String? ?? '';
        if (status == 'OK') {
          final predictions = data['predictions'] as List<dynamic>? ?? [];
          return predictions.map((p) {
            final pid = p['place_id'] as String? ?? '';
            final fullDesc = p['description'] as String? ?? '';
            final sf = p['structured_formatting'] as Map<String, dynamic>?;
            final main = sf?['main_text'] as String? ?? fullDesc;
            final sec = sf?['secondary_text'] as String? ?? '';
            return PlaceSuggestion(
              placeId: pid,
              mainText: main,
              secondaryText: sec,
              fullText: fullDesc,
            );
          }).toList();
        } else if (status == 'ZERO_RESULTS') {
          return [];
        } else if (status == 'REQUEST_DENIED' || status == 'OVER_QUERY_LIMIT') {
          final errMsg = data['error_message']?.toString() ?? status;
          debugPrint('[MEDAL] Places API (legacy) $status: $errMsg');
          throw LocationServiceException(
            explainPlacesFailure(newApiError, '$status $errMsg'),
            'new: $newApiError | legacy: $status $errMsg',
          );
        }
      }
    } on SocketException {
      throw LocationServiceException(
        'Network error: Unable to reach Google Places. Please check your internet connection.',
      );
    } catch (e) {
      if (e is LocationServiceException) rethrow;
      throw LocationServiceException('Search failed: $e');
    }

    return [];
  }

  /// Fetch location details (lat, lng, address) for a selected place ID
  Future<SelectedLocation> getPlaceDetails(String placeId, String fallbackAddress) async {
    final apiKey = MapsConfig.apiKey;
    final cleanPlaceId = placeId.replaceFirst('places/', '').trim();

    if (apiKey.isNotEmpty) {
      // 1. Try Places API (New) details
      try {
        final uri = Uri.parse(
          'https://places.googleapis.com/v1/places/$cleanPlaceId?fields=id,formattedAddress,location&key=$apiKey',
        );
        final response = await http.get(uri).timeout(const Duration(seconds: 8));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final loc = data['location'] as Map<String, dynamic>?;
          if (loc != null && loc['latitude'] != null && loc['longitude'] != null) {
            final lat = (loc['latitude'] as num).toDouble();
            final lng = (loc['longitude'] as num).toDouble();
            final addr = (data['formattedAddress'] as String?)?.trim();
            return SelectedLocation(
              latitude: lat,
              longitude: lng,
              address: (addr != null && addr.isNotEmpty) ? addr : fallbackAddress,
              placeId: cleanPlaceId,
            );
          }
        }
      } catch (_) {}

      // 2. Try Places API (Legacy) details
      try {
        final legacyUri = Uri.parse(
          'https://maps.googleapis.com/maps/api/place/details/json?place_id=$cleanPlaceId&fields=geometry,formatted_address&key=$apiKey',
        );
        final response = await http.get(legacyUri).timeout(const Duration(seconds: 8));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          if (data['status'] == 'OK' && data['result'] != null) {
            final res = data['result'] as Map<String, dynamic>;
            final geom = res['geometry']?['location'] as Map<String, dynamic>?;
            if (geom != null && geom['lat'] != null && geom['lng'] != null) {
              final lat = (geom['lat'] as num).toDouble();
              final lng = (geom['lng'] as num).toDouble();
              final addr = (res['formatted_address'] as String?)?.trim();
              return SelectedLocation(
                latitude: lat,
                longitude: lng,
                address: (addr != null && addr.isNotEmpty) ? addr : fallbackAddress,
                placeId: cleanPlaceId,
              );
            }
          }
        }
      } catch (_) {}
    }

    // 3. Fallback: geocode fallbackAddress if coordinates could not be retrieved
    try {
      final locations = await geo.locationFromAddress(fallbackAddress);
      if (locations.isNotEmpty) {
        final first = locations.first;
        return SelectedLocation(
          latitude: first.latitude,
          longitude: first.longitude,
          address: fallbackAddress,
          placeId: cleanPlaceId,
        );
      }
    } catch (_) {}

    throw LocationServiceException(
      'Could not retrieve coordinates for the selected place.',
    );
  }

  /// Reverse geocode latitude and longitude to a clean readable address
  Future<String> reverseGeocode(double latitude, double longitude) async {
    final apiKey = MapsConfig.apiKey;

    // 1. Try Google Geocoding API if key is present
    if (apiKey.isNotEmpty) {
      try {
        final uri = Uri.parse(
          'https://maps.googleapis.com/maps/api/geocode/json?latlng=$latitude,$longitude&key=$apiKey',
        );
        final response = await http.get(uri).timeout(const Duration(seconds: 8));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          if (data['status'] == 'OK') {
            final results = data['results'] as List<dynamic>?;
            if (results != null && results.isNotEmpty) {
              final formatted = results[0]['formatted_address'] as String?;
              if (formatted != null && formatted.trim().isNotEmpty) {
                return _cleanFormattedAddress(formatted.trim());
              }
            }
          }
        }
      } catch (e) {
        debugPrint('[MEDAL] Google Geocoding HTTP warning: $e');
      }
    }

    // 2. Fallback to platform native geocoder (Google Play Services / iOS CoreLocation)
    try {
      final placemarks = await geo.placemarkFromCoordinates(
        latitude,
        longitude,
      );
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final formatted = _formatPlacemark(p);
        if (formatted.isNotEmpty) {
          return formatted;
        }
      }
    } catch (e) {
      debugPrint('[MEDAL] Native Geocoding warning: $e');
    }

    // 3. Fallback to formatted coordinates string if reverse geocoding is unavailable
    return 'Lat: ${latitude.toStringAsFixed(6)}, Lng: ${longitude.toStringAsFixed(6)}';
  }

  static String _formatPlacemark(geo.Placemark p) {
    final parts = <String>[];
    if (p.street != null && p.street!.trim().isNotEmpty && p.street != p.name) {
      parts.add(p.street!.trim());
    } else if (p.name != null && p.name!.trim().isNotEmpty && p.name != p.subLocality) {
      parts.add(p.name!.trim());
    }

    if (p.subLocality != null &&
        p.subLocality!.trim().isNotEmpty &&
        !parts.contains(p.subLocality!.trim())) {
      parts.add(p.subLocality!.trim());
    }

    if (p.locality != null &&
        p.locality!.trim().isNotEmpty &&
        !parts.contains(p.locality!.trim())) {
      parts.add(p.locality!.trim());
    }

    if (p.administrativeArea != null &&
        p.administrativeArea!.trim().isNotEmpty &&
        !parts.contains(p.administrativeArea!.trim())) {
      parts.add(p.administrativeArea!.trim());
    }

    if (p.country != null &&
        p.country!.trim().isNotEmpty &&
        !parts.contains(p.country!.trim())) {
      parts.add(p.country!.trim());
    }

    return parts.join(', ');
  }

  static String _cleanFormattedAddress(String addr) {
    // Return clean trimmed address without plus codes if possible
    if (addr.contains('+') && addr.contains(' ')) {
      final parts = addr.split(' ');
      if (parts.first.contains('+') && parts.length > 1) {
        return parts.sublist(1).join(' ').trim();
      }
    }
    return addr;
  }
}
