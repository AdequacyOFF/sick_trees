import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/tree_spot.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  List<TreeSpot> _spots = [];
  List<TreeSpot> get spots => List.unmodifiable(_spots);

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/spots.json');
    }

  Future<void> load() async {
    try {
      final f = await _file();
      if (await f.exists()) {
        final jsonStr = await f.readAsString();
        final list = json.decode(jsonStr) as List<dynamic>;
        _spots = list.map((e) => TreeSpot.fromJson(Map<String, dynamic>.from(e))).toList();
      }
    } catch (_) {
      _spots = [];
    }
  }

  Future<void> add(TreeSpot spot) async {
    _spots = [..._spots, spot];
    await _save();
  }

  Future<void> _save() async {
    final f = await _file();
    final jsonStr = json.encode(_spots.map((e) => e.toJson()).toList());
    await f.writeAsString(jsonStr);
  }
}