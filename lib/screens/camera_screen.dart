import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../services/ml_service.dart';
import '../services/api_service.dart';
import '../services/analysis_storage_service.dart';
import 'result_screen.dart';
import 'location_picker_screen.dart';
import 'analysis_upload_screen.dart';
import 'package:yandex_maps_mapkit/mapkit.dart' as ymk;
import 'package:geolocator/geolocator.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  final _ml = MLService();
  final _apiService = ApiServiceWithRetry();
  final _analysisStorage = AnalysisStorageService();
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

  Future<void> _takePhoto() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    final file = await _controller!.takePicture();
    final labels = await _ml.analyzeImage(File(file.path));

    if (!mounted) return;

    // Показываем экран выбора: сохранить точку или отправить на анализ
    await _showActionChoice(file.path, labels);
  }

  Future<void> _showActionChoice(String imagePath, List<LabelResult> labels) async {
    final result = await showModalBottomSheet<int>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.map),
              title: const Text('Сохранить точку на карте'),
              subtitle: const Text('Сохранить с GPS координатами и заметкой'),
              onTap: () => Navigator.pop(context, 1),
            ),
            ListTile(
              leading: const Icon(Icons.analytics),
              title: const Text('Отправить на анализ'),
              subtitle: const Text('Детальный анализ дерева сервером'),
              onTap: () => Navigator.pop(context, 2),
            ),
          ],
        ),
      ),
    );

    if (result == 1) {
      // Сохранить точку на карте (старый функционал)
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ResultScreen(
            imagePath: imagePath,
            labels: labels,
            fromGallery: false
        ),
      ));
    } else if (result == 2) {
      // Отправить на анализ (новый функционал)
      await _sendForAnalysis(imagePath);
    }
  }

  Future<void> _sendForAnalysis(String imagePath) async {
    // Выбор координат для анализа
    final point = await _getCoordinates();
    if (point == null) return;

    // Создаем запись анализа
    final analysisId = await _analysisStorage.createAnalysis(
      imagePath: imagePath,
      lat: point.latitude,
      lng: point.longitude,
    );

    // Проверяем, что виджет еще mounted
    if (!mounted) return;

    // Показываем экран загрузки
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AnalysisUploadScreen(
        analysisId: analysisId,
        imageFile: File(imagePath),
      ),
    ));
  }

  Future<ymk.Point?> _getCoordinates() async {
    try {
      // Предлагаем выбрать на карте или использовать GPS
      final result = await showDialog<ymk.Point>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Выбор координат'),
          content: const Text('Как определить местоположение?'),
          actions: [
            TextButton(
              onPressed: () async {
                try {
                  final point = await _getGpsPoint();
                  Navigator.pop(context, point);
                } catch (e) {
                  Navigator.pop(context, null);
                }
              },
              child: const Text('Использовать GPS'),
            ),
            TextButton(
              onPressed: () async {
                try {
                  final point = await Navigator.push<ymk.Point>(
                    context,
                    MaterialPageRoute(builder: (_) => const LocationPickerScreen()),
                  );
                  Navigator.pop(context, point);
                } catch (e) {
                  Navigator.pop(context, null);
                }
              },
              child: const Text('Выбрать на карте'),
            ),
          ],
        ),
      );

      return result;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка выбора координат: $e')),
      );
      return null;
    }
  }

  Future<ymk.Point?> _getGpsPoint() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Доступ к GPS запрещен')),
        );
        return null;
      }
      final pos = await Geolocator.getCurrentPosition();
      return ymk.Point(latitude: pos.latitude, longitude: pos.longitude);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка GPS: $e')),
      );
      return null;
    }
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
                  onPressed: _takePhoto,
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