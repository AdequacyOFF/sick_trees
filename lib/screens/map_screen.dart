import 'dart:io';
import 'package:flutter/material.dart';

// Яндекс карта
import 'package:yandex_maps_mapkit/yandex_map.dart';
// Типы SDK: Point, MapWindow, IconStyle и т.д.
import 'package:yandex_maps_mapkit/mapkit.dart' as ymk;
// Жизненный цикл SDK (onStart/onStop)
import 'package:yandex_maps_mapkit/mapkit_factory.dart' show mapkit;

import '../models/tree_spot.dart';
import '../services/storage_service.dart';
import '../listeners/tap_listener.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with WidgetsBindingObserver {
  final _storage = StorageService();
  final _searchController = TextEditingController();
  ymk.MapWindow? _mapWindow;
  final List<ymk.MapObject> _objects = [];
  List<TreeSpot> _filteredSpots = [];
  String _searchQuery = '';

  // Для выделения маркера при переходе из других экранов
  ymk.Point? _highlightedPoint;
  String? _highlightedSpotId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    mapkit.onStart();
    _loadSpots();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Получаем аргументы навигации
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      _highlightedPoint = args['highlightSpot'] as ymk.Point?;
      _highlightedSpotId = args['spotId'] as String?;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _clearMap();
    WidgetsBinding.instance.removeObserver(this);
    mapkit.onStop();
    super.dispose();
  }

  Future<void> _loadSpots() async {
    await _storage.load();
    if (!mounted) return;
    setState(() {
      _filteredSpots = _storage.spots;
    });
    _renderAll();
  }

  void _clearMap() {
    final map = _mapWindow?.map;
    if (map == null) return;
    for (final obj in _objects) {
      map.mapObjects.remove(obj);
    }
    _objects.clear();
  }

  void _moveCameraToInitial() {
    final mw = _mapWindow;
    if (mw == null) return;

    final initialPoint = (_filteredSpots.isNotEmpty)
        ? ymk.Point(
      latitude: _filteredSpots.last.lat,
      longitude: _filteredSpots.last.lng,
    )
        : const ymk.Point(latitude: 55.751244, longitude: 37.618423);

    mw.map.move(
      ymk.CameraPosition(
        initialPoint,
        zoom: (_filteredSpots.isNotEmpty) ? 14 : 12,
        azimuth: 0.0,
        tilt: 0.0,
      ),
    );
  }

  void _moveCameraToSpot(TreeSpot spot) {
    final mw = _mapWindow;
    if (mw == null) return;

    // Упрощенная версия без анимации
    mw.map.move(
      ymk.CameraPosition(
        ymk.Point(latitude: spot.lat, longitude: spot.lng),
        zoom: 16,
        azimuth: 0.0,
        tilt: 0.0,
      ),
    );
  }

  void _moveCameraToPoint(ymk.Point point) {
    final mw = _mapWindow;
    if (mw == null) return;

    mw.map.move(
      ymk.CameraPosition(
        point,
        zoom: 16,
        azimuth: 0.0,
        tilt: 0.0,
      ),
    );
  }

  void _performSearch(String query) {
    setState(() {
      _searchQuery = query.toLowerCase().trim();

      if (_searchQuery.isEmpty) {
        _filteredSpots = _storage.spots;
      } else {
        _filteredSpots = _storage.spots.where((spot) {
          // Поиск по меткам (labels)
          final hasLabel = spot.labels.any((label) =>
              label.label.toLowerCase().contains(_searchQuery));

          // Поиск по комментарию
          final hasComment = spot.comment?.toLowerCase().contains(_searchQuery) ?? false;

          // Поиск по комментариям других пользователей
          final hasUserComment = spot.comments.any((comment) =>
          comment.text.toLowerCase().contains(_searchQuery) ||
              comment.author.toLowerCase().contains(_searchQuery));

          return hasLabel || hasComment || hasUserComment;
        }).toList();
      }
    });

    _renderAll();

    // Если найден только один результат - перемещаем камеру к нему
    if (_filteredSpots.length == 1) {
      _moveCameraToSpot(_filteredSpots.first);
    }
  }

  void _clearSearch() {
    _searchController.clear();
    _performSearch('');
    // Сбрасываем выделение при очистке поиска
    _highlightedPoint = null;
    _highlightedSpotId = null;
  }

  void _showAllResults() {
    if (_filteredSpots.isNotEmpty) {
      // Находим bounding box всех результатов
      double minLat = _filteredSpots.first.lat;
      double maxLat = _filteredSpots.first.lat;
      double minLng = _filteredSpots.first.lng;
      double maxLng = _filteredSpots.first.lng;

      for (final spot in _filteredSpots) {
        if (spot.lat < minLat) minLat = spot.lat;
        if (spot.lat > maxLat) maxLat = spot.lat;
        if (spot.lng < minLng) minLng = spot.lng;
        if (spot.lng > maxLng) maxLng = spot.lng;
      }

      // Центрируем камеру на середине bounding box
      final centerLat = (minLat + maxLat) / 2;
      final centerLng = (minLng + maxLng) / 2;

      final mw = _mapWindow;
      if (mw != null) {
        mw.map.move(
          ymk.CameraPosition(
            ymk.Point(latitude: centerLat, longitude: centerLng),
            zoom: 12,
            azimuth: 0.0,
            tilt: 0.0,
          ),
        );
      }
    }
  }

  void _renderAll() {
    final mw = _mapWindow;
    if (mw == null) return;

    _clearMap();

    final map = mw.map;

    // Создаем маркеры для всех отфильтрованных spots
    for (final spot in _filteredSpots) {
      try {
        final pm = map.mapObjects.addPlacemark()
          ..geometry = ymk.Point(latitude: spot.lat, longitude: spot.lng)
          ..userData = spot.id;

        // Добавляем слушатель тапов
        pm.addTapListener(MapObjectTapListenerImpl(
          onMapObjectTapped: (obj, p) {
            _openSpotSheet(spot);
            return true;
          },
        ));

        _objects.add(pm);
      } catch (e) {
      }
    }

    if (_highlightedPoint != null) {
      try {
        final highlightPm = map.mapObjects.addPlacemark()
          ..geometry = _highlightedPoint!
          ..userData = 'highlighted';

        _objects.add(highlightPm);

        _moveCameraToPoint(_highlightedPoint!);
      } catch (e) {
      }
    } else if (_filteredSpots.isNotEmpty && _searchQuery.isEmpty) {
      _moveCameraToInitial();
    }
  }

  void _openSpotSheet(TreeSpot spot) {
    try {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => _SpotSheet(
          spot: spot,
          onCommentAdded: () async {
            await _loadSpots();
            if (!mounted) return;
            Navigator.pop(context);
            try {
              final updatedSpot = _storage.spots.firstWhere(
                    (e) => e.id == spot.id,
                orElse: () => spot,
              );
              _openSpotSheet(updatedSpot);
            } catch (e) {
              // Игнорируем ошибку если спот не найден
            }
            _renderAll();
          },
        ),
      );
    } catch (e) {
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Панель поиска
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.background,
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Поиск по меткам, комментариям...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: _clearSearch,
                    )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: _performSearch,
                ),
                const SizedBox(height: 8),
                if (_searchQuery.isNotEmpty)
                  Row(
                    children: [
                      Text(
                        'Найдено: ${_filteredSpots.length}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const Spacer(),
                      if (_filteredSpots.isNotEmpty) ...[
                        if (_filteredSpots.length > 1)
                          TextButton(
                            onPressed: _showAllResults,
                            child: const Text('Показать все'),
                          ),
                        TextButton(
                          onPressed: () {
                            if (_filteredSpots.isNotEmpty) {
                              _moveCameraToSpot(_filteredSpots.first);
                            }
                          },
                          child: const Text('Первый результат'),
                        ),
                      ],
                    ],
                  ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                YandexMap(
                  onMapCreated: (mw) {
                    _mapWindow = mw;
                    _renderAll();
                  },
                ),
                // Сообщение о пустом результате поиска
                if (_searchQuery.isNotEmpty && _filteredSpots.isEmpty)
                  Container(
                    alignment: Alignment.center,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.search_off, size: 48, color: Colors.grey),
                            const SizedBox(height: 8),
                            Text(
                              'Ничего не найдено по запросу: "$_searchQuery"',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: _clearSearch,
                              child: const Text('Очистить поиск'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                // Индикатор выделенной точки
                if (_highlightedPoint != null)
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_on, color: Colors.blue),
                            const SizedBox(width: 8),
                            Text(
                              'Выделенная точка',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () {
                                setState(() {
                                  _highlightedPoint = null;
                                  _highlightedSpotId = null;
                                });
                                _renderAll();
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SpotSheet extends StatefulWidget {
  const _SpotSheet({required this.spot, required this.onCommentAdded});
  final TreeSpot spot;
  final Future<void> Function() onCommentAdded;

  @override
  State<_SpotSheet> createState() => _SpotSheetState();
}

class _SpotSheetState extends State<_SpotSheet> {
  final _commentCtrl = TextEditingController();
  final _authorCtrl = TextEditingController(text: 'гость');
  final _storage = StorageService();
  bool _sending = false;

  String _primaryLabel(TreeSpot s) =>
      s.labels.isEmpty ? 'Без метки' : s.labels.first.label;

  @override
  Widget build(BuildContext context) {
    final s = widget.spot;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        top: 8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (s.imagePath != null && s.imagePath!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(s.imagePath!),
                  width: 84,
                  height: 84,
                  fit: BoxFit.cover,
                ),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_primaryLabel(s), style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text('${s.lat.toStringAsFixed(6)}, ${s.lng.toStringAsFixed(6)}'),
                if (s.comment != null && s.comment!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(s.comment!),
                ],
              ]),
            ),
          ]),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Комментарии', style: Theme.of(context).textTheme.titleSmall),
          ),
          const SizedBox(height: 8),
          if (s.comments.isEmpty)
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Пока нет комментариев — будьте первым!'),
            )
          else
            SizedBox(
              height: 180,
              child: ListView.separated(
                itemCount: s.comments.length,
                separatorBuilder: (_, __) => const Divider(height: 12),
                itemBuilder: (_, i) {
                  final c = s.comments[i];
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(c.author),
                    subtitle: Text(c.text),
                    trailing: Text(
                      '${c.createdAt.hour.toString().padLeft(2, '0')}:${c.createdAt.minute.toString().padLeft(2, '0')}',
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _authorCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Ваше имя',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _commentCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Оставьте комментарий',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: _sending
                    ? const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Icon(Icons.send),
                onPressed: _sending
                    ? null
                    : () async {
                  final text = _commentCtrl.text.trim();
                  final author = _authorCtrl.text.trim();
                  if (text.isEmpty) return;
                  setState(() => _sending = true);
                  await _storage.addComment(
                    spotId: s.id,
                    author: author.isEmpty ? 'гость' : author,
                    text: text,
                  );
                  setState(() => _sending = false);
                  _commentCtrl.clear();
                  await widget.onCommentAdded();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}