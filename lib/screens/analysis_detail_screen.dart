import 'package:flutter/material.dart';
import 'dart:io';
import '../services/analysis_storage_service.dart';

class AnalysisDetailScreen extends StatelessWidget {
  final AnalysisItem analysis;

  const AnalysisDetailScreen({super.key, required this.analysis});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Детали анализа'),
      ),
      body: analysis.status == 'completed'
          ? _buildCompletedAnalysis()
          : _buildProcessingAnalysis(),
    );
  }

  Widget _buildProcessingAnalysis() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 100,
            height: 100,
            child: CircularProgressIndicator(
              strokeWidth: 8,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green[700]!),
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Идет анализ...',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Text('Пожалуйста, подождите'),
        ],
      ),
    );
  }

  Widget _buildCompletedAnalysis() {
    final results = analysis.analysisResults;
    final instances = results?['instances'] as List<dynamic>? ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Исходное изображение
          if (analysis.imagePath != null && File(analysis.imagePath!).existsSync())
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Исходное изображение:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(analysis.imagePath!),
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),

          // BBOX изображение (только одно)
          if (results?['bboxImage'] != null && File(results!['bboxImage']).existsSync())
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Область обнаружения:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(results['bboxImage']),
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),

          // Результаты анализа по instance
          const Text(
            'Результаты анализа:',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          if (instances.isEmpty)
            const Text('Нет данных для отображения'),

          ...instances.map((instance) => _buildInstanceCard(instance)),
        ],
      ),
    );
  }

  Widget _buildInstanceCard(Map<String, dynamic> instance) {
    final report = instance['report'] as Map<String, dynamic>? ?? {};
    final overlayPath = instance['overlay'] as String?;
    final instanceName = instance['name'] as String? ?? '';

    // Создаем список виджетов для Column
    final List<Widget> columnChildren = [
      Text(
        instanceName.toUpperCase(),
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 12),
    ];

    // Добавляем overlay изображение если есть
    if (overlayPath != null && File(overlayPath).existsSync()) {
      columnChildren.addAll([
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            File(overlayPath),
            width: double.infinity,
            height: 150,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 12),
      ]);
    }

    // Добавляем теги из report.json
    if (report.isNotEmpty) {
      columnChildren.addAll([
        const Text(
          'Параметры:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            if (report['type'] != null)
              Chip(
                label: Text('Тип: ${report['type']}'),
                backgroundColor: Colors.blue[50],
              ),
            if (report['lean_angle'] != null)
              Chip(
                label: Text('Угол: ${report['lean_angle']}°'),
                backgroundColor: Colors.green[50],
              ),
            if (report['species'] != null)
              Chip(
                label: Text('Класс: ${report['species']}'),
                backgroundColor: Colors.orange[50],
              ),
            if (report['height'] != null)
              Chip(
                label: Text('Высота: ${report['height']}м'),
                backgroundColor: Colors.purple[50],
              ),
            if (report['diameter'] != null)
              Chip(
                label: Text('Диаметр: ${report['diameter']}см'),
                backgroundColor: Colors.red[50],
              ),
          ],
        ),
      ]);
    } else {
      columnChildren.add(const Text('Нет данных анализа'));
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: columnChildren,
        ),
      ),
    );
  }
}