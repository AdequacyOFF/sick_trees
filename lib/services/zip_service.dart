// lib/services/zip_service.dart
import 'dart:io';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import '../models/analysis_results.dart';

class ZipService {
  Future<Map<String, dynamic>> extractAndAnalyze(File zipFile) async {
    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    final tempDir = await getTemporaryDirectory();
    final extractDir = Directory('${tempDir.path}/analysis_${DateTime.now().millisecondsSinceEpoch}');
    await extractDir.create(recursive: true);

    final results = <String, dynamic>{};
    final instances = <Map<String, dynamic>>[];

    // Извлекаем все файлы
    for (final file in archive) {
      final filename = file.name;

      // Пропускаем директории
      if (file.isFile) {
        final localPath = '${extractDir.path}/$filename';
        final localFile = File(localPath);

        await localFile.create(recursive: true);
        await localFile.writeAsBytes(file.content);
      }
    }

    // Парсим summary.json
    final summaryFile = File('${extractDir.path}/detections/summary.json');
    if (await summaryFile.exists()) {
      try {
        final summaryContent = await summaryFile.readAsString();
        final summaryJson = jsonDecode(summaryContent);
        results['summary'] = AnalysisSummary.fromJson(summaryJson);
        print('Found summary: ${summaryJson['instances']} instances');
      } catch (e) {
        print('Error parsing summary.json: $e');
      }
    } else {
      print('summary.json not found at ${summaryFile.path}');
    }

    // Обрабатываем каждую instance папку
    final detectionsDir = Directory('${extractDir.path}/detections');
    if (await detectionsDir.exists()) {
      final entities = await detectionsDir.list().toList();

      for (final entity in entities) {
        if (entity is Directory && entity.path.contains('instance_')) {
          final instanceData = await _parseInstance(entity);
          if (instanceData != null) {
            instances.add(instanceData);
          }
        }
      }
    } else {
      print('detections directory not found at ${detectionsDir.path}');

      // Альтернативный подход: ищем instance папки в корне
      final entities = await extractDir.list().toList();
      for (final entity in entities) {
        if (entity is Directory && entity.path.contains('instance_')) {
          final instanceData = await _parseInstance(entity);
          if (instanceData != null) {
            instances.add(instanceData);
          }
        }
      }
    }

    results['instances'] = instances;
    results['extractPath'] = extractDir.path;

    print('Extracted ${instances.length} instances from archive');
    return results;
  }

  Future<Map<String, dynamic>?> _parseInstance(Directory instanceDir) async {
    final instanceName = instanceDir.path.split('/').last;
    final instanceData = <String, dynamic>{
      'name': instanceName,
      'path': instanceDir.path,
    };

    try {
      final files = await instanceDir.list().toList();

      for (final file in files) {
        if (file is File) {
          final filename = file.uri.pathSegments.last;

          if (filename == 'overlay.png') {
            instanceData['overlay'] = file.path;
            print('Found overlay for $instanceName: ${file.path}');
          } else if (filename == 'disease.png') {
            instanceData['disease'] = file.path;
            print('Found disease image for $instanceName: ${file.path}');
          } else if (filename == 'report.json') {
            try {
              final content = await file.readAsString();
              final reportJson = jsonDecode(content);
              instanceData['report'] = TreeReport.fromJson(reportJson);
              print('Parsed report for $instanceName: ${reportJson['species']}');
            } catch (e) {
              print('Error parsing report.json for $instanceName: $e');
            }
          }
        }
      }

      // Проверяем, что есть обязательные данные
      if (instanceData.containsKey('report') && instanceData.containsKey('overlay')) {
        return instanceData;
      } else {
        print('Missing required data for $instanceName. Has report: ${instanceData.containsKey('report')}, Has overlay: ${instanceData.containsKey('overlay')}');
      }
    } catch (e) {
      print('Error processing instance $instanceName: $e');
    }

    return null;
  }

  // Вспомогательный метод для отладки - показывает структуру архива
  Future<void> debugArchiveStructure(File zipFile) async {
    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    print('=== Archive Structure ===');
    for (final file in archive) {
      print('${file.isFile ? 'FILE' : 'DIR '}: ${file.name} (${file.size} bytes)');
    }
    print('=========================');
  }
}