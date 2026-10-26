import 'package:flutter_test/flutter_test.dart';
import 'package:medal/core/services/api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Profile Photo & MinIO URL Resolution Tests', () {
    final apiService = ApiService();

    test('resolveImageUrl returns empty string for null or empty input', () {
      expect(apiService.resolveImageUrl(null), equals(''));
      expect(apiService.resolveImageUrl(''), equals(''));
      expect(apiService.resolveImageUrl('   '), equals(''));
    });

    test('resolveImageUrl resolves absolute MinIO URL to active target host and scheme', () {
      final inputUrl = 'http://localhost:9000/medal-evidence/profiles/42/photo.jpg';
      final resolved = apiService.resolveImageUrl(inputUrl);

      expect(resolved, contains(':9000/medal-evidence/profiles/42/photo.jpg'));
      expect(resolved, startsWith('http://'));
    });

    test('resolveImageUrl resolves relative profiles path to MinIO URL', () {
      final relativePath = '/profiles/42/photo.jpg';
      final resolved = apiService.resolveImageUrl(relativePath);

      expect(resolved, contains(':9000/medal-evidence/profiles/42/photo.jpg'));
    });

    test('resolveImageUrl preserves external HTTP image URLs', () {
      const externalUrl = 'https://images.unsplash.com/photo-1534528741775-53994a69daeb';
      expect(apiService.resolveImageUrl(externalUrl), equals(externalUrl));
    });

    test('resolveImageUrl preserves Cloudinary HTTPS URLs even if path contains profiles or reports', () {
      const cloudinaryUrl = 'https://res.cloudinary.com/uco2jihi/image/upload/v1234567890/medal/avatars/profiles/42/avatar.jpg';
      expect(apiService.resolveImageUrl(cloudinaryUrl), equals(cloudinaryUrl));

      const complaintUrl = 'https://res.cloudinary.com/uco2jihi/image/upload/v1234567890/medal/complaints/asset_abc123.jpg';
      expect(apiService.resolveImageUrl(complaintUrl), equals(complaintUrl));
    });
  });
}
