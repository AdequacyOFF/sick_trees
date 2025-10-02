// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import '../services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settingsService = SettingsService();
  final _baseUrlController = TextEditingController();
  final _topKController = TextEditingController();
  final _diseaseScoreController = TextEditingController();

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
  }

  Future<void> _loadCurrentSettings() async {
    // Даем время на инициализацию SettingsService
    await Future.delayed(const Duration(milliseconds: 100));

    setState(() {
      _baseUrlController.text = _settingsService.baseUrl;
      _topKController.text = _settingsService.topK.toString();
      _diseaseScoreController.text = _settingsService.diseaseScore.toStringAsFixed(2);
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    final baseUrl = _baseUrlController.text.trim();
    final topK = int.tryParse(_topKController.text);
    final diseaseScore = double.tryParse(_diseaseScoreController.text);

    // Валидация
    if (baseUrl.isEmpty) {
      _showError('URL сервера не может быть пустым');
      return;
    }

    if (!baseUrl.startsWith('http://') && !baseUrl.startsWith('https://')) {
      _showError('URL должен начинаться с http:// или https://');
      return;
    }

    if (topK == null || topK <= 0) {
      _showError('Top K должен быть положительным числом');
      return;
    }

    if (topK > 10) {
      _showError('Top K не может быть больше 10');
      return;
    }

    if (diseaseScore == null || diseaseScore < 0 || diseaseScore > 1) {
      _showError('Disease Score должен быть числом от 0.0 до 1.0');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _settingsService.saveSettings(
        baseUrl: baseUrl,
        topK: topK,
        diseaseScore: diseaseScore,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Настройки сохранены'),
            backgroundColor: Colors.green,
          ),
        );

        // Возвращаемся назад через секунду
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) Navigator.of(context).pop();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showError('Ошибка сохранения: $e');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _resetToDefaults() {
    setState(() {
      _baseUrlController.text = SettingsService.defaultBaseUrl;
      _topKController.text = SettingsService.defaultTopK.toString();
      _diseaseScoreController.text = SettingsService.defaultDiseaseScore.toStringAsFixed(2);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Настройки сброшены к значениям по умолчанию')),
    );
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _topKController.dispose();
    _diseaseScoreController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки сервера'),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.restore),
              onPressed: _resetToDefaults,
              tooltip: 'Сбросить к значениям по умолчанию',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Base URL настройка
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Настройки сервера',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _baseUrlController,
                      decoration: const InputDecoration(
                        labelText: 'Base URL',
                        hintText: 'http://your-server.com:port',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.link),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Параметры анализа
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Параметры анализа',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: _topKController,
                      decoration: const InputDecoration(
                        labelText: 'Top K',
                        hintText: 'Количество вариантов видов деревьев (1-10)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.format_list_numbered),
                      ),
                      keyboardType: TextInputType.number,
                    ),

                    const SizedBox(height: 16),

                    TextField(
                      controller: _diseaseScoreController,
                      decoration: const InputDecoration(
                        labelText: 'Disease Score Threshold',
                        hintText: 'Порог вероятности для заболеваний (0.0-1.0)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.medical_services),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Кнопки действий
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _saveSettings,
                    icon: const Icon(Icons.save),
                    label: const Text('Сохранить настройки'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            OutlinedButton.icon(
              onPressed: _resetToDefaults,
              icon: const Icon(Icons.restore),
              label: const Text('Сбросить к значениям по умолчанию'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),

            // Текущие значения по умолчанию
            const SizedBox(height: 24),
            Card(
              color: Colors.blue[50],
              child: const Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Значения по умолчанию:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text('Base URL: http://194.85.249.95:58000/'),
                    Text('Top K: 3'),
                    Text('Disease Score: 0.47'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}