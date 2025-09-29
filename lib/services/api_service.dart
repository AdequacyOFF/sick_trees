import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

class ApiServiceWithRetry {
  static const String baseUrl = 'https://5qxami8c28yc.share.zrok.io/api/task';
  static const int maxRetries = 3;

  late Dio _dio;
  CancelToken _cancelToken = CancelToken();

  ApiServiceWithRetry() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
    ));

    // Добавляем интерцептор для повторных попыток
    _dio.interceptors.add(RetryInterceptor(
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

      return await _saveZipFile(response);
    } on DioException catch (e) {
      _handleDioError(e);
      rethrow;
    }
  }

  Future<File> _saveZipFile(Response response) async {
    final directory = await getApplicationDocumentsDirectory();
    final fileName = _getZipFileName(response) ?? 'analysis_${DateTime.now().millisecondsSinceEpoch}.zip';
    final filePath = '${directory.path}/$fileName';
    final File zipFile = File(filePath);

    await zipFile.writeAsBytes(response.data);
    return zipFile;
  }

  void _handleDioError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout) {
      throw Exception('Connection timeout. Please check your internet connection.');
    } else if (e.type == DioExceptionType.receiveTimeout) {
      throw Exception('Server is taking too long to respond.');
    } else if (e.type == DioExceptionType.badResponse) {
      throw Exception('Server error: ${e.response?.statusCode}');
    } else if (e.type == DioExceptionType.cancel) {
      throw Exception('Request was cancelled');
    } else {
      throw Exception('Network error: ${e.message}');
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
    _cancelToken = CancelToken(); // Создаем новый токен для следующего запроса
  }
}

// Интерцептор для повторных попыток
class RetryInterceptor extends Interceptor {
  final Dio dio;
  final int retries;

  RetryInterceptor({required this.dio, required this.retries});

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    if (_shouldRetry(err)) {
      if (err.requestOptions.extra['retry_count'] == null) {
        err.requestOptions.extra['retry_count'] = 0;
      }

      int retryCount = err.requestOptions.extra['retry_count'];
      if (retryCount < retries) {
        err.requestOptions.extra['retry_count'] = retryCount + 1;

        await Future.delayed(const Duration(seconds: 1));

        try {
          final response = await dio.fetch(err.requestOptions);
          handler.resolve(response);
          return;
        } catch (e) {
          handler.reject(err);
        }
      }
    }
    handler.reject(err);
  }

  bool _shouldRetry(DioException err) {
    return err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.unknown;
  }
}