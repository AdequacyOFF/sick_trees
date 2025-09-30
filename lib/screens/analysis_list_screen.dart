import 'package:flutter/material.dart';
import 'dart:io';
import '../services/analysis_storage_service.dart';
import 'analysis_detail_screen.dart';
import 'package:yandex_maps_mapkit/mapkit.dart' as ymk;

class AnalysisListScreen extends StatefulWidget {
  const AnalysisListScreen({super.key});

  @override
  State<AnalysisListScreen> createState() => _AnalysisListScreenState();
}

class _AnalysisListScreenState extends State<AnalysisListScreen> {
  final _analysisStorage = AnalysisStorageService();
  List<AnalysisItem> _analyses = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAnalyses();
  }

  Future<void> _loadAnalyses() async {
    setState(() => _loading = true);
    _analyses = await _analysisStorage.getAnalyses();
    setState(() => _loading = false);
  }

  void _showOnMap(AnalysisItem analysis) {
    // Переходим на карту и передаем координаты для выделения
    Navigator.of(context).pushNamed(
      '/map',
      arguments: {
        'highlightSpot': ymk.Point(latitude: analysis.lat, longitude: analysis.lng),
        'spotId': analysis.id,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_analyses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.analytics, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'Нет анализов',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text('Сделайте фото и отправьте на анализ'),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAnalyses,
      child: ListView.builder(
        itemCount: _analyses.length,
        itemBuilder: (context, index) {
          final analysis = _analyses[index];
          return _AnalysisListItem(
            analysis: analysis,
            onTap: () => _openAnalysisDetail(analysis),
            onDelete: () => _deleteAnalysis(analysis.id),
            onShowOnMap: analysis.status == 'completed'
                ? () => _showOnMap(analysis)
                : null,
          );
        },
      ),
    );
  }

  void _openAnalysisDetail(AnalysisItem analysis) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AnalysisDetailScreen(analysis: analysis),
    )).then((_) => _loadAnalyses());
  }

  Future<void> _deleteAnalysis(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить анализ?'),
        content: const Text('Это действие нельзя отменить.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _analysisStorage.deleteAnalysis(id);
      await _loadAnalyses();
    }
  }
}

class _AnalysisListItem extends StatelessWidget {
  final AnalysisItem analysis;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback? onShowOnMap;

  const _AnalysisListItem({
    required this.analysis,
    required this.onTap,
    required this.onDelete,
    this.onShowOnMap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: _buildImagePreview(),
        title: Text(
          'Анализ от ${_formatDate(analysis.createdAt)}',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Координаты: ${analysis.lat.toStringAsFixed(4)}, ${analysis.lng.toStringAsFixed(4)}'),
            const SizedBox(height: 4),
            _buildStatus(),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onShowOnMap != null && analysis.status == 'completed')
              IconButton(
                icon: const Icon(Icons.map, color: Colors.blue),
                onPressed: onShowOnMap,
                tooltip: 'Показать на карте',
              ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: onDelete,
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildImagePreview() {
    if (analysis.imagePath != null && File(analysis.imagePath!).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(analysis.imagePath!),
          width: 50,
          height: 50,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: 50,
              height: 50,
              color: Colors.grey[300],
              child: const Icon(Icons.photo),
            );
          },
        ),
      );
    } else {
      return Container(
        width: 50,
        height: 50,
        color: Colors.grey[300],
        child: const Icon(Icons.photo),
      );
    }
  }

  Widget _buildStatus() {
    final status = analysis.status;
    final color = status == 'completed'
        ? Colors.green
        : status == 'error'
        ? Colors.red
        : Colors.orange;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          status == 'completed' ? 'Готово'
              : status == 'error' ? 'Ошибка'
              : 'Обрабатывается',
          style: TextStyle(color: color),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}