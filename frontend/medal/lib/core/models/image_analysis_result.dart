import 'dart:convert';

class DetectedObject {
  final String className;
  final double confidence;

  const DetectedObject({
    required this.className,
    required this.confidence,
  });

  factory DetectedObject.fromJson(Map<String, dynamic> json) {
    return DetectedObject(
      className: (json['class'] ?? json['class_name'] ?? '').toString(),
      confidence: ((json['confidence'] ?? 0.0) as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'class': className,
        'confidence': confidence,
      };
}

class SDGSuggestion {
  final int id;
  final String name;
  final double confidence;

  const SDGSuggestion({
    required this.id,
    required this.name,
    required this.confidence,
  });

  factory SDGSuggestion.fromJson(Map<String, dynamic> json) {
    return SDGSuggestion(
      id: (json['id'] ?? 0) as int,
      name: (json['name'] ?? '').toString(),
      confidence: ((json['confidence'] ?? 0.0) as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'confidence': confidence,
      };
}

class CivicIssue {
  final String label;
  final String category;
  final double confidence;

  const CivicIssue({
    required this.label,
    required this.category,
    required this.confidence,
  });

  factory CivicIssue.fromJson(Map<String, dynamic> json) {
    return CivicIssue(
      label: (json['label'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      confidence: ((json['confidence'] ?? 0.0) as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'label': label,
        'category': category,
        'confidence': confidence,
      };
}

class ImageAnalysisResult {
  final bool success;
  final CivicIssue issue;
  final List<DetectedObject> detections;
  final List<SDGSuggestion> sdgs;
  final String message;

  const ImageAnalysisResult({
    required this.success,
    required this.issue,
    required this.detections,
    required this.sdgs,
    required this.message,
  });

  factory ImageAnalysisResult.fromJson(Map<String, dynamic> json) {
    final analysis = (json['analysis'] as Map<String, dynamic>?) ?? {};
    final issueJson = (analysis['issue'] as Map<String, dynamic>?) ?? {};
    final detectionsList = (analysis['detections'] as List<dynamic>?) ?? [];
    final sdgsList = (analysis['sdgs'] as List<dynamic>?) ?? [];

    return ImageAnalysisResult(
      success: json['success'] == true,
      issue: CivicIssue.fromJson(issueJson),
      detections: detectionsList
          .map((e) => DetectedObject.fromJson(e as Map<String, dynamic>))
          .toList(),
      sdgs: sdgsList
          .map((e) => SDGSuggestion.fromJson(e as Map<String, dynamic>))
          .toList(),
      message: (json['message'] ?? '').toString(),
    );
  }

  factory ImageAnalysisResult.empty([String message = 'Unable to analyze image']) {
    return ImageAnalysisResult(
      success: false,
      issue: const CivicIssue(
        label: 'Unable to determine',
        category: 'unknown',
        confidence: 0.0,
      ),
      detections: const [],
      sdgs: const [],
      message: message,
    );
  }

  String toJsonString() {
    return jsonEncode({
      'issue': issue.toJson(),
      'detections': detections.map((d) => d.toJson()).toList(),
      'sdgs': sdgs.map((s) => s.toJson()).toList(),
    });
  }
}
