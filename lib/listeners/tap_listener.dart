// lib/listeners/tap_listener.dart
import 'package:yandex_maps_mapkit/mapkit.dart' as ymk;

/// Универсальный адаптер для подписки на тап по MapObject.
final class MapObjectTapListenerImpl implements ymk.MapObjectTapListener {
  final bool Function(ymk.MapObject, ymk.Point) onMapObjectTapped;

  const MapObjectTapListenerImpl({required this.onMapObjectTapped});

  @override
  bool onMapObjectTap(ymk.MapObject object, ymk.Point point) =>
      onMapObjectTapped(object, point);
}
