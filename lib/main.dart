import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'widgets/bottom_pill_nav.dart';
// New UI Screens (scaffolds)
import 'screens/home_screen.dart';
import 'screens/tracking_screen.dart';
import 'screens/tasks_screen.dart';
import 'services/detection_service.dart';
import 'services/background_notification_service.dart';

// Global Camera List
List<CameraDescription> cameras = [];

// Theme Notifier for Global Dark/Light Mode
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set preferred orientation to portrait for a consistent test lab
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  try {
    cameras = await availableCameras();
  } catch (e) {
    debugPrint("Error fetching cameras: $e");
  }

  runApp(const SightFeasibilityApp());
}

class SightFeasibilityApp extends StatelessWidget {
  const SightFeasibilityApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode currentMode, __) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'SIGHT Lab',
          themeMode: currentMode,
          
          // --- LIGHT THEME (Apple Style) ---
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF007AFF), // iOS Blue
              background: const Color(0xFFF2F2F7), // iOS Light Gray Background
              surface: Colors.white,
            ),
            scaffoldBackgroundColor: const Color(0xFFF2F2F7),
            
            // FIX: Changed 'CardTheme' to 'CardThemeData'
            cardTheme: CardThemeData(
              color: Colors.white,
              elevation: 0, // Flat design
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: Colors.grey.shade200, width: 1),
              ),
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFFF2F2F7),
              surfaceTintColor: Colors.transparent,
            ),
          ),

          // --- DARK THEME (Apple Style) ---
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF0A84FF), // iOS Dark Blue
              brightness: Brightness.dark,
              background: const Color(0xFF000000), // Pure Black
              surface: const Color(0xFF1C1C1E), // iOS Dark Surface
            ),
            scaffoldBackgroundColor: const Color(0xFF000000),
            
            // FIX: Changed 'CardTheme' to 'CardThemeData'
            cardTheme: CardThemeData(
              color: const Color(0xFF1C1C1E),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF000000),
              surfaceTintColor: Colors.transparent,
            ),
          ),

          home: const RootApp(),
        );
      },
    );
  }
}
class RootApp extends StatefulWidget {
  const RootApp({Key? key}) : super(key: key);

  @override
  State<RootApp> createState() => _RootAppState();
}

class _RootAppState extends State<RootApp> with WidgetsBindingObserver {
  int _index = 0;

  final List<Widget> _pages = const [
    HomeScreen(),
    TrackingScreen(),
    TasksScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    try {
      DetectionService.instance.initialize();
    } catch (e) {
      debugPrint('DetectionService init error: $e');
    }

    // Start background notification service (it will only enable background
    // execution after calibration to respect the 30cm requirement)
    try {
      BackgroundNotificationService.instance.start();
    } catch (e) {
      debugPrint('BackgroundNotificationService init error: $e');
    }
  }

  Future<void> _enableBackgroundExecution() async {
    return;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Keep DetectionService running across lifecycle; do not dispose it so
    // it remains active while the app is backgrounded if platform permits.
    debugPrint('AppLifecycleState changed: $state');
    try {
      if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
        BackgroundNotificationService.instance.start();
      } else if (state == AppLifecycleState.resumed) {
        DetectionService.instance.restartMonitoringWithDelay();
      }
    } catch (e) {
      debugPrint('BackgroundNotificationService lifecycle error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: IndexedStack(
          index: _index,
          children: _pages,
        ),
      ),
      bottomNavigationBar: SizedBox(
        height: 88,
        child: BottomPillNav(
          currentIndex: _index,
          onTap: (i) => setState(() => _index = i),
        ),
      ),
    );
  }
}