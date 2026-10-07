// lib/core/models/selected_location.dart

class SelectedLocation {
  final double latitude;
  final double longitude;
  final String address;
  final String? placeId;

  const SelectedLocation({
    required this.latitude,
    required this.longitude,
    required this.address,
    this.placeId,
  });

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
        if (placeId != null) 'placeId': placeId,
      };

  factory SelectedLocation.fromJson(Map<String, dynamic> json) => SelectedLocation(
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        address: json['address'] as String? ?? '',
        placeId: json['placeId'] as String?,
      );

  SelectedLocation copyWith({
    double? latitude,
    double? longitude,
    String? address,
    String? placeId,
  }) {
    return SelectedLocation(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      placeId: placeId ?? this.placeId,
    );
  }

  @override
  String toString() => 'SelectedLocation($latitude, $longitude, "$address")';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SelectedLocation &&
          runtimeType == other.runtimeType &&
          latitude == other.latitude &&
          longitude == other.longitude &&
          address == other.address;

  @override
  int get hashCode => Object.hash(latitude, longitude, address);
}
