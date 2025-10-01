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
  String _status = '';

  @override
  void initState() {
    super.initState();
    _startUpload();
  }

  @override
  void dispose() {
    _apiService.cancel();
    super.dispose();
  }

  Future<void> _startUpload() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _status = 'Подготовка...';
    });

    try {
      setState(() => _status = 'Отправка фото на сервер...');

      final zipFile = await _apiService.uploadImage(
        imageFile: widget.imageFile,
        onSendProgress: (sent, total) {
          final progress = (sent / total * 100).toInt();
          if (mounted) {
            setState(() => _status = 'Отправка: $progress%');
          }
        },
        onReceiveProgress: (received, total) {
          final progress = (received / total * 100).toInt();
          if (mounted) {
            setState(() => _status = 'Получение результатов: $progress%');
          }
        },
      );

      if (zipFile == null) {
        throw Exception('Не удалось отправить фото на сервер');
      }
      if (!mounted) return;
      setState(() => _status = 'Обработка результатов...');

      final results = await _zipService.extractAndAnalyze(zipFile);

      await _analysisStorage.updateAnalysisStatus(
        widget.analysisId,
        'completed',
        zipPath: zipFile.path,
        results: results,
      );

      if (!mounted) return;

      _showSuccessAndReturn();

    } catch (e) {

      if (mounted) {
        setState(() => _status = 'Ошибка: ${e.toString()}');

        await _analysisStorage.updateAnalysisStatus(widget.analysisId, 'error');

        _showErrorAndOption(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSuccessAndReturn() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Анализ успешно завершен!'),
        backgroundColor: Colors.green,
      ),
    );

    // Возвращаемся через секунду, чтобы пользователь увидел сообщение
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  void _showErrorAndOption(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ошибка отправки'),
        content: Text('Не удалось отправить фото: $error'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _startUpload();
            },
            child: const Text('Повторить'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Анализ изображения'),
        leading: _isLoading
            ? null
            : IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Превью изображения
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  image: DecorationImage(
                    image: FileImage(widget.imageFile),
                    fit: BoxFit.cover,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Индикатор загрузки
              if (_isLoading) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
              ] else if (_status.contains('Ошибка')) ...[
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
              ],

              // Статус
              Text(
                _status,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),

              const SizedBox(height: 32),

              // Кнопка отмены/повтора
              if (_isLoading)
                OutlinedButton(
                  onPressed: () {
                    _apiService.cancel();
                    Navigator.pop(context);
                  },
                  child: const Text('Отменить'),
                )
              else if (_status.contains('Ошибка'))
                ElevatedButton(
                  onPressed: _startUpload,
                  child: const Text('Повторить отправку'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}