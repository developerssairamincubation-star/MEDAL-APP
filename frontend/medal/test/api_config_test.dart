import 'package:flutter_test/flutter_test.dart';
import 'package:medal/config/api_config.dart';
import 'package:medal/core/services/api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ApiConfig & Production Render Base URL Tests', () {
    test('Default productionUrl is https://medal-backend.onrender.com', () {
      expect(ApiConfig.productionUrl, equals('https://medal-backend.onrender.com'));
      expect(kRenderUrl, equals('https://medal-backend.onrender.com'));
    });

    test('Default baseUrl uses Render production URL when no override is set', () {
      expect(ApiConfig.baseUrl, equals('https://medal-backend.onrender.com'));
      expect(kActiveBaseUrl, equals('https://medal-backend.onrender.com'));
      expect(ApiConfig.isProduction, isTrue);
    });

    test('ApiService baseUrl matches ApiConfig.baseUrl', () {
      final apiService = ApiService();
      expect(apiService.baseUrl, equals('https://medal-backend.onrender.com'));
    });

    test('Legacy local configurations are preserved and accessible', () {
      expect(kLocalhostUrl, contains(':8000'));
      expect(kAndroidEmulatorUrl, equals('http://10.0.2.2:8000'));
      expect(kAndroidLanUrl, contains(':8000'));
      expect(kBackendPort, equals(8000));
    });

    test('resolveImageUrl preserves Cloudinary HTTPS URLs directly without rewriting', () {
      final apiService = ApiService();
      const cloudinaryUrl =
          'https://res.cloudinary.com/uco2jihi/image/upload/v1793037716/medal/complaints/asset_69020a.jpg';

      final resolved = apiService.resolveImageUrl(cloudinaryUrl);
      expect(resolved, equals(cloudinaryUrl));
      expect(resolved, startsWith('https://res.cloudinary.com'));
    });

    test('resolveImageUrl preserves external HTTP/HTTPS assets (Unsplash, etc.)', () {
      final apiService = ApiService();
      const externalUrl = 'https://images.unsplash.com/photo-1573496359142';

      expect(apiService.resolveImageUrl(externalUrl), equals(externalUrl));
    });
  });
}
