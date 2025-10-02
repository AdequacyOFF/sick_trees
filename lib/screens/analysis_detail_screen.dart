// lib/screens/analysis_detail_screen.dart
import 'package:flutter/material.dart';
import 'dart:io';
import '../services/analysis_storage_service.dart';
import '../models/analysis_results.dart';

class AnalysisDetailScreen extends StatelessWidget {
  final AnalysisItem analysis;

  const AnalysisDetailScreen({super.key, required this.analysis});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Детали анализа'),
      ),
      body: analysis.status == 'completed' && analysis.analysisResults != null
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
    final summary = results?['summary'] as AnalysisSummary?;

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

          // Сводная информация
          if (summary != null)
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Сводная информация:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Обнаружено деревьев: ${summary.instances}'),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 16),

          const Text(
            'Результаты анализа:',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          if (instances.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: Text('Нет обнаруженных деревьев')),
              ),
            ),

          ...instances.map((instance) => _buildInstanceCard(instance)),
        ],
      ),
    );
  }

  Widget _buildInstanceCard(Map<String, dynamic> instance) {
    final report = instance['report'] as TreeReport?;
    final overlayPath = instance['overlay'] as String?;
    final diseasePath = instance['disease'] as String?;
    final instanceName = instance['name'] as String? ?? 'Неизвестный объект';

    if (report == null) {
      return Card(
        margin: const EdgeInsets.only(bottom: 16),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Ошибка: нет данных анализа'),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок instance
            Text(
              instanceName.toUpperCase(),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Overlay изображение (обнаруженное дерево)
            if (overlayPath != null && File(overlayPath).existsSync())
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Обнаруженное дерево:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
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
                ],
              ),

            // Disease изображение (если есть)
            if (diseasePath != null && File(diseasePath).existsSync())
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Выделенные заболевания:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(diseasePath),
                      width: double.infinity,
                      height: 150,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),

            // Информация о виде дерева
            const Text(
              'Идентификация вида:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '${_formatSpeciesName(report.species)} (${(report.speciesScore * 100).toStringAsFixed(1)}%)',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),

            // Другие предположения
            if (report.topKSpecies.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Другие варианты:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: report.topKSpecies.map((species) => Chip(
                  label: Text('${_formatSpeciesName(species.label)}: ${(species.prob * 100).toStringAsFixed(1)}%'),
                  backgroundColor: Colors.grey[100],
                )).toList(),
              ),
            ],

            // Заболевания
            if (report.diseases.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Обнаруженные заболевания:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: report.diseases.map((disease) => Chip(
                  label: Text('${_formatDiseaseName(disease.name)}: ${(disease.score * 100).toStringAsFixed(1)}%'),
                  backgroundColor: _getDiseaseColor(disease.score),
                  labelStyle: TextStyle(
                    color: disease.score > 0.5 ? Colors.white : Colors.black,
                  ),
                )).toList(),
              ),
            ],

            // Дополнительная информация
            const SizedBox(height: 12),
            const Text(
              'Дополнительно:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                Chip(
                  label: Text('Уверенность: ${(report.score * 100).toStringAsFixed(1)}%'),
                  backgroundColor: Colors.blue[50],
                ),
                Chip(
                  label: Text('Угол наклона: ${report.leanAngle.toStringAsFixed(1)}°'),
                  backgroundColor: Colors.green[50],
                ),
                if (report.type.isNotEmpty)
                  Chip(
                    label: Text('Тип: ${report.type}'),
                    backgroundColor: Colors.orange[50],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Форматирование названия вида дерева (замена подчеркиваний на пробелы и капитализация)
  String _formatSpeciesName(String species) {
    return species.replaceAll('_', ' ').split(' ').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }

  // Форматирование названия заболевания
  String _formatDiseaseName(String disease) {
    return disease.split('_').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }

  // Цвет для отображения серьезности заболевания
  Color _getDiseaseColor(double score) {
    if (score > 0.7) return Colors.red[300]!;
    if (score > 0.4) return Colors.orange[300]!;
    return Colors.yellow[300]!;
  }
}