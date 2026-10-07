// test/location_picker_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:medal/core/models/selected_location.dart';

void main() {
  group('SelectedLocation Model Tests', () {
    test('Constructs and serializes correctly', () {
      const loc = SelectedLocation(
        latitude: 12.917142,
        longitude: 80.192384,
        address: '2nd Street, Medavakkam, Chennai, Tamil Nadu',
        placeId: 'ChIJ12345',
      );

      expect(loc.latitude, 12.917142);
      expect(loc.longitude, 80.192384);
      expect(loc.address, '2nd Street, Medavakkam, Chennai, Tamil Nadu');
      expect(loc.placeId, 'ChIJ12345');

      final json = loc.toJson();
      expect(json['latitude'], 12.917142);
      expect(json['longitude'], 80.192384);
      expect(json['address'], '2nd Street, Medavakkam, Chennai, Tamil Nadu');
      expect(json['placeId'], 'ChIJ12345');

      final fromJson = SelectedLocation.fromJson(json);
      expect(fromJson, equals(loc));
    });

    test('copyWith updates fields as expected', () {
      const loc = SelectedLocation(
        latitude: 12.0,
        longitude: 80.0,
        address: 'Old Address',
      );

      final updated = loc.copyWith(
        address: 'New Address',
        placeId: 'PID_999',
      );

      expect(updated.latitude, 12.0);
      expect(updated.longitude, 80.0);
      expect(updated.address, 'New Address');
      expect(updated.placeId, 'PID_999');
    });
  });
}
