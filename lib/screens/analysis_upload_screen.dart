import 'package:flutter/material.dart';
import 'dart:io';
import '../services/api_service.dart';
import '../services/analysis_storage_service.dart';
import '../services/zip_service.dart';

class AnalysisUploadScreen extends StatefulWidget {
  final String analysisId;
  final File imageFile;

  const AnalysisUploadScreen({
    super.key,
    required this.analysisId,
    required this.imageFile,
  });

  @override
  State<AnalysisUploadScreen> createState() => _AnalysisUploadScreenState();
}

class _AnalysisUploadScreenState extends State<AnalysisUploadScreen> {
  final _apiService = ApiServiceWithRetry();
  final _analysisStorage = AnalysisStorageService();
  final _zipService = ZipService();

  bool _isLoading = false;
  double _uploadProgress = 0.0;
  double _downloadProgress = 0.0;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _startUpload();
  }

  Future<void> _startUpload() async {
    setState(() {
      _isLoading = true;
      _status = 'Подготовка к загрузке...';
    });

    try {
      _status = 'Отправка изображения на сервер...';

      final zipFile = await _apiService.uploadImage(
        imageFile: widget.imageFile,
        onSendProgress: (sent, total) {
          setState(() {
            _uploadProgress = sent / total;
          });
        },
        onReceiveProgress: (received, total) {
          setState(() {
            _downloadProgress = received / total;
          });
        },
      );

      // Проверяем, что zipFile не null
      if (zipFile == null) {
        throw Exception('Не удалось получить файл с сервера');
      }

      _status = 'Обработка результатов...';

      // Разархивируем и анализируем результаты
      final results = await _zipService.extractAndAnalyze(zipFile);

      // Сохраняем результаты
      await _analysisStorage.updateAnalysisStatus(
        widget.analysisId,
        'completed',
        zipPath: zipFile.path,
        results: results,
      );

      _status = 'Анализ завершен!';

      if (!mounted) return;

      // Показываем успех и возвращаемся
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Анализ успешно завершен')),
      );

      Navigator.of(context).pop();

    } catch (e) {
      _status = 'Ошибка: $e';
      await _analysisStorage.updateAnalysisStatus(widget.analysisId, 'error');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка анализа: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Анализ изображения'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _isLoading ? null : () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Превью изображения
            Container(
              height: 150,
              width: 150,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Image.file(widget.imageFile, fit: BoxFit.cover),
            ),

            const SizedBox(height: 32),

            // Индикатор загрузки
            if (_isLoading) ...[
              CircularProgressIndicator(
                value: _uploadProgress > 0 ? _uploadProgress : null,
              ),
              const SizedBox(height: 16),
              Text('Отправка: ${(_uploadProgress * 100).toStringAsFixed(1)}%'),

              if (_downloadProgress > 0) ...[
                const SizedBox(height: 16),
                LinearProgressIndicator(value: _downloadProgress),
                Text('Загрузка результата: ${(_downloadProgress * 100).toStringAsFixed(1)}%'),
              ],
            ],

            const SizedBox(height: 16),

            // Статус
            Text(
              _status,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),

            const SizedBox(height: 32),

            // Кнопка отмены
            if (_isLoading)
              OutlinedButton(
                onPressed: () {
                  _apiService.cancel();
                  Navigator.pop(context);
                },
                child: const Text('Отменить'),
              ),
          ],
        ),
      ),
    );
  }
}