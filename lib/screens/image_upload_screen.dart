import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';

class ImageUploadScreen extends StatefulWidget {
  const ImageUploadScreen({super.key});
  @override
  _ImageUploadScreenState createState() => _ImageUploadScreenState();
}

class _ImageUploadScreenState extends State<ImageUploadScreen> {
  File? _selectedImage;
  bool _isLoading = false;
  double _uploadProgress = 0.0;
  double _downloadProgress = 0.0;
  File? _downloadedZip;
  CancelToken _cancelToken = CancelToken();

  final ImagePicker _picker = ImagePicker();
  final ApiServiceWithRetry _apiService = ApiServiceWithRetry();

  @override
  void dispose() {
    _cancelToken.cancel();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  Future<void> _uploadImage() async {
    if (_selectedImage == null) return;

    setState(() {
      _isLoading = true;
      _uploadProgress = 0.0;
      _downloadProgress = 0.0;
      _downloadedZip = null;
    });

    try {
      final zipFile = await _apiService.uploadImage(
        imageFile: _selectedImage!,
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

      setState(() {
        _downloadedZip = zipFile;
        _isLoading = false;
      });

      _showSuccessDialog();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorDialog(e.toString());
    }
  }

  void _cancelUpload() {
    _cancelToken.cancel('User cancelled');
    setState(() {
      _isLoading = false;
    });
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Успех!'),
        content: const Text('Анализ завершен. Файл сохранен.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ошибка'),
        content: Text('Произошла ошибка: $error'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
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
        actions: [
          if (_isLoading)
            IconButton(
              icon: const Icon(Icons.cancel),
              onPressed: _cancelUpload,
              tooltip: 'Отменить загрузку',
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Превью изображения
            if (_selectedImage != null)
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Image.file(_selectedImage!, fit: BoxFit.cover),
              )
            else
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(child: Text('Выберите изображение')),
              ),

            const SizedBox(height: 16),

            // Кнопка выбора изображения
            ElevatedButton(
              onPressed: _pickImage,
              child: const Text('Выбрать изображение'),
            ),

            const SizedBox(height: 16),

            // Кнопка отправки
            ElevatedButton(
              onPressed: _isLoading || _selectedImage == null ? null : _uploadImage,
              child: const Text('Начать анализ'),
            ),

            // Индикатор загрузки
            if (_isLoading) ...[
              const SizedBox(height: 16),
              Column(
                children: [
                  LinearProgressIndicator(value: _uploadProgress),
                  const SizedBox(height: 8),
                  Text('Отправка: ${(_uploadProgress * 100).toStringAsFixed(1)}%'),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(value: _downloadProgress),
                  const SizedBox(height: 8),
                  Text('Загрузка результата: ${(_downloadProgress * 100).toStringAsFixed(1)}%'),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: _cancelUpload,
                    child: const Text('Отменить'),
                  ),
                ],
              ),
            ],

            // Информация о загруженном файле
            if (_downloadedZip != null) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 48),
                      const SizedBox(height: 8),
                      const Text('Файл успешно сохранен:'),
                      Text(
                        _downloadedZip!.path.split('/').last,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}