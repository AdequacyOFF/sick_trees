import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:yandex_maps_mapkit/mapkit.dart' as ymk;
import 'package:geolocator/geolocator.dart';

import '../services/ml_service.dart';
import '../services/api_service.dart';
import '../services/analysis_storage_service.dart';
import 'result_screen.dart';
import 'location_picker_screen.dart';
import 'analysis_upload_screen.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  final _picker = ImagePicker();
  final _ml = MLService();
  final _apiService = ApiServiceWithRetry();
  final _analysisStorage = AnalysisStorageService();

  Future<void> _pickFromGallery() async {
    final x = await _picker.pickImage(source: ImageSource.gallery);
    if (x == null) return;

    final labels = await _ml.analyzeImage(File(x.path));
    if (!mounted) return;

    // Показываем экран выбора: сохранить точку или отправить на анализ
    await _showActionChoice(x.path, labels);
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
      // Сохранить точку на карте
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ResultScreen(
          imagePath: imagePath,
          labels: labels,
          fromGallery: true,
        ),
      ));
    } else if (result == 2) {
      // Отправить на анализ
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
    return Center(
      child: ElevatedButton.icon(
        onPressed: _pickFromGallery,
        icon: const Icon(Icons.photo_library),
        label: const Text('Выбрать из галереи'),
      ),
    );
  }
}