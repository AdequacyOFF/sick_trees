import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../services/ml_service.dart';
import 'package:Dendrotector/screens/result_screen.dart';



class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  final _ml = MLService();
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _cameras = await availableCameras();
    _controller = CameraController(_cameras!.first, ResolutionPreset.medium, enableAudio: false);
    await _controller!.initialize();
    await _ml.init();
    if (mounted) setState(() => _busy = false);
  }

  @override
  void dispose() {
    _controller?.dispose();
    _ml.dispose();
    super.dispose();
  }

  Future<void> _take() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    final file = await _controller!.takePicture();
    final labels = await _ml.analyzeImage(File(file.path));
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ResultScreen(imagePath: file.path, labels: labels, fromGallery: false),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_busy) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        Expanded(child: CameraPreview(_controller!)),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _take,
                  icon: const Icon(Icons.camera),
                  label: const Text('Сделать фото'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}