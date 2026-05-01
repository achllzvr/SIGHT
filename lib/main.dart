import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

import 'widgets/bottom_pill_nav.dart';
import 'widgets/tracking_bubble.dart';
import 'widgets/rounded_card.dart';

import 'screens/auth/auth_options_screen.dart';
import 'screens/add_children_screen.dart';
import 'screens/child_dashboard_screen.dart';
import 'screens/home_screen.dart';
import 'screens/tracking_screen.dart';
import 'screens/tasks_screen.dart';
import 'screens/media_hub_screen.dart';
import 'screens/guardian_setup_screen.dart';
import 'screens/guardian_dashboard_screen.dart';
import 'screens/guardian_child_dashboard_screen.dart';
import 'screens/store_screen.dart';
import 'screens/daily_report_screen.dart';

import 'screens/welcome_screen.dart';
import 'services/active_child_context_service.dart';
import 'services/auth_session_service.dart';
import 'services/session_timer_service.dart';
import 'services/gamification_service.dart';
import 'services/guardian_preferences_service.dart';
import 'services/guardian_setup_service.dart';
import 'services/local_metrics_service.dart';
import 'services/twenty_twenty_twenty_service.dart';
import 'services/offline_models.dart';
import 'services/rule_engine_service.dart';
import 'services/feedback_service.dart';
import 'services/app_lifecycle_service.dart';

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

  // Initialize feedback service
  await FeedbackService.instance.initialize();

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
            '/guardian': (_) => const GuardianDashboardScreen(),
            '/guardian/child-dashboard': (_) => const GuardianChildDashboardScreen(),
            '/guardian-setup': (_) => const GuardianSetupScreen(mandatory: true),
            '/add-child': (_) => const AddChildrenScreen(),
            '/child-dashboard': (_) => const ChildDashboardScreen(),
            '/media-hub': (_) => const MediaHubScreen(),
            '/store': (_) => const StoreScreen(),
            '/daily-report': (_) => const DailyReportScreen(),
          },
          
          // --- LIGHT THEME (Apple Style) ---
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF007AFF),
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
              seedColor: const Color(0xFF0A84FF),
              brightness: Brightness.dark,
              surface: const Color(0xFF1C1C1E),
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

class _ManualResumeOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black87,
        child: Center(
          child: RoundedCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Session Paused", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => SessionTimerService.instance.startTracking(),
                  child: const Text("Resume using LUMI"),
                )
              ],
            ),
          ),
        ),
      ),
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
          ? const GuardianDashboardScreen()
          : const GuardianSetupScreen(mandatory: true);
    }
    await ActiveChildContextService.instance.setActiveChildId(session.childId);
    
    // FIX: Force routing if time is up
    await SessionTimerService.instance.initialize();
    if (SessionTimerService.instance.remainingSecondsNotifier.value <= 0) {
      return const DailyReportScreen();
    }
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
  const RootApp({super.key});

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

    SessionTimerService.instance.isTimeUpNotifier.addListener(_onTimeUp);
    unawaited(LocalMetricsService.instance.initialize());
    unawaited(RuleEngineService.instance.initialize());
    unawaited(GamificationService.instance.initialize());
    unawaited(ActiveChildContextService.instance.initialize());

    // Initialize and start the session timer
    unawaited(SessionTimerService.instance.initialize().then((_) {
      SessionTimerService.instance.startTracking();
    }));

    unawaited(_initializeGuardianPolicyState());

    Permission.notification.request();

    // Initialize tracking services (only for child users - DetectionService initialized here)
    try {
      unawaited(TwentyTwentyBreakService.instance.initialize());
    } catch (e) {
      debugPrint('TwentyTwentyBreakService init error: $e');
    }

    // Background notification service removed (deprecated)
  }

  @override
  void dispose() {
    SessionTimerService.instance.isTimeUpNotifier.removeListener(_onTimeUp);
    RuleEngineService.instance.alertLevelNotifier.removeListener(_handleAlertLevelChange);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onTimeUp() {
    if (SessionTimerService.instance.isTimeUpNotifier.value && mounted) {
      Navigator.of(context).pushReplacementNamed('/daily-report');
    }
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
          await RuleEngineService.instance.triggerCriticalLock(
            context,
            skipIfJustCompleted: TwentyTwentyBreakService.instance.breakJustCompleted,
          );
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
      
      if (state == AppLifecycleState.resumed) {
        // Show the manual resume overlay
        SessionTimerService.instance.isPausedNotifier.value = true; 
      } else if (state == AppLifecycleState.inactive || 
                 state == AppLifecycleState.paused || 
                 state == AppLifecycleState.hidden) {
        // Ensure the timer is actually stopped in the service
        SessionTimerService.instance.pauseTracking(); 
      }
    } catch (e) {
      debugPrint('App lifecycle tracking error: $e');
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
        if (_index != 0) TrackingBubble(currentPageIndex: _index),
        const _OfflineAlertOverlay(),
        
        // NEW: The 2-Minute Wrap Up Warning
        ValueListenableBuilder<bool>(
          valueListenable: SessionTimerService.instance.showWrapUpWarningNotifier,
          builder: (_, showWarning, __) {
            if (!showWarning) return const SizedBox.shrink();
            return Positioned.fill(
              child: Container(
                color: Colors.black87,
                child: Center(
                  child: RoundedCard(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.timer, size: 48, color: Colors.orange),
                        const SizedBox(height: 16),
                        const Text("2 Minutes Left!", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        const Text(
                          "Wrap up now for a +20 Coin Early Bird Bonus, or use your remaining time.",
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () => SessionTimerService.instance.wrapUpEarly(),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7FC86D), foregroundColor: Colors.white),
                          child: const Text("Wrap Up Now (+20 Coins)"),
                        ),
                        TextButton(
                          onPressed: () => SessionTimerService.instance.ignoreWrapUp(),
                          child: const Text("Use Remaining Time", style: TextStyle(color: Colors.grey)),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),

        ValueListenableBuilder<bool>(
          valueListenable: SessionTimerService.instance.isPausedNotifier,
          builder: (_, isPaused, __) => isPaused ? _ManualResumeOverlay() : const SizedBox.shrink(),
        ),
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
        return 'Critical eye-strain threshold reached. Please take a rest.';
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

// ignore: unused_element
class _TimeLimitOverlay extends StatelessWidget {
  const _TimeLimitOverlay();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: SessionTimerService.instance.isTimeUpNotifier,
      builder: (_, isTimeUp, __) {
        if (!isTimeUp) return const SizedBox.shrink();

        final isDark = Theme.of(context).brightness == Brightness.dark;
        
        return Positioned.fill(
          child: Container(
            color: isDark ? Colors.black.withValues(alpha: 0.95) : Colors.white.withValues(alpha: 0.95),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.timer_off_outlined, size: 80, color: Color(0xFF8F5A88)),
                const SizedBox(height: 24),
                Text(
                  "Time's Up!",
                  style: TextStyle(
                    fontSize: 32, 
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black87
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "You've reached your daily screen limit.\nGreat job protecting your eyes today!",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16, 
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white70 : Colors.black54,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}