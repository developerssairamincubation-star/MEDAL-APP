// lib/widgets/location_picker.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:medal/config/maps_config.dart';
import 'package:medal/core/models/selected_location.dart';
import 'package:medal/core/services/location_service.dart';

enum MapStatus {
  initializing,
  ready,
  error,
}

enum LocationStatus {
  idle,
  detecting,
  resolved,
  error,
}

class LocationPickerWidget extends StatefulWidget {
  final SelectedLocation? initialLocation;
  final ValueChanged<SelectedLocation?> onLocationConfirmed;
  final ValueChanged<SelectedLocation?>? onLocationChanged;

  const LocationPickerWidget({
    super.key,
    this.initialLocation,
    required this.onLocationConfirmed,
    this.onLocationChanged,
  });

  @override
  State<LocationPickerWidget> createState() => _LocationPickerWidgetState();
}

class _LocationPickerWidgetState extends State<LocationPickerWidget>
    with SingleTickerProviderStateMixin {
  GoogleMapController? _mapController;
  final LocationService _locationService = LocationService();

  // Status tracking
  MapStatus _mapStatus = MapStatus.initializing;
  LocationStatus _locationStatus = LocationStatus.idle;

  // Search
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<PlaceSuggestion> _searchResults = [];
  bool _isSearching = false;
  Timer? _searchDebounce;

  // Active Map Position & Address
  late LatLng _currentCenter;
  String _currentAddress = 'Locating incident position...';
  String? _currentPlaceId;

  // Reverse geocoding debounce
  Timer? _geocodeDebounce;
  bool _isGeocoding = false;

  // Confirmation state
  bool _isConfirmed = false;
  SelectedLocation? _confirmedLocation;

  // Error messaging
  String? _errorMessage;

  // Primary MEDAL colors
  static const Color primaryColor = Color(0xFF2321BC);

  @override
  void initState() {
    super.initState();

    debugPrint('[MEDAL LocationPicker] Initializing on platform: ${defaultTargetPlatform.name} (isWeb: $kIsWeb)');
    debugPrint('[MEDAL LocationPicker] API key configured: ${MapsConfig.hasApiKey}');

    if (widget.initialLocation != null) {
      _currentCenter = LatLng(
        widget.initialLocation!.latitude,
        widget.initialLocation!.longitude,
      );
      _currentAddress = widget.initialLocation!.address;
      _currentPlaceId = widget.initialLocation!.placeId;
      _confirmedLocation = widget.initialLocation;
      _isConfirmed = true;
      _locationStatus = LocationStatus.resolved;
    } else {
      // Default fallback camera position: Chennai urban center
      _currentCenter = const LatLng(LocationService.defaultLat, LocationService.defaultLng);
      _currentAddress = 'Pin incident location on map or search address';

      // Detect GPS location asynchronously in background WITHOUT blocking map rendering
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _detectGpsLocationAsync(animateCamera: true);
      });
    }

    _searchFocusNode.addListener(() {
      if (!_searchFocusNode.hasFocus && mounted) {
        setState(() {
          _searchResults = [];
        });
      }
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _geocodeDebounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  /// Asynchronously detects device GPS location and moves map camera when ready
  Future<void> _detectGpsLocationAsync({bool animateCamera = true}) async {
    if (_locationStatus == LocationStatus.detecting) return;

    setState(() {
      _locationStatus = LocationStatus.detecting;
      _errorMessage = null;
    });

    try {
      debugPrint('[MEDAL LocationPicker] Requesting device GPS position...');
      final pos = await _locationService.getCurrentPosition();
      final newLatLng = LatLng(pos.latitude, pos.longitude);
      debugPrint('[MEDAL LocationPicker] GPS resolved: ${pos.latitude}, ${pos.longitude}');

      if (!mounted) return;
      setState(() {
        _currentCenter = newLatLng;
        _locationStatus = LocationStatus.resolved;
      });

      if (animateCamera && _mapController != null) {
        await _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: newLatLng, zoom: 16.5),
          ),
        );
      }

      await _reverseGeocodePosition(newLatLng);
    } catch (e) {
      debugPrint('[MEDAL LocationPicker] GPS detection error: $e');
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      setState(() {
        _locationStatus = LocationStatus.error;
        _errorMessage = msg;
        if (_currentAddress == 'Locating incident position...') {
          _currentAddress = 'GPS unavailable. Move map or search address below.';
        }
      });
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    debugPrint('[MEDAL LocationPicker] Native GoogleMap created successfully');
    _mapController = controller;
    if (mounted) {
      setState(() {
        _mapStatus = MapStatus.ready;
      });
    }
  }

  /// Tracks continuous camera movement for fixed-center-pin UX
  void _onCameraMove(CameraPosition position) {
    _currentCenter = position.target;
    if (_isConfirmed) {
      setState(() {
        _isConfirmed = false;
      });
    }
  }

  /// Debounces reverse geocoding after camera movement stops
  void _onCameraIdle() {
    _geocodeDebounce?.cancel();
    _geocodeDebounce = Timer(const Duration(milliseconds: 700), () {
      if (mounted) {
        _reverseGeocodePosition(_currentCenter);
      }
    });
  }

  Future<void> _reverseGeocodePosition(LatLng target) async {
    setState(() {
      _isGeocoding = true;
    });

    try {
      final addr = await _locationService.reverseGeocode(
        target.latitude,
        target.longitude,
      );
      if (!mounted) return;
      setState(() {
        _currentAddress = addr;
        _currentPlaceId = null;
        _locationStatus = LocationStatus.resolved;
      });
      _notifyLocationChanged();
    } catch (e) {
      debugPrint('[MEDAL LocationPicker] Reverse geocode error: $e');
      if (!mounted) return;
      setState(() {
        _currentAddress =
            'Lat: ${target.latitude.toStringAsFixed(6)}, Lng: ${target.longitude.toStringAsFixed(6)}';
      });
      _notifyLocationChanged();
    } finally {
      if (mounted) {
        setState(() => _isGeocoding = false);
      }
    }
  }

  void _onSearchQueryChanged(String query) {
    _searchDebounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 400), () async {
      if (!mounted) return;
      setState(() => _isSearching = true);
      try {
        final results = await _locationService.searchPlaces(query);
        if (!mounted) return;
        setState(() {
          _searchResults = results;
          _errorMessage = null;
        });
      } catch (e) {
        debugPrint('[MEDAL LocationPicker] Places search error: $e');
        if (!mounted) return;
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _searchResults = [];
        });
      } finally {
        if (mounted) {
          setState(() => _isSearching = false);
        }
      }
    });
  }

  Future<void> _selectSearchResult(PlaceSuggestion suggestion) async {
    _searchFocusNode.unfocus();
    _searchController.text = suggestion.mainText;
    setState(() {
      _searchResults = [];
      _isSearching = true;
      _isConfirmed = false;
      _errorMessage = null;
    });

    try {
      final loc = await _locationService.getPlaceDetails(
        suggestion.placeId,
        suggestion.fullText,
      );

      final newTarget = LatLng(loc.latitude, loc.longitude);
      if (!mounted) return;
      setState(() {
        _currentCenter = newTarget;
        _currentAddress = loc.address;
        _currentPlaceId = loc.placeId;
        _locationStatus = LocationStatus.resolved;
      });

      if (_mapController != null) {
        await _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: newTarget, zoom: 16.5),
          ),
        );
      }

      _notifyLocationChanged();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  void _notifyLocationChanged() {
    final loc = SelectedLocation(
      latitude: _currentCenter.latitude,
      longitude: _currentCenter.longitude,
      address: _currentAddress,
      placeId: _currentPlaceId,
    );
    widget.onLocationChanged?.call(loc);
  }

  void _confirmLocation() {
    final confirmed = SelectedLocation(
      latitude: _currentCenter.latitude,
      longitude: _currentCenter.longitude,
      address: _currentAddress,
      placeId: _currentPlaceId,
    );

    setState(() {
      _isConfirmed = true;
      _confirmedLocation = confirmed;
      _errorMessage = null;
    });

    widget.onLocationConfirmed(confirmed);
  }

  void _reopenPicker() {
    setState(() {
      _isConfirmed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isConfirmed && _confirmedLocation != null) {
      return _buildConfirmedCard();
    }

    return _buildPickerCard();
  }

  /// Confirmed State Card
  Widget _buildConfirmedCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 16,
                      color: Color(0xFF10B981),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    "Location Secured",
                    style: TextStyle(
                      color: Color(0xFF047857),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: _reopenPicker,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_location_alt, size: 14, color: primaryColor),
                      SizedBox(width: 4),
                      Text(
                        "Adjust",
                        style: TextStyle(
                          color: primaryColor,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.location_on, color: primaryColor, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _confirmedLocation!.address,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Coordinates: ${_confirmedLocation!.latitude.toStringAsFixed(6)}, ${_confirmedLocation!.longitude.toStringAsFixed(6)}",
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Interactive Picker Component
  Widget _buildPickerCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header title & info
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "INCIDENT LOCATION",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.5,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    "Real-time GPS / Map",
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Stack(
              children: [
                TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  onChanged: _onSearchQueryChanged,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    hintText: "Search for a street, area or landmark...",
                    hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF64748B)),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18, color: Color(0xFF94A3B8)),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchQueryChanged('');
                            },
                          )
                        : (_isSearching
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : null),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: primaryColor, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Autocomplete suggestions list if search results exist
          if (_searchResults.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(14, 6, 14, 6),
              constraints: const BoxConstraints(maxHeight: 180),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0F000000),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _searchResults.length,
                separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                itemBuilder: (context, index) {
                  final suggestion = _searchResults[index];
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.location_on_outlined, size: 18, color: primaryColor),
                    title: Text(
                      suggestion.mainText,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                    subtitle: suggestion.secondaryText.isNotEmpty
                        ? Text(
                            suggestion.secondaryText,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )
                        : null,
                    onTap: () => _selectSearchResult(suggestion),
                  );
                },
              ),
            ),

          const SizedBox(height: 10),

          // Error / Notice Banner
          if (_errorMessage != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Color(0xFFDC2626)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFFB91C1C),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Interactive Map Container with Center Pin
          SizedBox(
            height: 220,
            width: double.infinity,
            child: _mapStatus == MapStatus.error
                ? Container(
                    color: const Color(0xFFF8FAFC),
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.map_outlined, size: 36, color: Color(0xFF94A3B8)),
                          const SizedBox(height: 8),
                          const Text(
                            "Unable to load map",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            "Please check your connection or try again.",
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 0,
                            ),
                            onPressed: () {
                              setState(() {
                                _mapStatus = MapStatus.initializing;
                              });
                            },
                            icon: const Icon(Icons.refresh, size: 14),
                            label: const Text(
                              "Retry",
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : Stack(
                    alignment: Alignment.center,
                    children: [
                      // Real Native GoogleMap Widget
                      GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _currentCenter,
                    zoom: 15.5,
                  ),
                  onMapCreated: _onMapCreated,
                  onCameraMove: _onCameraMove,
                  onCameraIdle: _onCameraIdle,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  compassEnabled: true,
                  mapToolbarEnabled: false,
                  gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                    Factory<OneSequenceGestureRecognizer>(
                      () => EagerGestureRecognizer(),
                    ),
                  },
                ),

                // Center Pin with Floating Radar Glow
                IgnorePointer(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: primaryColor.withValues(alpha: 0.2),
                        ),
                        child: const Icon(
                          Icons.location_on,
                          color: primaryColor,
                          size: 38,
                          shadows: [
                            Shadow(
                              color: Colors.black26,
                              blurRadius: 8,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                      ),
                      // Ground shadow dot
                      Container(
                        width: 6,
                        height: 3,
                        decoration: BoxDecoration(
                          color: Colors.black38,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(height: 24), // Offset to align tip of pin precisely to center
                    ],
                  ),
                ),

                // Top Instruction Pill
                Positioned(
                  top: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xCC0F172A),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.touch_app, size: 13, color: Colors.white),
                        SizedBox(width: 6),
                        Text(
                          "Move the map to place the pin on the incident location",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Map Control Overlay: Zoom In / Zoom Out / Center GPS
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildMapIconButton(
                        icon: Icons.add,
                        tooltip: "Zoom in",
                        onTap: () {
                          _mapController?.animateCamera(CameraUpdate.zoomIn());
                        },
                      ),
                      const SizedBox(height: 6),
                      _buildMapIconButton(
                        icon: Icons.remove,
                        tooltip: "Zoom out",
                        onTap: () {
                          _mapController?.animateCamera(CameraUpdate.zoomOut());
                        },
                      ),
                      const SizedBox(height: 6),
                      _buildMapIconButton(
                        icon: _locationStatus == LocationStatus.detecting
                            ? Icons.sync
                            : Icons.my_location,
                        tooltip: "Use Current GPS Location",
                        iconColor: primaryColor,
                        isLoading: _locationStatus == LocationStatus.detecting,
                        onTap: () => _detectGpsLocationAsync(animateCamera: true),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Selected Address Detail Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "SELECTED LOCATION",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (_isGeocoding || _locationStatus == LocationStatus.detecting)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(strokeWidth: 1.5, color: primaryColor),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _locationStatus == LocationStatus.detecting
                                ? "Detecting GPS..."
                                : "Finding address...",
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Icons.pin_drop, size: 18, color: primaryColor),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _currentAddress,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F172A),
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Coordinates: ${_currentCenter.latitude.toStringAsFixed(6)}, ${_currentCenter.longitude.toStringAsFixed(6)}",
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: Color(0xFF64748B),
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Action Buttons: "Current Location" & "Confirm Location"
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: _locationStatus == LocationStatus.detecting
                            ? null
                            : () => _detectGpsLocationAsync(animateCamera: true),
                        icon: _locationStatus == LocationStatus.detecting
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.my_location, size: 16, color: Color(0xFF334155)),
                        label: const Text(
                          "Current Location",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 5,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        onPressed: _confirmLocation,
                        icon: const Icon(Icons.check, size: 17),
                        label: const Text(
                          "Confirm Location",
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color iconColor = const Color(0xFF1E293B),
    bool isLoading = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: isLoading ? null : onTap,
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            child: isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor),
                  )
                : Icon(icon, size: 18, color: iconColor),
          ),
        ),
      ),
    );
  }
}
