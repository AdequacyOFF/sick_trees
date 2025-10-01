import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class AnalysisItem {
  final String id;
  final String imagePath;
  final double lat;
  final double lng;
  final DateTime createdAt;
  final String status; // 'processing', 'completed', 'error'
  final String? zipPath;
  final Map<String, dynamic>? analysisResults;

  AnalysisItem({
    required this.id,
    required this.imagePath,
    required this.lat,
    required this.lng,
    required this.createdAt,
    this.status = 'processing',
    this.zipPath,
    this.analysisResults,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'imagePath': imagePath,
    'lat': lat,
    'lng': lng,
    'createdAt': createdAt.toIso8601String(),
    'status': status,
    'zipPath': zipPath,
    'analysisResults': analysisResults,
  };

  factory AnalysisItem.fromJson(Map<String, dynamic> json) => AnalysisItem(
    id: json['id'] as String,
    imagePath: json['imagePath'] as String,
    lat: (json['lat'] as num).toDouble(),
    lng: (json['lng'] as num).toDouble(),
    createdAt: DateTime.parse(json['createdAt'] as String),
    status: json['status'] as String? ?? 'processing',
    zipPath: json['zipPath'] as String?,
    analysisResults: json['analysisResults'] as Map<String, dynamic>?,
  );
}

class AnalysisStorageService {
  static final AnalysisStorageService _instance = AnalysisStorageService._internal();
  factory AnalysisStorageService() => _instance;
  AnalysisStorageService._internal();

  final _uuid = const Uuid();
  final List<AnalysisItem> _analyses = [];
  bool _loaded = false;

  Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/analyses.json');
  }

  Future<void> load() async {
    if (_loaded) return;
    final file = await _getFile();
    if (await file.exists()) {
      final raw = await file.readAsString();
      if (raw.trim().isNotEmpty) {
        final list = (jsonDecode(raw) as List<dynamic>);
        _analyses.clear();
        _analyses.addAll(list.map((e) => AnalysisItem.fromJson(e as Map<String, dynamic>)));
      }
    }
    _loaded = true;
  }

  Future<void> _save() async {
    final file = await _getFile();
    final raw = jsonEncode(_analyses.map((e) => e.toJson()).toList());
    await file.writeAsString(raw);
  }

  Future<String> createAnalysis({
    required String imagePath,
    required double lat,
    required double lng,
  }) async {
    await load();
    final id = _uuid.v4();
    final analysis = AnalysisItem(
      id: id,
      imagePath: imagePath,
      lat: lat,
      lng: lng,
      createdAt: DateTime.now(),
      status: 'processing',
    );
    _analyses.insert(0, analysis); // Новые сверху
    await _save();
    return id;
  }

  Future<void> updateAnalysisStatus(String id, String status, {String? zipPath, Map<String, dynamic>? results}) async {
    await load();
    final index = _analyses.indexWhere((a) => a.id == id);
    if (index != -1) {
      final old = _analyses[index];
      _analyses[index] = AnalysisItem(
        id: old.id,
        imagePath: old.imagePath,
        lat: old.lat,
        lng: old.lng,
        createdAt: old.createdAt,
        status: status,
        zipPath: zipPath ?? old.zipPath,
        analysisResults: results ?? old.analysisResults,
      );
      await _save();
    }
  }

  Future<void> deleteAnalysis(String id) async {
    await load();
    _analyses.removeWhere((a) => a.id == id);
    await _save();
  }

  Future<List<AnalysisItem>> getAnalyses() async {
    await load();
    return List.unmodifiable(_analyses);
  }

  AnalysisItem? getAnalysis(String id) {
    return _analyses.firstWhere((a) => a.id == id);
  }
}