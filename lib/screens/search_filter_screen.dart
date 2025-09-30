import 'package:flutter/material.dart';
import '../models/tree_spot.dart';

class SearchFilterScreen extends StatefulWidget {
  final List<TreeSpot> allSpots;
  final Function(List<TreeSpot>) onFilterApplied;

  const SearchFilterScreen({
    super.key,
    required this.allSpots,
    required this.onFilterApplied,
  });

  @override
  State<SearchFilterScreen> createState() => _SearchFilterScreenState();
}

class _SearchFilterScreenState extends State<SearchFilterScreen> {
  final _searchController = TextEditingController();
  Set<String> _selectedLabels = {};
  DateTime? _startDate;
  DateTime? _endDate;

  List<String> get _allLabels {
    final allLabels = <String>{};
    for (final spot in widget.allSpots) {
      for (final label in spot.labels) {
        allLabels.add(label.label);
      }
    }
    return allLabels.toList()..sort();
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase().trim();

    final filtered = widget.allSpots.where((spot) {
      // Текстовый поиск
      if (query.isNotEmpty) {
        final hasText = spot.labels.any((label) =>
            label.label.toLowerCase().contains(query)) ||
            (spot.comment?.toLowerCase().contains(query) ?? false) ||
            spot.comments.any((comment) =>
                comment.text.toLowerCase().contains(query));
        if (!hasText) return false;
      }

      // Фильтр по меткам
      if (_selectedLabels.isNotEmpty) {
        final spotLabels = spot.labels.map((l) => l.label).toSet();
        if (!_selectedLabels.any((label) => spotLabels.contains(label))) {
          return false;
        }
      }

      // Фильтр по дате
      if (_startDate != null && spot.createdAt.isBefore(_startDate!)) {
        return false;
      }
      if (_endDate != null && spot.createdAt.isAfter(_endDate!)) {
        return false;
      }

      return true;
    }).toList();

    widget.onFilterApplied(filtered);
    Navigator.pop(context);
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _selectedLabels.clear();
      _startDate = null;
      _endDate = null;
    });
    widget.onFilterApplied(widget.allSpots);
    Navigator.pop(context);
  }

  Future<void> _selectDate(bool isStartDate) async {
    final initialDate = isStartDate ? _startDate : _endDate;
    final firstDate = DateTime(2020);
    final lastDate = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Фильтры поиска'),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: _clearFilters,
            tooltip: 'Очистить все фильтры',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Текстовый поиск',
                hintText: 'Введите метку, комментарий...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Фильтр по меткам
            if (_allLabels.isNotEmpty) ...[
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Метки:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _allLabels.map((label) {
                  final isSelected = _selectedLabels.contains(label);
                  return FilterChip(
                    label: Text(label),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedLabels.add(label);
                        } else {
                          _selectedLabels.remove(label);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],

            // Фильтр по дате
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Дата создания:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _selectDate(true),
                    child: Text(_startDate == null
                        ? 'Начальная дата'
                        : 'С: ${_startDate!.toString().split(' ')[0]}'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _selectDate(false),
                    child: Text(_endDate == null
                        ? 'Конечная дата'
                        : 'По: ${_endDate!.toString().split(' ')[0]}'),
                  ),
                ),
              ],
            ),

            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _applyFilters,
                child: const Text('Применить фильтры'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}