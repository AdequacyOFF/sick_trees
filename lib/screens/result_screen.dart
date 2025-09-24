import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import '../models/tree_spot.dart';
import '../services/storage_service.dart';

class ResultScreen extends StatefulWidget {
  final String imagePath;
  final List<LabelResult> labels;
  const ResultScreen({super.key, required this.imagePath, required this.labels});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  final _commentCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    setState(() { _saving = true; _error = null; });
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      final pos = await Geolocator.getCurrentPosition();
      final spot = TreeSpot(
        id: const Uuid().v4(),
        lat: pos.latitude,
        lng: pos.longitude,
        labels: widget.labels,
        comment: _commentCtrl.text.isEmpty ? null : _commentCtrl.text,
        imagePath: widget.imagePath,
      );
      await StorageService().load();
      await StorageService().add(spot);
      if (!mounted) return;
      Navigator.pop(context); // close
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Сохранено на карте')));
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Результат')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(File(widget.imagePath), height: 240, fit: BoxFit.cover),
            ),
            const SizedBox(height: 12),
            const Text('Найденные метки:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: widget.labels
                  .map((l) => Chip(label: Text('${l.label} (${(l.confidence*100).toStringAsFixed(0)}%)')))
                  .toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _commentCtrl,
              decoration: const InputDecoration(
                labelText: 'Комментарий',
                border: OutlineInputBorder(),
              ),
              minLines: 1, maxLines: 3,
            ),
            const SizedBox(height: 12),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save),
              label: _saving ? const Text('Сохраняем...') : const Text('Сохранить точку'),
            ),
          ],
        ),
      ),
    );
  }
}