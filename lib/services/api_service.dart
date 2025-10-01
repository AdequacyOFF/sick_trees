import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

class ApiServiceWithRetry {
  static const String baseUrl = 'http://10.0.2.2:1234/api/task';
  static const int maxRetries = 3;

  late Dio _dio;
  CancelToken _cancelToken = CancelToken();

  ApiServiceWithRetry() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
    ));

    // Добавляем исправленный интерцептор для повторных попыток
    _dio.interceptors.add(RetryInterceptorOnError(
      dio: _dio,
      retries: maxRetries,
    ));
  }

  Future<File?> uploadImage({
    required File imageFile,
    required Function(int sent, int total) onSendProgress,
    required Function(int received, int total) onReceiveProgress,
    CancelToken? cancelToken,
  }) async {
    try {
      // Проверяем размер файла
      final fileLength = await imageFile.length();
      if (fileLength == 0) {
        throw Exception('Файл пустой');
      }

      print('Starting upload: ${imageFile.path}');
      print('File size: $fileLength bytes');

      FormData formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          imageFile.path,
          filename: _getFileName(imageFile.path),
        ),
      });

      Response response = await _dio.post(
        '/generate',
        data: formData,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
        cancelToken: cancelToken ?? _cancelToken,
        options: Options(
          responseType: ResponseType.bytes,
          headers: {'Content-Type': 'multipart/form-data'},
        ),
      );

      // Проверяем ответ
      if (response.statusCode != 200) {
        throw Exception('Server error: ${response.statusCode}');
      }

      if (response.data == null || (response.data as List<int>).isEmpty) {
        throw Exception('Empty response from server');
      }

      print('Upload successful, saving ZIP file...');
      return await _saveZipFile(response);

    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        print('Request cancelled by user');
        return null;
      }
      print('Dio error: ${e.type} - ${e.message}');
      _handleDioError(e);
      rethrow;
    } catch (e) {
      print('Upload error: $e');
      rethrow;
    }
  }

  Future<File> _saveZipFile(Response response) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = _getZipFileName(response) ?? 'analysis_${DateTime.now().millisecondsSinceEpoch}.zip';
      final filePath = '${directory.path}/$fileName';
      final File zipFile = File(filePath);

      final data = response.data as List<int>;
      print('Saving ZIP file: $filePath, size: ${data.length} bytes');

      await zipFile.writeAsBytes(data);

      // Проверяем, что файл сохранился
      if (await zipFile.exists()) {
        final savedSize = await zipFile.length();
        print('ZIP file saved successfully: $savedSize bytes');
        return zipFile;
      } else {
        throw Exception('Failed to save ZIP file');
      }
    } catch (e) {
      print('Error saving ZIP file: $e');
      rethrow;
    }
  }

  void _handleDioError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout) {
      throw Exception('Connection timeout. Please check your internet connection.');
    } else if (e.type == DioExceptionType.receiveTimeout) {
      throw Exception('Server is taking too long to respond.');
    } else if (e.type == DioExceptionType.badResponse) {
      throw Exception('Server error: ${e.response?.statusCode} - ${e.response?.statusMessage}');
    } else if (e.type == DioExceptionType.cancel) {
      throw Exception('Request was cancelled');
    } else if (e.type == DioExceptionType.unknown) {
      throw Exception('Network error: ${e.message}');
    } else {
      throw Exception('Unknown error: ${e.message}');
    }
  }

  String _getFileName(String path) => path.split('/').last;

  String? _getZipFileName(Response response) {
    try {
      final contentDisposition = response.headers['content-disposition']?.first;
      if (contentDisposition != null) {
        final matches = RegExp(r'filename="([^"]+)"').firstMatch(contentDisposition);
        return matches?.group(1);
      }
    } catch (e) {
      print('Error parsing filename: $e');
    }
    return null;
  }

  void cancel() {
    if (!_cancelToken.isCancelled) {
      _cancelToken.cancel('User cancelled');
    }
  }
}

// ИСПРАВЛЕННЫЙ интерцептор для повторных попыток
class RetryInterceptorOnError extends Interceptor {
  final Dio dio;
  final int retries;

  RetryInterceptorOnError({required this.dio, required this.retries});

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    // Проверяем, нужно ли повторять запрос
    if (_shouldRetry(err) && _getRetryCount(err) < retries) {
      final retryCount = _getRetryCount(err);
      print('Retrying request (attempt ${retryCount + 1}/$retries)...');

      await Future.delayed(const Duration(seconds: 1));

      try {
        // Создаем новую копию RequestOptions для повторной попытки
        final options = Options(
          method: err.requestOptions.method,
          headers: err.requestOptions.headers,
          responseType: err.requestOptions.responseType,
        );

        final response = await dio.request(
          err.requestOptions.path,
          data: err.requestOptions.data,
          queryParameters: err.requestOptions.queryParameters,
          options: options,
          cancelToken: err.requestOptions.cancelToken,
          onSendProgress: err.requestOptions.onSendProgress,
          onReceiveProgress: err.requestOptions.onReceiveProgress,
        );

        handler.resolve(response);
        return;
      } catch (e) {
        // Увеличиваем счетчик повторных попыток
        err.requestOptions.extra['retry_count'] = retryCount + 1;

        // Если это последняя попытка, передаем ошибку дальше
        if (_getRetryCount(err) >= retries) {
          handler.next(err);
        } else {
          // Продолжаем цепочку обработки ошибок для следующей попытки
          handler.next(err);
        }
        return;
      }
    }

    // Если повторять не нужно, передаем ошибку дальше
    handler.next(err);
  }

  bool _shouldRetry(DioException err) {
    return err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.unknown;
  }

  int _getRetryCount(DioException err) {
    return (err.requestOptions.extra['retry_count'] as int?) ?? 0;
  }
}