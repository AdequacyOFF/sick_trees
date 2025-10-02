// lib/services/settings_service.dart
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _baseUrlKey = 'base_url';
  static const String _topKKey = 'top_k';
  static const String _diseaseScoreKey = 'disease_score';

  static const String defaultBaseUrl = 'http://194.85.249.95:58000/';
  static const int defaultTopK = 3;
  static const double defaultDiseaseScore = 0.47;

  String _baseUrl = defaultBaseUrl;
  int _topK = defaultTopK;
  double _diseaseScore = defaultDiseaseScore;

  SettingsService() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _baseUrl = prefs.getString(_baseUrlKey) ?? defaultBaseUrl;
      _topK = prefs.getInt(_topKKey) ?? defaultTopK;
      _diseaseScore = prefs.getDouble(_diseaseScoreKey) ?? defaultDiseaseScore;
    } catch (e) {
      // Если возникла ошибка при загрузке, используем значения по умолчанию
      _baseUrl = defaultBaseUrl;
      _topK = defaultTopK;
      _diseaseScore = defaultDiseaseScore;
    }
  }

  Future<void> saveSettings({
    String? baseUrl,
    int? topK,
    double? diseaseScore,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    if (baseUrl != null) {
      _baseUrl = baseUrl;
      await prefs.setString(_baseUrlKey, baseUrl);
    }

    if (topK != null) {
      _topK = topK;
      await prefs.setInt(_topKKey, topK);
    }

    if (diseaseScore != null) {
      _diseaseScore = diseaseScore;
      await prefs.setDouble(_diseaseScoreKey, diseaseScore);
    }
  }

  // Getters
  String get baseUrl => _baseUrl;
  int get topK => _topK;
  double get diseaseScore => _diseaseScore;

  // Метод для сброса к значениям по умолчанию
  Future<void> resetToDefaults() async {
    await saveSettings(
      baseUrl: defaultBaseUrl,
      topK: defaultTopK,
      diseaseScore: defaultDiseaseScore,
    );
  }
}