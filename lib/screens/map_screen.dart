import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../services/storage_service.dart';
import '../models/tree_spot.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _storage = StorageService();
  final Completer<GoogleMapController> _mapController = Completer();
  LatLng? _myPos;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _storage.load();
    await _ensureLocation();
    if (mounted) setState(() {});
  }

  Future<void> _ensureLocation() async {
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    final pos = await Geolocator.getCurrentPosition();
    _myPos = LatLng(pos.latitude, pos.longitude);
  }

  Set<Marker> _markers() {
    return _storage.spots.map((TreeSpot s) {
      return Marker(
        markerId: MarkerId(s.id),
        position: LatLng(s.lat, s.lng),
        infoWindow: InfoWindow(
          title: s.labels.isNotEmpty ? s.labels.first.label : 'Дерево',
          snippet: s.comment ?? 'Без комментария',
        ),
      );
    }).toSet();
  }

  @override
  Widget build(BuildContext context) {
    final start = _myPos ?? const LatLng(55.751244, 37.618423); // Москва центр fallback
    return Column(
      children: [
        Expanded(
          child: GoogleMap(
            initialCameraPosition: CameraPosition(target: start, zoom: 14),
            markers: _markers(),
            myLocationEnabled: true,
            onMapCreated: (c) => _mapController.complete(c),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Text('Точек: ${_storage.spots.length}'),
          ),
        ),
      ],
    );
  }
}