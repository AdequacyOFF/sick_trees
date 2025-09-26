// lib/screens/location_picker_screen.dart
import 'package:flutter/material.dart';
import 'package:yandex_maps_mapkit/yandex_map.dart';
import 'package:yandex_maps_mapkit/mapkit.dart' as ymk;
import 'package:yandex_maps_mapkit/mapkit_factory.dart' show mapkit; // onStart/onStop
import 'package:yandex_maps_mapkit/image.dart' as yimg; // иконка из ассета

/// Экран выбора точки на карте Яндекс.
/// Тап по карте ставит маркер, кнопка снизу возвращает выбранный Point.
class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({
    super.key,
    this.initialPoint =
    const ymk.Point(latitude: 55.751244, longitude: 37.618423), // Москва
    this.initialZoom = 12.0,
  });

  /// Начальная позиция камеры.
  final ymk.Point initialPoint;

  /// Начальный зум.
  final double initialZoom;

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  ymk.MapWindow? _mapWindow;
  ymk.PlacemarkMapObject? _pin;
  ymk.Point? _picked;

  // Слушатель тапов по карте
  late final ymk.MapInputListener _tapListener = _MapTapListener(
    onTap: (map, point) {
      _picked = point;
      _renderPin(point);
    },
  );

  @override
  void initState() {
    super.initState();
    // Важно: запуск сетевого стека SDK, иначе тайлы могут не загрузиться
    mapkit.onStart();
  }

  @override
  void dispose() {
    final map = _mapWindow?.map;
    if (map != null) {
      map.removeInputListener(_tapListener);
    }
    // Остановка SDK при уходе со страницы
    mapkit.onStop();
    super.dispose();
  }

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
    final map = _mapWindow!.map;

    // Удаляем предыдущий маркер
    if (_pin != null) {
      map.mapObjects.remove(_pin!);
      _pin = null;
    }

    // Иконка маркера из ассета (если ассета нет — будет системный пин)
    yimg.ImageProvider? icon;
    try {
      icon = yimg.ImageProvider.fromImageProvider(
        const AssetImage('assets/marker.png'),
      );
    } catch (_) {
      icon = null;
    }

    final pm = map.mapObjects.addPlacemark()
      ..geometry = point
      ..setIconStyle(ymk.IconStyle(scale: 1.2)); // делаем маркер заметнее

    if (icon != null) {
      pm.setIcon(icon);
    }

    _pin = pm;
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
                // Сброс маркера и выбранной точки
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
              _moveInitialCamera();
              mw.map.addInputListener(_tapListener);
            },
          ),
          // Панель подтверждения
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_picked != null)
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color:
                      Theme.of(context).colorScheme.surface.withOpacity(0.9),
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
