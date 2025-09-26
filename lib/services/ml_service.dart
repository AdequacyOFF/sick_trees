// lib/ml_service.dart
import 'dart:io';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

/// Результат распознавания: метка и уверенность [0..1].
class LabelResult {
  final String label;
  final double confidence;

  const LabelResult({
    required this.label,
    required this.confidence,
  });

  Map<String, dynamic> toJson() => {
    'label': label,
    'confidence': confidence,
  };

  factory LabelResult.fromJson(Map<String, dynamic> json) => LabelResult(
    label: (json['label'] ?? '') as String,
    confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
  );
}

/// Обёртка над Google ML Kit (on-device image labeling).
class MLService {
  ImageLabeler? _labeler;
  final double confidenceThreshold;

  MLService({this.confidenceThreshold = 0.5});

  Future<void> init() async {
    _labeler ??= ImageLabeler(
      options: ImageLabelerOptions(confidenceThreshold: confidenceThreshold),
    );
  }

  Future<List<LabelResult>> analyzeImage(File imageFile) async {
    await init();
    final input = InputImage.fromFile(imageFile);
    final labels = await _labeler!.processImage(input);
    return labels
        .map((e) => LabelResult(label: e.label, confidence: e.confidence))
        .toList();
  }

  Future<void> dispose() async {
    await _labeler?.close();
    _labeler = null;
  }
}
