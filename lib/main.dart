import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'screens/camera_screen.dart';
import 'screens/gallery_screen.dart';
import 'screens/map_screen.dart';
import 'screens/analysis_list_screen.dart';
import 'package:yandex_maps_mapkit/init.dart' as init;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await init.initMapkit(
        apiKey: 'ebd640e1-f658-4501-9d60-4995189398e5'
    );
    runApp(const TreeTrackerApp());
  } catch (e) {
    runApp(const TreeTrackerApp());
  }
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
    AnalysisListScreen(),
  ];

  final _iosThemes = {
    Brightness.light: _IosThemeData(
      backgroundColor: const Color(0xFFF2F2F7),
      barBackgroundColor: Colors.white,
      primaryColor: const Color(0xFF007AFF),
      barForegroundColor: Colors.black,
      unselectedColor: const Color(0xFF8E8E93),
      scaffoldBackgroundColor: Colors.white,
      dividerColor: const Color(0xFFC6C6C8),
    ),
    Brightness.dark: _IosThemeData(
      backgroundColor: const Color(0xFF1C1C1E),
      barBackgroundColor: const Color(0xFF1C1C1E),
      primaryColor: const Color(0xFF0A84FF),
      barForegroundColor: Colors.white,
      unselectedColor: const Color(0xFF8E8E93),
      scaffoldBackgroundColor: const Color(0xFF000000),
      dividerColor: const Color(0xFF38383A),
    ),
  };

  Widget _getCurrentScreen() {
    return _pages[_index];
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dendrotector',
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      themeMode: ThemeMode.system,
      initialRoute: '/',
      routes: {
        '/': (context) {
          final brightness = MediaQuery.of(context).platformBrightness;
          final theme = _iosThemes[brightness]!;

          return Scaffold(
            backgroundColor: theme.scaffoldBackgroundColor,
            appBar: _buildIosAppBar(context, 'Dendrotector', theme),
            body: _getCurrentScreen(),
            bottomNavigationBar: _buildIosNavigationBar(context, theme),
          );
        },
        '/map': (context) {
          final brightness = MediaQuery.of(context).platformBrightness;
          final theme = _iosThemes[brightness]!;

          return Scaffold(
            backgroundColor: theme.scaffoldBackgroundColor,
            appBar: _buildIosAppBar(
              context,
              'Карта',
              theme,
              showBackButton: true,
            ),
            body: const MapScreen(),
          );
        },
      },
      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) {
            final brightness = MediaQuery.of(context).platformBrightness;
            final theme = _iosThemes[brightness]!;

            return Scaffold(
              backgroundColor: theme.scaffoldBackgroundColor,
              appBar: _buildIosAppBar(context, 'Ошибка', theme),
              body: const Center(
                child: Text('Страница не найдена'),
              ),
            );
          },
        );
      },
    );
  }

  PreferredSizeWidget _buildIosAppBar(
      BuildContext context,
      String title,
      _IosThemeData theme, {
        bool showBackButton = false,
      }) {
    return AppBar(
      title: Text(
        title,
        style: TextStyle(
          color: theme.barForegroundColor,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
      backgroundColor: theme.barBackgroundColor,
      elevation: 0.0,
      scrolledUnderElevation: 0.1,
      surfaceTintColor: Colors.transparent,
      foregroundColor: theme.barForegroundColor,
      leading: showBackButton
          ? IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        onPressed: () => Navigator.of(context).pop(),
        color: theme.primaryColor,
      )
          : null,
      centerTitle: true,
      toolbarHeight: 44,
    );
  }

  Widget _buildIosNavigationBar(BuildContext context, _IosThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.barBackgroundColor,
        border: Border(
          top: BorderSide(
            color: theme.dividerColor,
            width: 0.3,
          ),
        ),
      ),
      child: NavigationBar(
        selectedIndex: _index,
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        indicatorColor: theme.backgroundColor,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          _buildIosNavigationDestination(
            icon: Icons.photo_camera_outlined,
            selectedIcon: Icons.photo_camera,
            label: "Камера",
            theme: theme,
          ),
          _buildIosNavigationDestination(
            icon: Icons.photo_library_outlined,
            selectedIcon: Icons.photo_library,
            label: "Галерея",
            theme: theme,
          ),
          _buildIosNavigationDestination(
            icon: Icons.map_outlined,
            selectedIcon: Icons.map,
            label: "Карта",
            theme: theme,
          ),
          _buildIosNavigationDestination(
            icon: Icons.analytics_outlined,
            selectedIcon: Icons.analytics,
            label: "Анализы",
            theme: theme,
          ),
        ],
        onDestinationSelected: (i) => setState(() => _index = i),
      ),
    );
  }

  NavigationDestination _buildIosNavigationDestination({
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required _IosThemeData theme,
  }) {
    return NavigationDestination(
      icon: Icon(
        icon,
        size: 22,
        color: theme.unselectedColor,
      ),
      selectedIcon: Icon(
        selectedIcon,
        size: 22,
        color: theme.primaryColor,
      ),
      label: label,
    );
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF007AFF),
        brightness: Brightness.light,
        primary: const Color(0xFF007AFF),
        surface: Colors.white,
        background: Colors.white,
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.1,
        centerTitle: true,
        toolbarHeight: 44,
        titleTextStyle: TextStyle(
          color: Colors.black,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        indicatorColor: const Color(0xFFF2F2F7),
        labelTextStyle: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: Color(0xFF007AFF),
            );
          }
          return const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: Color(0xFF8E8E93),
          );
        }),
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        tileColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF2F2F7),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFC6C6C8),
        thickness: 0.3,
        space: 0,
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF0A84FF),
        brightness: Brightness.dark,
        primary: const Color(0xFF0A84FF),
        surface: Color(0xFF1C1C1E),
        background: Color(0xFF000000),
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFF000000),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1C1C1E),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.1,
        centerTitle: true,
        toolbarHeight: 44,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF1C1C1E),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        indicatorColor: const Color(0xFF2C2C2E),
        labelTextStyle: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: Color(0xFF0A84FF),
            );
          }
          return const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: Color(0xFF8E8E93),
          );
        }),
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        tileColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1C1C1E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF38383A),
        thickness: 0.3,
        space: 0,
      ),
    );
  }
}

class _IosThemeData {
  final Color backgroundColor;
  final Color barBackgroundColor;
  final Color primaryColor;
  final Color barForegroundColor;
  final Color unselectedColor;
  final Color scaffoldBackgroundColor;
  final Color dividerColor;

  _IosThemeData({
    required this.backgroundColor,
    required this.barBackgroundColor,
    required this.primaryColor,
    required this.barForegroundColor,
    required this.unselectedColor,
    required this.scaffoldBackgroundColor,
    required this.dividerColor,
  });
}