import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

// Test Screens
import 'distance_test_screen.dart';
import 'blink_test_screen.dart';
import 'screening_test_screen.dart';

// Global Camera List
List<CameraDescription> cameras = [];

// Theme Notifier for Global Dark/Light Mode
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);

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

          home: const LabHubScreen(),
        );
      },
    );
  }
}

class LabHubScreen extends StatelessWidget {
  const LabHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Determine current theme for icon colors
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // 1. Large Collapsing Header
          SliverAppBar.large(
            title: const Text(
              "SIGHT Lab",
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: -0.5),
            ),
            centerTitle: false,
            actions: [
              // Theme Toggle Button
              IconButton(
                icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
                onPressed: () {
                  themeNotifier.value = isDark ? ThemeMode.light : ThemeMode.dark;
                },
              ),
              const SizedBox(width: 16),
            ],
          ),

          // 2. Content List
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Status Card
                  _buildStatusCard(context, isDark),
                  const SizedBox(height: 24),
                  
                  const Text(
                    "Test Modules",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),

                  // Module A: Distance
                  _buildModuleTile(
                    context,
                    title: "Distance Monitor",
                    subtitle: "Vision-based proximity detection",
                    icon: Icons.face_retouching_natural,
                    color: Colors.blueAccent,
                    isDark: isDark,
                    onTap: () => _navigateTo(context, const DistanceTestScreen()),
                  ),
                  const SizedBox(height: 12),

                  // Module B: Blink
                  _buildModuleTile(
                    context,
                    title: "Blink Analysis",
                    subtitle: "EAR (Eye Aspect Ratio) calculation",
                    icon: Icons.remove_red_eye,
                    color: Colors.greenAccent.shade700,
                    isDark: isDark,
                    onTap: () => _navigateTo(context, const BlinkTestScreen()),
                  ),
                  const SizedBox(height: 12),

                  // Module C: AI Screening
                  _buildModuleTile(
                    context,
                    title: "Symptom Screening",
                    subtitle: "Offline TFLite Inference Pipeline",
                    icon: Icons.medical_services,
                    color: Colors.orangeAccent.shade700,
                    isDark: isDark,
                    onTap: () => _navigateTo(context, const ScreeningTestScreen()),
                  ),

                  const SizedBox(height: 40),
                  
                  // Footer
                  Center(
                    child: Text(
                      "SIGHT Feasibility Prototype v1.0\nCapstone Project 2026",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildStatusCard(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark ? [] : [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.teal.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle, color: Colors.teal, size: 24),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "System Ready",
                style: TextStyle(
                  fontSize: 16, 
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87
                ),
              ),
              Text(
                "${cameras.length} Cameras Detected",
                style: TextStyle(
                  fontSize: 13, 
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModuleTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              // Icon Container
              Container(
                height: 50,
                width: 50,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 16),
              
              // Text Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17, 
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.3
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13, 
                        color: Colors.grey.shade500
                      ),
                    ),
                  ],
                ),
              ),
              
              // Arrow
              Icon(
                Icons.arrow_forward_ios_rounded, 
                size: 18, 
                color: Colors.grey.shade300
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- HELPERS ---

  Future<void> _navigateTo(BuildContext context, Widget screen) async {
    // Haptic feedback for "premium" feel
    HapticFeedback.lightImpact();

    // Check permissions before navigation
    final status = await Permission.camera.request();
    
    if (status.isGranted) {
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => screen),
        );
      }
    } else {
      if (context.mounted) {
        // iOS style Dialog
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Permission Required"),
            content: const Text("SIGHT needs camera access to perform this test."),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  openAppSettings();
                },
                child: const Text("Settings"),
              ),
            ],
          ),
        );
      }
    }
  }
}