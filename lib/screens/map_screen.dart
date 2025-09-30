// lib/screens/map_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';

// Яндекс карта
import 'package:yandex_maps_mapkit/yandex_map.dart';
// Типы SDK: Point, MapWindow, IconStyle и т.д.
import 'package:yandex_maps_mapkit/mapkit.dart' as ymk;
// Провайдер для иконок из ассетов
import 'package:yandex_maps_mapkit/image.dart' as yimg;
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
  ymk.MapWindow? _mapWindow;
  final List<ymk.MapObject> _objects = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // ВАЖНО: запускаем MapKit при показе карты
    mapkit.onStart();
    _loadSpots();
  }

  @override
  void dispose() {
    _clearMap();
    WidgetsBinding.instance.removeObserver(this);
    // ВАЖНО: останавливаем MapKit, чтобы освободить ресурсы
    mapkit.onStop();
    super.dispose();
  }

  Future<void> _loadSpots() async {
    await _storage.load();
    if (!mounted) return;
    setState(() {});
    _renderAll(); // если карта уже создана — перерисуем маркеры
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

    final initialPoint = (_storage.spots.isNotEmpty)
        ? ymk.Point(
      latitude: _storage.spots.last.lat,
      longitude: _storage.spots.last.lng,
    )
        : const ymk.Point(latitude: 55.751244, longitude: 37.618423); // Москва

    mw.map.move(
      ymk.CameraPosition(
        initialPoint,
        zoom: (_storage.spots.isNotEmpty) ? 14 : 12,
        azimuth: 0.0,
        tilt: 0.0,
      ),
    );
  }

  void _renderAll() {
    final mw = _mapWindow;
    if (mw == null) return;

    _clearMap();
    _moveCameraToInitial();

    final map = mw.map;

    for (final s in _storage.spots) {
      try {
        final pm = map.mapObjects.addPlacemark()
          ..geometry = ymk.Point(latitude: s.lat, longitude: s.lng)
          ..userData = s.id;

        // Убираем проблемные операции с иконками
        // final icon = yimg.ImageProvider.fromImageProvider(
        //   const AssetImage('assets/marker.png'),
        // );
        // pm.setIcon(icon);
        // pm.setIconStyle(ymk.IconStyle(scale: 1.2));

        pm.addTapListener(MapObjectTapListenerImpl(
          onMapObjectTapped: (obj, p) {
            _openSpotSheet(s);
            return true;
          },
        ));

        _objects.add(pm);
      } catch (e) {
        print('Error creating marker for spot ${s.id}: $e');
      }
    }
  }

  void _openSpotSheet(TreeSpot spot) {
    try {
      showModalBottomSheet(
        context: context, // Теперь context доступен
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => _SpotSheet(
          spot: spot,
          onCommentAdded: () async {
            await _loadSpots(); // Теперь _loadSpots доступен
            if (!mounted) return; // Теперь mounted доступен
            Navigator.pop(context);
            try {
              final updatedSpot = _storage.spots.firstWhere( // Теперь _storage доступен
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
      print('Error opening spot sheet: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return YandexMap(
      onMapCreated: (mw) {
        _mapWindow = mw;
        _renderAll(); // после создания карты выставим камеру и маркеры
      },
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