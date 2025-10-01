import 'package:flutter/material.dart';
import 'package:yandex_maps_mapkit/yandex_map.dart';
import 'package:yandex_maps_mapkit/mapkit.dart' as ymk;
import 'package:yandex_maps_mapkit/mapkit_factory.dart' show mapkit;

class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({
    super.key,
    this.initialPoint =
    const ymk.Point(latitude: 55.751244, longitude: 37.618423),
    this.initialZoom = 12.0,
  });

  final ymk.Point initialPoint;
  final double initialZoom;

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  ymk.MapWindow? _mapWindow;
  ymk.PlacemarkMapObject? _pin;
  ymk.Point? _picked;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    final map = _mapWindow?.map;
    if (map != null) {
      map.removeInputListener(_tapListener);
    }
    mapkit.onStop();
    super.dispose();
  }

  // Слушатель тапов по карте
  late final ymk.MapInputListener _tapListener = _MapTapListener(
    onTap: (map, point) {
      _picked = point;
      _renderPin(point);
    },
  );

  void _moveInitialCamera() {
    final mw = _mapWindow;
    if (mw == null) return;

    mw.map.move(
      ymk.CameraPosition(
        widget.initialPoint,
        zoom: widget.initialZoom,
        azimuth: 0,
        tilt: 0,
      ),
    );
  }

  void _renderPin(ymk.Point point) {
    final map = _mapWindow?.map;
    if (map == null) return;

    // Удаляем предыдущий маркер
    if (_pin != null) {
      map.mapObjects.remove(_pin!);
      _pin = null;
    }

    // Создаем новый маркер - УПРОЩЕННАЯ ВЕРСИЯ БЕЗ СТИЛЕЙ
    try {
      final pm = map.mapObjects.addPlacemark()
        ..geometry = point;

      _pin = pm;

      setState(() {});
    } catch (e) {
    }
  }

  void _confirm() {
    if (_picked == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ткните по карте, чтобы выбрать точку')),
      );
      return;
    }
    Navigator.of(context).pop<ymk.Point>(_picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Где сделано фото?'),
        actions: [
          if (_picked != null)
            IconButton(
              tooltip: 'Сбросить выбор',
              onPressed: () {
                final map = _mapWindow?.map;
                if (_pin != null && map != null) {
                  map.mapObjects.remove(_pin!);
                }
                setState(() {
                  _pin = null;
                  _picked = null;
                });
              },
              icon: const Icon(Icons.clear),
            ),
        ],
      ),
      body: Stack(
        children: [
          YandexMap(
            onMapCreated: (mw) {
              _mapWindow = mw;
              mapkit.onStart();
              _moveInitialCamera();
              mw.map.addInputListener(_tapListener);
            },
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_picked != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: const [
                        BoxShadow(
                          blurRadius: 6,
                          color: Colors.black26,
                        ),
                      ],
                    ),
                    child: Text(
                      'Выбрано: ${_picked!.latitude.toStringAsFixed(5)}, ${_picked!.longitude.toStringAsFixed(5)}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ElevatedButton.icon(
                  onPressed: _confirm,
                  icon: const Icon(Icons.check),
                  label: const Text('Подтвердить точку'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
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

class _MapTapListener implements ymk.MapInputListener {
  final void Function(ymk.Map, ymk.Point) onTap;
  _MapTapListener({required this.onTap});

  @override
  void onMapTap(ymk.Map map, ymk.Point point) => onTap(map, point);

  @override
  void onMapLongTap(ymk.Map map, ymk.Point point) {}
}