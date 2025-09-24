import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/ml_service.dart';
import 'result_screen.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  final _picker = ImagePicker();
  final _ml = MLService();

  @override
  void initState() {
    super.initState();
    _ml.init();
  }

  Future<void> _pick() async {
    final x = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1600);
    if (x == null) return;
    final labels = await _ml.analyzeImage(File(x.path));
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ResultScreen(imagePath: x.path, labels: labels),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ElevatedButton.icon(
        onPressed: _pick,
        icon: const Icon(Icons.photo_library),
        label: const Text('Выбрать из галереи'),
      ),
    );
  }
}