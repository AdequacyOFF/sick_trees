import 'package:flutter/material.dart';
import 'screens/camera_screen.dart';
import 'screens/gallery_screen.dart';
import 'screens/map_screen.dart';
import 'screens/image_upload_screen.dart';
import 'package:yandex_maps_mapkit/init.dart' as init;
//import 'package:yandex_maps_mapkit/mapkit_factory.dart' show mapkit;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await init.initMapkit(
      apiKey: const String.fromEnvironment('ebd640e1-f658-4501-9d60-4995189398e5')
  );
  runApp(const TreeTrackerApp());
}

class TreeTrackerApp extends StatefulWidget {
  const TreeTrackerApp({super.key});

  @override
  State<TreeTrackerApp> createState() => _TreeTrackerAppState();
}

class _TreeTrackerAppState extends State<TreeTrackerApp> {
  int _index = 0;

  final _pages = const [
    CameraScreen(),
    GalleryScreen(),
    MapScreen(),
    ImageUploadScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dendrotector',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: Scaffold(
        appBar: AppBar(title: const Text('Dendrotector')),
        body: _pages[_index],
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.photo_camera), label: "Камера"),
            NavigationDestination(icon: Icon(Icons.photo_library), label: "Галерея"),
            NavigationDestination(icon: Icon(Icons.map), label: "Карта"),
            NavigationDestination(icon: Icon(Icons.map), label: "Загрузка"),
          ],
          onDestinationSelected: (i) => setState(() => _index = i),
        ),
      ),
    );
  }
}