import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medal/core/models/image_analysis_result.dart';
import 'package:medal/core/services/api_service.dart';

class MlAnalysisService {
  static final MlAnalysisService _instance = MlAnalysisService._internal();
  factory MlAnalysisService() => _instance;
  MlAnalysisService._internal();

  /// Analyzes an image by sending it to POST /api/v1/ml/analyze-image
  /// Returns a typed ImageAnalysisResult.
  /// Guarantees safe return (never throws or crashes the UI).
  Future<ImageAnalysisResult> analyzeImage({
    required Uint8List imageBytes,
    required String filename,
    String? mimeType,
  }) async {
    final baseUrl = ApiService().baseUrl;
    final uri = Uri.parse('$baseUrl/api/v1/ml/analyze-image');

    try {
      final request = http.MultipartRequest('POST', uri);

      // Attach token if user is authenticated (check in-memory or persisted session)
      String? token = ApiService().token;
      if (token == null || token.isEmpty) {
        try {
          final prefs = await SharedPreferences.getInstance();
          token = prefs.getString('medal_auth_token');
        } catch (_) {}
      }

      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      // Determine content type
      String safeFilename = filename.trim().isNotEmpty ? filename.trim() : 'evidence.jpg';
      if (!safeFilename.contains('.')) {
        safeFilename = '$safeFilename.jpg';
      }

      MediaType contentType = MediaType('image', 'jpeg');
      if (mimeType != null && mimeType.contains('/')) {
        final parts = mimeType.split('/');
        contentType = MediaType(parts[0].trim(), parts[1].trim());
      } else {
        final ext = safeFilename.split('.').last.toLowerCase();
        if (ext == 'png') {
          contentType = MediaType('image', 'png');
        } else if (ext == 'webp') {
          contentType = MediaType('image', 'webp');
        }
      }

      final multipartFile = http.MultipartFile.fromBytes(
        'image',
        imageBytes,
        filename: safeFilename,
        contentType: contentType,
      );
      request.files.add(multipartFile);

      debugPrint('ML: Sending image analysis request to $uri (${imageBytes.length} bytes)...');
      final streamedResponse = await request.send().timeout(
            const Duration(seconds: 25),
            onTimeout: () => throw TimeoutException('AI image analysis timed out after 25s.'),
          );

      final response = await http.Response.fromStream(streamedResponse).timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw TimeoutException('Reading response timed out.'),
          );

      debugPrint('ML: Response status = ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final result = ImageAnalysisResult.fromJson(data);
        debugPrint('ML: Analysis success: issue=${result.issue.label}, SDGs=${result.sdgs.length}');
        return result;
      } else {
        debugPrint('ML: Server returned error ${response.statusCode}: ${response.body}');
        return ImageAnalysisResult.empty(
          'Image analysis service unavailable (${response.statusCode}). Please select the SDG manually.',
        );
      }
    } on TimeoutException {
      debugPrint('ML: Analysis timed out.');
      return ImageAnalysisResult.empty(
        'AI analysis timed out. Please select the SDG manually.',
      );
    } catch (e) {
      debugPrint('ML: Analysis exception: $e');
      return ImageAnalysisResult.empty(
        'Unable to analyze image. Please select the SDG manually.',
      );
    }
  }
}
