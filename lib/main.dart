import 'package:flutter/material.dart';
import 'screens/camera_screen.dart';
import 'screens/gallery_screen.dart';
import 'screens/map_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
  ];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TreeTracker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: Scaffold(
        appBar: AppBar(title: const Text('TreeTracker Starter')),
        body: _pages[_index],
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.photo_camera), label: "Камера"),
            NavigationDestination(icon: Icon(Icons.photo_library), label: "Галерея"),
            NavigationDestination(icon: Icon(Icons.map), label: "Карта"),
          ],
          onDestinationSelected: (i) => setState(() => _index = i),
        ),
      ),
    );
  }
}