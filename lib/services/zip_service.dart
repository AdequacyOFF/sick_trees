import 'dart:io';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';

class ZipService {
  Future<Map<String, dynamic>> extractAndAnalyze(File zipFile) async {
    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    final tempDir = await getTemporaryDirectory();
    final extractDir = Directory('${tempDir.path}/analysis_${DateTime.now().millisecondsSinceEpoch}');
    await extractDir.create(recursive: true);

    final results = <String, dynamic>{};
    final instances = <Map<String, dynamic>>[];

    for (final file in archive) {
      final filename = file.name;

      if (filename.startsWith('out/') && file.isFile) {
        final localPath = '${extractDir.path}/$filename';
        final localFile = File(localPath);
        await localFile.create(recursive: true);
        await localFile.writeAsBytes(file.content);

        // Анализируем structure instance папок
        if (filename.contains('instance_')) {
          final instanceData = await _parseInstance(extractDir.path, filename);
          if (instanceData != null) {
            instances.add(instanceData);
          }
        }

        // Ищем bbox изображение (только один раз)
        if (filename.contains('bbox') && !results.containsKey('bboxImage')) {
          results['bboxImage'] = localPath;
        }

        // Ищем overlay изображения
        if (filename.contains('overlay')) {
          final instanceNum = _extractInstanceNumber(filename);
          if (instanceNum != null) {
            results['overlay_$instanceNum'] = localPath;
          }
        }

        // Парсим report.json
        if (filename.endsWith('report.json')) {
          final reportData = await _parseReport(localPath);
          final instanceNum = _extractInstanceNumber(filename);
          if (instanceNum != null && reportData != null) {
            results['report_$instanceNum'] = reportData;
          }
        }
      }
    }

    results['instances'] = instances;
    results['extractPath'] = extractDir.path;

    return results;
  }

  Future<Map<String, dynamic>?> _parseInstance(String basePath, String filename) async {
    final parts = filename.split('/');
    if (parts.length < 2) return null;

    final instanceDir = parts[1]; // instance_00, instance_01, etc.
    final instancePath = '$basePath/${parts.sublist(0, 2).join('/')}';

    final instanceData = <String, dynamic>{
      'name': instanceDir,
      'path': instancePath,
    };

    // Ищем файлы в instance папке
    final instanceDirFile = Directory(instancePath);
    if (await instanceDirFile.exists()) {
      final files = await instanceDirFile.list().toList();

      for (final file in files) {
        if (file is File) {
          final name = file.uri.pathSegments.last;
          if (name.contains('bbox')) {
            instanceData['bbox'] = file.path;
          } else if (name.contains('overlay')) {
            instanceData['overlay'] = file.path;
          } else if (name.endsWith('report.json')) {
            instanceData['report'] = await _parseReport(file.path);
          }
        }
      }
    }

    return instanceData;
  }

  Future<Map<String, dynamic>?> _parseReport(String reportPath) async {
    try {
      final file = File(reportPath);
      if (await file.exists()) {
        final content = await file.readAsString();
        return jsonDecode(content);
      }
    } catch (e) {
      print('Error parsing report: $e');
    }
    return null;
  }

  int? _extractInstanceNumber(String filename) {
    final regex = RegExp(r'instance_(\d+)');
    final match = regex.firstMatch(filename);
    return match != null ? int.tryParse(match.group(1)!) : null;
  }
}