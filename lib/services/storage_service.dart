import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/tree_spot.dart';
import '../models/comment.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  final _uuid = const Uuid();

  List<TreeSpot> _spots = [];
  bool _loaded = false;

  Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/spots.json');
  }

  Future<void> load() async {
    if (_loaded) return;
    final file = await _getFile();
    if (await file.exists()) {
      final raw = await file.readAsString();
      if (raw.trim().isNotEmpty) {
        final list = (jsonDecode(raw) as List<dynamic>);
        _spots = list
            .map((e) => TreeSpot.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } else {
      _spots = [];
    }
    _loaded = true;
  }

  Future<void> _save() async {
    final file = await _getFile();
    final raw = jsonEncode(_spots.map((e) => e.toJson()).toList());
    await file.writeAsString(raw);
  }

  List<TreeSpot> get spots => List.unmodifiable(_spots);

  Future<void> add(TreeSpot spot) async {
    await load();
    _spots.add(spot);
    await _save();
  }

  Future<void> update(TreeSpot spot) async {
    await load();
    _spots = _spots.map((s) => s.id == spot.id ? spot : s).toList();
    await _save();
  }

  Future<void> remove(String spotId) async {
    await load();
    _spots.removeWhere((s) => s.id == spotId);
    await _save();
  }

  Future<void> clear() async {
    await load();
    _spots.clear();
    await _save();
  }

  Future<void> addComment({
    required String spotId,
    required String author,
    required String text,
  }) async {
    await load();
    final idx = _spots.indexWhere((s) => s.id == spotId);
    if (idx < 0) return;

    final comment = Comment(
      id: _uuid.v4(),
      author: author.isEmpty ? 'anon' : author,
      text: text,
      createdAt: DateTime.now(),
    );

    final spot = _spots[idx];
    _spots[idx] = spot.copyWith(comments: [...spot.comments, comment]);
    await _save();
  }
}
