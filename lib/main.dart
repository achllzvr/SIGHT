import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

import 'widgets/bottom_pill_nav.dart';
import 'widgets/tracking_bubble.dart';

import 'screens/auth/auth_options_screen.dart';
import 'screens/add_children_screen.dart';
import 'screens/child_dashboard_screen.dart';
import 'screens/connect_with_doctor_screen.dart';
import 'screens/home_screen.dart';
import 'screens/tracking_screen.dart';
import 'screens/tasks_screen.dart';
import 'screens/media_hub_screen.dart';
import 'screens/guardian_setup_screen.dart';
import 'screens/guardian_control_center_screen.dart';
import 'screens/welcome_screen.dart';
import 'services/app_lifecycle_service.dart';
import 'services/active_child_context_service.dart';
import 'services/auth_session_service.dart';
import 'services/background_notification_service.dart';
import 'services/detection_service.dart';
import 'services/gamification_service.dart';
import 'services/guardian_preferences_service.dart';
import 'services/guardian_setup_service.dart';
import 'services/local_metrics_service.dart';
import 'services/offline_models.dart';
import 'services/rule_engine_service.dart';

// Global Camera List
List<CameraDescription> cameras = [];

// Theme Notifier for Global Dark/Light Mode
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

// Media Hub Fullscreen Mode Notifier
final ValueNotifier<bool> mediaHubFullscreenNotifier = ValueNotifier(false);

// Media Hub Bubble Tap Notifier - used to communicate bubble taps to MediaHubScreen
final ValueNotifier<bool> mediaHubBubbleTapNotifier = ValueNotifier(false);

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
          routes: {
            '/welcome': (_) => const WelcomeScreen(),
            '/auth': (_) => const AuthOptionsScreen(),
            '/child': (_) => const RootApp(),
            '/guardian': (_) => const GuardianControlCenterScreen(),
            '/guardian-setup': (_) => const GuardianSetupScreen(mandatory: true),
            '/add-child': (_) => const AddChildrenScreen(),
            '/child-dashboard': (_) => const ChildDashboardScreen(),
            '/connect-doctor': (_) => const ConnectWithDoctorScreen(),
            '/media-hub': (_) => const MediaHubScreen(),
          },
          
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

          home: const _SessionRouter(),
        );
      },
    );
  }
}

class _SessionRouter extends StatefulWidget {
  const _SessionRouter();

  @override
  State<_SessionRouter> createState() => _SessionRouterState();
}

class _SessionRouterState extends State<_SessionRouter> {
  late final Future<Widget> _initialScreenFuture = _resolveInitialScreen();

  Future<Widget> _resolveInitialScreen() async {
    final session = await AuthSessionService.instance.loadUserSession();
    if (session == null) {
      return const WelcomeScreen();
    }

    if (session.role == AppUserRole.guardian) {
      final hasPin = await GuardianSetupService.instance.hasGuardianPin();
      return hasPin
          ? const GuardianControlCenterScreen()
          : const GuardianSetupScreen(mandatory: true);
    }

    await ActiveChildContextService.instance.setActiveChildId(session.childId);

    return const RootApp();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _initialScreenFuture,
      builder: (_, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return snapshot.data!;
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
  bool _pendingCriticalLockCheck = false;

  final List<Widget> _pages = const [
    HomeScreen(),
    MediaHubScreen(),
    TrackingScreen(),
    TasksScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    RuleEngineService.instance.alertLevelNotifier.addListener(_handleAlertLevelChange);

    unawaited(LocalMetricsService.instance.initialize());
    unawaited(RuleEngineService.instance.initialize());
    unawaited(GamificationService.instance.initialize());
    unawaited(ActiveChildContextService.instance.initialize());
    unawaited(_initializeGuardianPolicyState());

    Permission.notification.request();

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


  @override
  void dispose() {
    RuleEngineService.instance.alertLevelNotifier.removeListener(_handleAlertLevelChange);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _handleAlertLevelChange() {
    if (_pendingCriticalLockCheck || !mounted) {
      return;
    }

    if (RuleEngineService.instance.alertLevelNotifier.value != AlertLevel.screenLock) {
      return;
    }

    _pendingCriticalLockCheck = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        if (!mounted) {
          return;
        }

        if (RuleEngineService.instance.alertLevelNotifier.value == AlertLevel.screenLock) {
          await RuleEngineService.instance.triggerCriticalLock(context);
        }
      } finally {
        _pendingCriticalLockCheck = false;
      }
    });
  }

  Future<void> _initializeGuardianPolicyState() async {
    final preferences = await GuardianPreferencesService.instance.loadPreferences();
    await RuleEngineService.instance.applyGuardianPreferences(preferences);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('AppLifecycleState changed: $state');
    try {
      unawaited(AppLifecycleService.instance.trackScreenState(state));
    } catch (e) {
      debugPrint('BackgroundNotificationService lifecycle error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: SafeArea(
            child: IndexedStack(
              index: _index,
              children: _pages,
            ),
          ),
          bottomNavigationBar: ValueListenableBuilder<bool>(
            valueListenable: mediaHubFullscreenNotifier,
            builder: (_, isFullscreen, __) {
              if (isFullscreen) {
                return const SizedBox.shrink();
              }
              return SizedBox(
                height: 88,
                child: BottomPillNav(
                  currentIndex: _index,
                  onTap: (i) => setState(() => _index = i),
                ),
              );
            },
          ),
        ),
        // Only show TrackingBubble if not on home screen (index 0)
        if (_index != 0) TrackingBubble(currentPageIndex: _index),
        const _OfflineAlertOverlay(),
      ],
    );
  }
}

class _OfflineAlertOverlay extends StatelessWidget {
  const _OfflineAlertOverlay();

  String _friendlyMessage(String raw, AlertLevel alertLevel) {
    if (raw.isEmpty) {
      return alertLevel == AlertLevel.blinkBubble
          ? 'Try a few natural blinks.'
          : alertLevel == AlertLevel.redOverlay
              ? 'Please move the device a bit farther away.'
              : 'Time for a short rest to protect your eyes.';
    }

    switch (raw) {
      case 'face temporarily lost':
        return 'Face not detected. Hold the device steady and look at the screen.';
      case 'blink suppression detected':
        return 'Blink rhythm dropped below healthy range. Complete the blink reset to continue.';
      case 'critical proximity detected':
        return 'You are too close to the screen. Please move the device farther away.';
      case 'critical proximity or eye fatigue':
        return 'Critical eye-strain threshold reached. Guardian override is required.';
      case 'adjust distance or blink rhythm':
        return 'Move the screen farther and blink naturally.';
      case 'minor correction needed':
        return 'Small adjustment needed. Keep healthy blink rhythm.';
      default:
        return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AlertLevel>(
      valueListenable: RuleEngineService.instance.alertLevelNotifier,
      builder: (_, alertLevel, __) {
        if (alertLevel == AlertLevel.none) {
          return const SizedBox.shrink();
        }

        final message = _friendlyMessage(
          RuleEngineService.instance.overlayMessageNotifier.value,
          alertLevel,
        );
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final colorScheme = Theme.of(context).colorScheme;

        if (alertLevel == AlertLevel.blinkBubble) {
          return Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            right: 16,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark 
                    ? const Color(0xFF2A3A2A).withValues(alpha: 0.96)
                    : const Color(0xFFE3F1D6).withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? Colors.white70 : Colors.black87,
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFB9E3A4).withValues(alpha: 0.6),
                      offset: const Offset(2, 2),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                    BoxShadow(
                      color: const Color(0xFFD5C2E8).withValues(alpha: 0.4),
                      offset: const Offset(1, 1),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.remove_red_eye_outlined,
                      size: 20,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        message,
                        textAlign: TextAlign.left,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white70 : Colors.black87,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // For redOverlay and screenLock alerts
        late Color accentColor;
        late Color backgroundColor;
        late IconData alertIcon;
        late String alertTitle;

        if (alertLevel == AlertLevel.redOverlay) {
          accentColor = isDark ? const Color(0xFFFF6B6B) : const Color(0xFFFF3B30);
          backgroundColor = isDark ? Colors.black87 : Colors.white;
          alertIcon = Icons.warning_amber_rounded;
          alertTitle = 'Distance Warning';
        } else {
          // screenLock alert
          accentColor = isDark
              ? const Color(0xFF0A84FF)
              : const Color(0xFF007AFF);
          backgroundColor = isDark ? Colors.black87 : Colors.white;
          alertIcon = Icons.lock_outline_rounded;
          alertTitle = 'Time for a Break';
        }

        final overlayColor = alertLevel == AlertLevel.redOverlay
            ? (isDark
                ? Colors.red.withValues(alpha: 0.3)
                : Colors.red.withValues(alpha: 0.2))
            : (isDark
                ? Colors.black.withValues(alpha: 0.92)
                : Colors.black.withValues(alpha: 0.85));

        return Positioned.fill(
          child: IgnorePointer(
            child: Container(
              color: overlayColor,
              alignment: Alignment.center,
              padding: const EdgeInsets.all(24),
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 420),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFB9E3A4).withValues(alpha: 0.4),
                      offset: const Offset(3, 3),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: const Color(0xFFD5C2E8).withValues(alpha: 0.3),
                      offset: const Offset(1, 1),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(
                        alertIcon,
                        size: 40,
                        color: accentColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      alertTitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black54,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
