// lib/services/api_service.dart
import 'dart:developer';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'settings_service.dart';

class ApiServiceWithRetry {
  late String baseUrl;
  static const int maxRetries = 3;

  late Dio _dio;
  CancelToken _cancelToken = CancelToken();
  final SettingsService _settingsService;

  ApiServiceWithRetry() : _settingsService = SettingsService() {
    _updateDio();
  }

  void _updateDio() {
    baseUrl = _settingsService.baseUrl;

    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
    ));

    _dio.interceptors.add(LogInterceptor(
      request: true,
      requestHeader: true,
      requestBody: false,
      responseHeader: true,
      responseBody: false,
      logPrint: (object) => log(object.toString()),
    ));

    _dio.interceptors.add(RetryInterceptorOnError(
      dio: _dio,
      retries: maxRetries,
    ));
  }

  Future<File?> uploadImage({
    required File imageFile,
    required Function(int sent, int total) onSendProgress,
    required Function(int received, int rTotal) onReceiveProgress,
    CancelToken? cancelToken,
  }) async {
    _updateDio(); // Обновляем настройки перед каждым запросом

    try {
      final fileLength = await imageFile.length();
      if (fileLength == 0) {
        throw Exception('Файл пустой');
      }
      log('Uploading image: ${imageFile.path}, size: $fileLength bytes');

      FormData formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(
          imageFile.path,
          filename: _getFileName(imageFile.path),
        ),
      });

      // Используем настройки из SettingsService
      final topK = _settingsService.topK;
      final diseaseScore = _settingsService.diseaseScore;

      log('Sending request with params: top_k=$topK, disease_score=$diseaseScore');

      Response response = await _dio.post(
        '/detect?top_k=$topK&disease_score=$diseaseScore',
        data: formData,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
        cancelToken: cancelToken ?? _cancelToken,
        options: Options(
          responseType: ResponseType.bytes,
        ),
      );

      if (response.statusCode != 200) {
        throw Exception('Server error: ${response.statusCode}');
      }

      if (response.data == null || (response.data as List<int>).isEmpty) {
        throw Exception('Empty response from server');
      }

      return await _saveZipFile(response);

    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        return null;
      }
      _handleDioError(e);
      rethrow;
    } catch (e) {
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

      await zipFile.writeAsBytes(data);

      if (await zipFile.exists()) {
        final savedSize = await zipFile.length();
        log('ZIP file saved: $filePath, size: $savedSize bytes');
        return zipFile;
      } else {
        throw Exception('Failed to save ZIP file');
      }
    } catch (e) {
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
      log('Error parsing zip filename: $e');
    }
    return null;
  }

  void cancel() {
    if (!_cancelToken.isCancelled) {
      _cancelToken.cancel('User cancelled');
    }
    // Создаем новый CancelToken для следующих запросов
    _cancelToken = CancelToken();
  }
}

class RetryInterceptorOnError extends Interceptor {
  final Dio dio;
  final int retries;

  RetryInterceptorOnError({required this.dio, required this.retries});

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    if (_shouldRetry(err) && _getRetryCount(err) < retries) {
      final retryCount = _getRetryCount(err);

      await Future.delayed(const Duration(seconds: 1));

      try {
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
        err.requestOptions.extra['retry_count'] = retryCount + 1;

        if (_getRetryCount(err) >= retries) {
          handler.next(err);
        } else {
          handler.next(err);
        }
        return;
      }
    }
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