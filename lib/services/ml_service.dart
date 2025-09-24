import 'dart:io';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

import '../models/tree_spot.dart';

class MLService {
  ImageLabeler? _labeler;

  Future<void> init() async {
    // Base model (on-device). Good to start with.
    _labeler ??= ImageLabeler(options: ImageLabelerOptions(confidenceThreshold: 0.5));
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
  }
}