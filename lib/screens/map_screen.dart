import 'dart:async';
import 'package:flutter/material.dart';
import 'package:yandex_maps_mapkit/mapkit.dart' as mapkit;
import 'package:geolocator/geolocator.dart';
import '../services/storage_service.dart';
import '../models/tree_spot.dart';
import '../listeners/tap_listener.dart';
import '../widgets/flutter_map_widget.dart';



class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _storage = StorageService();


  mapkit.MapWindow? _mapWindow;
  late mapkit.MapObjectCollection _mapObjectCollection;
  late final _placemarkTapListener = MapObjectTapListenerImpl(
    onMapObjectTapped: (mapObject, point) {
      if (mapObject is mapkit.PlacemarkMapObject) {
        final spot = mapObject.userData as TreeSpot?;
        if (spot != null) {
          _onTreeSpotTap(spot, point);
        }
      }
      return true;
    },
  );

  mapkit.Point? _myPos;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _storage.load();
    await _ensureLocation();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _ensureLocation() async {
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    final pos = await Geolocator.getCurrentPosition();
    _myPos = mapkit.Point(latitude: pos.latitude, longitude: pos.longitude);
  }

  void _createMapObjects(mapkit.MapWindow mapWindow) {
    _mapWindow = mapWindow;

    // Устанавливаем начальную позицию карты с обязательными параметрами
    final startPoint = _myPos ?? const mapkit.Point(latitude: 55.751244, longitude: 37.618423);
    mapWindow.map.move(
      mapkit.CameraPosition(
        startPoint,
        zoom: 14,
        azimuth: 0.0,  // Добавлен обязательный параметр
        tilt: 0.0,     // Добавлен обязательный параметр
      ),
    );

    // Создаем коллекцию объектов для карты
    _mapObjectCollection = mapWindow.map.mapObjects.addCollection();

    // Добавляем маркеры для всех точек
    _addTreeSpotsMarkers();

    setState(() => _isLoading = false);
  }

  void _addTreeSpotsMarkers() {
    for (final spot in _storage.spots) {
      final placemark = _mapObjectCollection.addPlacemark()
        ..geometry = mapkit.Point(latitude: spot.lat, longitude: spot.lng)
        ..setText(spot.labels.isNotEmpty ? spot.labels.first.label : 'Дерево')
        ..setTextStyle(
          const mapkit.TextStyle(
            size: 12.0,
            color: Colors.black,
            placement: mapkit.TextStylePlacement.Top,
            offset: 5.0,
          ),
        )
        ..userData = spot
        ..addTapListener(_placemarkTapListener);
    }
  }

  void _showTreeSpotInfo(TreeSpot spot) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(spot.labels.isNotEmpty ? spot.labels.first.label : 'Дерево'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (spot.comment != null) Text(spot.comment!),
            const SizedBox(height: 8),
            Text('Широта: ${spot.lat.toStringAsFixed(6)}'),
            Text('Долгота: ${spot.lng.toStringAsFixed(6)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  void _updateMapObjects() {
    // Очищаем старые маркеры
    _mapObjectCollection.clear();
    // Добавляем обновленные маркеры
    _addTreeSpotsMarkers();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              FlutterMapWidget(
                onMapCreated: _createMapObjects,
              ),
              if (_isLoading)
                const Center(
                  child: CircularProgressIndicator(),
                ),
            ],
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Точек: ${_storage.spots.length}'),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () {
                    setState(() {
                      _isLoading = true;
                    });
                    _load().then((_) {
                      if (_mapWindow != null) {
                        _updateMapObjects();
                      }
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }


  void _onTreeSpotTap(TreeSpot spot, mapkit.Point point) {
    final label = spot.labels.isNotEmpty ? spot.labels.first.label : 'Дерево';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Точка: $label\n(${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)})')),
    );
  }
}