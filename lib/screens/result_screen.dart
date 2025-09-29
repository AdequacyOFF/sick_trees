import 'dart:io';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:geolocator/geolocator.dart';
import 'package:yandex_maps_mapkit/mapkit.dart' as ymk;

import '../services/ml_service.dart' show LabelResult;
import '../models/tree_spot.dart';
import '../services/storage_service.dart';
import '../screens/location_picker_screen.dart';

class ResultScreen extends StatefulWidget {
  const ResultScreen({
    super.key,
    required this.imagePath,
    required this.labels,
    this.fromGallery = false,
  });

  final String imagePath;
  final List<LabelResult> labels;
  final bool fromGallery;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  final _commentCtrl = TextEditingController();
  final _storage = StorageService();
  final _uuid = const Uuid();

  ymk.Point? _pickedPoint;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _storage.load();
  }

  Future<void> _pickOnMap() async {
    try {
      final res = await Navigator.push<ymk.Point>(
        context,
        MaterialPageRoute(builder: (_) => const LocationPickerScreen()),
      );
      if (res != null) {
        setState(() => _pickedPoint = res);
      }
    } catch (e) {
      setState(() => _error = 'Ошибка выбора места: $e');
    }
  }

  Future<ymk.Point?> _getGpsPoint() async {
    try {
      // Проверяем разрешения
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _error = 'Доступ к GPS запрещен');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _error = 'Доступ к GPS заблокирован навсегда. Разрешите в настройках устройства');
        return null;
      }

      // Получаем текущую позицию с таймаутом
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 10),
      ).timeout(const Duration(seconds: 15));

      return ymk.Point(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (e) {
      setState(() => _error = 'Ошибка GPS: $e');
      return null;
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      ymk.Point point;

      if (_pickedPoint != null) {
        // Используем выбранную на карте точку
        point = _pickedPoint!;
      } else {
        // Пытаемся получить GPS координаты
        final gpsPoint = await _getGpsPoint();
        if (gpsPoint == null) {
          setState(() => _saving = false);
          return; // Не продолжаем если GPS недоступен
        }
        point = gpsPoint;
      }

      final spot = TreeSpot(
        id: _uuid.v4(),
        lat: point.latitude,
        lng: point.longitude,
        labels: widget.labels,
        comment: _commentCtrl.text.trim().isEmpty ? null : _commentCtrl.text.trim(),
        imagePath: widget.imagePath,
        createdAt: DateTime.now(),
        comments: const [],
      );

      await _storage.add(spot);

      if (!mounted) return;

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сохранено на карте')),
      );
    } catch (e) {
      setState(() => _error = 'Не удалось сохранить: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chips = widget.labels.map((l) => Chip(label: Text(l.label))).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Результат')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(widget.imagePath),
                height: 240,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 12),
            if (chips.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(spacing: 8, runSpacing: 8, children: chips),
              ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                widget.fromGallery
                    ? 'Фото из галереи — укажите место вручную или используйте GPS:'
                    : 'Можно указать место вручную либо сохранить по GPS:',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickOnMap,
                    icon: const Icon(Icons.add_location_alt),
                    label: Text(
                      _pickedPoint == null
                          ? 'Выбрать место на карте'
                          : 'Выбрано: ${_pickedPoint!.latitude.toStringAsFixed(5)}, ${_pickedPoint!.longitude.toStringAsFixed(5)}',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _commentCtrl,
              decoration: const InputDecoration(
                labelText: 'Заметка к фото',
                border: OutlineInputBorder(),
              ),
              minLines: 1,
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.save),
                label: Text(_saving ? 'Сохраняем…' : 'Сохранить точку'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}