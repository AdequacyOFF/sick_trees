// lib/widgets/flutter_map_widget.dart
import 'package:flutter/material.dart';
import 'package:yandex_maps_mapkit/yandex_map.dart';
import 'package:yandex_maps_mapkit/mapkit.dart' as ymk;
import 'package:yandex_maps_mapkit/mapkit_factory.dart' show mapkit;

final class FlutterMapWidget extends StatefulWidget {
  final void Function(ymk.MapWindow) onMapCreated;
  final VoidCallback? onMapDispose;

  const FlutterMapWidget({
    super.key,
    required this.onMapCreated,
    this.onMapDispose,
  });

  @override
  State<FlutterMapWidget> createState() => _FlutterMapWidgetState();
}

class _FlutterMapWidgetState extends State<FlutterMapWidget>
    with WidgetsBindingObserver {
  ymk.MapWindow? _mapWindow;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Сообщаем SDK, что карта появилась
    mapkit.onStart();
  }

  @override
  void dispose() {
    widget.onMapDispose?.call();
    // Сообщаем SDK, что карта скрыта
    mapkit.onStop();
    WidgetsBinding.instance.removeObserver(this);
    _mapWindow = null;
    super.dispose();
  }

  void _applyNightMode() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    _mapWindow?.map.nightModeEnabled = isDark;
  }

  @override
  Widget build(BuildContext context) {
    return YandexMap(
      onMapCreated: (mw) {
        _mapWindow = mw;
        _applyNightMode();
        widget.onMapCreated(mw);
      },
    );
  }
}
