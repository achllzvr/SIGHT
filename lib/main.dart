import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';

import 'widgets/bottom_pill_nav.dart';
import 'widgets/tracking_bubble.dart';
import 'widgets/lumi_game_kit.dart';
import 'widgets/animated_hue_background.dart';

import 'screens/auth/child_login_screen.dart';
import 'screens/auth/login_screen.dart';
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
import 'screens/twenty_twenty_twenty_break_screen.dart';

import 'screens/welcome_screen.dart';
import 'services/active_child_context_service.dart';
import 'services/auth_session_service.dart';
import 'services/detection_service.dart';
import 'services/session_timer_service.dart';
import 'services/gamification_service.dart';
import 'services/guardian_login_sync_service.dart';
import 'services/guardian_preferences_service.dart';
import 'services/guardian_setup_service.dart';
import 'services/local_metrics_service.dart';
import 'services/twenty_twenty_twenty_service.dart';
import 'services/offline_models.dart';
import 'services/rule_engine_service.dart';
import 'services/feedback_service.dart';
import 'services/app_lifecycle_service.dart';
import 'services/onboarding_service.dart';
import 'services/metrics_service.dart';
import 'services/watch_tracking_session.dart';
import 'screens/parent_onboarding_screen.dart';
import 'screens/child_setup_gate_screen.dart';
import 'theme/lumi_theme.dart';
import 'copy/lumi_strings.dart';
import 'widgets/arcade/arcade_icon.dart';

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
  
  // Allow portrait + landscape for Watch Area, tracking, and parent screens
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

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
          title: LumiStrings.brand,
          themeMode: currentMode,
          routes: {
            '/welcome': (_) => const WelcomeScreen(),
            '/auth': (_) => const ChildLoginScreen(),
            '/child': (_) => const RootApp(),
            '/guardian': (_) => const GuardianDashboardScreen(),
            '/guardian/child-dashboard': (_) => const GuardianChildDashboardScreen(),
            '/guardian-setup': (_) => const GuardianSetupScreen(mandatory: true),
            '/parent-onboarding': (_) => const ParentOnboardingScreen(),
            '/child-setup-gate': (_) => const ChildSetupGateScreen(),
            '/child-dashboard': (_) => const ChildDashboardScreen(),
            '/media-hub': (_) => const MediaHubScreen(),
            '/store': (_) => const StoreScreen(),
            '/daily-report': (_) => const DailyReportScreen(),
          },
          theme: LumiTheme.light(),
          darkTheme: LumiTheme.dark(),
          home: const _SessionRouter(),
          builder: (context, child) {
            return AnimatedHueBackground(
              child: child ?? const SizedBox.shrink(),
            );
          },
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
      // Ensure leftover active-child / token crumbs cannot affect a fresh start.
      await ActiveChildContextService.instance.clearActiveChild();
      return const WelcomeScreen();
    }

    if (session.role == AppUserRole.guardian) {
      final email = session.guardianEmail;
      if (email == null || email.isEmpty) {
        await AuthSessionService.instance.clearAllAuthState();
        await ActiveChildContextService.instance.clearActiveChild();
        return const WelcomeScreen();
      }

      // Parent sessions should never keep a child context hot.
      await ActiveChildContextService.instance.clearActiveChild();

      final sync = await GuardianLoginSyncService.instance.syncAfterLogin(email);
      if (!sync.success) {
        debugPrint('[SessionRouter] guardian resume sync failed: ${sync.message}');
        // Keep identity so they can retry login, but do not open the dashboard.
        return const LoginScreen();
      }
      final hasPin = await GuardianSetupService.instance.hasGuardianPin();
      if (!hasPin) {
        return const GuardianSetupScreen(mandatory: true);
      }
      final onboarded = await OnboardingService.instance.isParentOnboardingDone();
      return onboarded
          ? const GuardianDashboardScreen()
          : const ParentOnboardingScreen();
    }

    // Child session requires a login code (loadUserSession already enforces this).
    final code = session.childLoginCode;
    if (code == null || code.isEmpty) {
      await AuthSessionService.instance.clearAllAuthState();
      await ActiveChildContextService.instance.clearActiveChild();
      return const WelcomeScreen();
    }

    await ActiveChildContextService.instance.setActiveChildId(session.childId);

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
  bool _watchCameraAcquired = false;

  // MediaHub is rebuilt with [active] so WebView is torn down off-tab (M2).
  List<Widget> get _pages => [
    const HomeScreen(),
    MediaHubScreen(active: _index == 1),
    const TrackingScreen(),
    const TasksScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    RuleEngineService.instance.alertLevelNotifier.addListener(_handleAlertLevelChange);
    TwentyTwentyBreakService.instance.stateNotifier.addListener(_handleEyeRestStateChange);

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

    // Camera + notifications are requested during parent onboarding, not on child entry.
    try {
      unawaited(TwentyTwentyBreakService.instance.initialize(startDetection: false));
    } catch (e) {
      debugPrint('TwentyTwentyBreakService init error: $e');
    }

    _syncCameraForTab(_index);
  }

  @override
  void dispose() {
    SessionTimerService.instance.isTimeUpNotifier.removeListener(_onTimeUp);
    RuleEngineService.instance.alertLevelNotifier.removeListener(_handleAlertLevelChange);
    TwentyTwentyBreakService.instance.stateNotifier.removeListener(_handleEyeRestStateChange);
    WidgetsBinding.instance.removeObserver(this);
    if (_watchCameraAcquired) {
      unawaited(DetectionService.instance.releaseMonitoring());
      _watchCameraAcquired = false;
    }
    unawaited(DetectionService.instance.stopMonitoring());
    super.dispose();
  }

  bool _eyeRestRouteOpen = false;

  void _handleEyeRestStateChange() {
    if (!WatchTrackingSession.instance.active.value) {
      return;
    }
    final state = TwentyTwentyBreakService.instance.stateNotifier.value;
    if (state == BreakState.askingPermission && !_eyeRestRouteOpen && mounted) {
      _eyeRestRouteOpen = true;
      Navigator.of(context)
          .push(
            MaterialPageRoute(builder: (_) => const TwentyTwentyBreakScreen()),
          )
          .whenComplete(() async {
            _eyeRestRouteOpen = false;
            await _restoreWatchTrackingAfterIntervention();
          });
    }
  }

  void _onTimeUp() {
    if (SessionTimerService.instance.isTimeUpNotifier.value && mounted) {
      Navigator.of(context).pushReplacementNamed('/daily-report');
    }
  }

  Future<void> _restoreWatchTrackingAfterIntervention() async {
    if (!WatchTrackingSession.instance.active.value) return;
    RuleEngineService.instance.triggerOverlay(AlertLevel.none, 'intervention complete');
    MetricsService.instance.beginWatchEvaluationGrace();
    if (!_watchCameraAcquired) {
      await DetectionService.instance.acquireMonitoring(resolution: ResolutionPreset.low);
      _watchCameraAcquired = true;
    } else {
      await DetectionService.instance.ensureMonitoringWithRetry(resolution: ResolutionPreset.low);
    }
  }

  void _handleAlertLevelChange() {
    if (!WatchTrackingSession.instance.active.value) {
      return;
    }
    if (_pendingCriticalLockCheck || !mounted) {
      return;
    }

    if (RuleEngineService.instance.alertLevelNotifier.value != AlertLevel.screenLock) {
      return;
    }

    _pendingCriticalLockCheck = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        if (!mounted || !WatchTrackingSession.instance.active.value) {
          return;
        }

        if (RuleEngineService.instance.alertLevelNotifier.value == AlertLevel.screenLock) {
          await RuleEngineService.instance.triggerCriticalLock(
            context,
            skipIfJustCompleted: TwentyTwentyBreakService.instance.breakJustCompleted,
          );
          await _restoreWatchTrackingAfterIntervention();
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

  void _syncCameraForTab(int index) {
    // Watch Area (1) = tracking + penalties. Eyes (2) = camera only (no interventions).
    if (index == 1) {
      final wasActive = WatchTrackingSession.instance.active.value;
      WatchTrackingSession.instance.setActive(true);
      if (!wasActive) {
        TwentyTwentyBreakService.instance.resumeWatchSession();
        MetricsService.instance.beginWatchEvaluationGrace();
      }
      if (!_watchCameraAcquired) {
        _watchCameraAcquired = true;
        unawaited(
          DetectionService.instance.acquireMonitoring(resolution: ResolutionPreset.low),
        );
      } else {
        unawaited(
          DetectionService.instance.ensureMonitoringWithRetry(resolution: ResolutionPreset.low),
        );
      }
      unawaited(DetectionService.instance.enableWakelockForMonitoring());
    } else if (index == 2) {
      _deactivateWatchTracking();
      unawaited(
        DetectionService.instance.ensureMonitoringWithRetry(resolution: ResolutionPreset.medium),
      );
      unawaited(DetectionService.instance.disableWakelock());
    } else {
      _deactivateWatchTracking();
      unawaited(DetectionService.instance.disableWakelock());
      unawaited(DetectionService.instance.stopMonitoring());
    }
  }

  void _deactivateWatchTracking() {
    if (!WatchTrackingSession.instance.active.value && !_watchCameraAcquired) return;
    WatchTrackingSession.instance.setActive(false);
    TwentyTwentyBreakService.instance.pauseWatchSession();
    MetricsService.instance.clearLiveTrackingState();
    if (_watchCameraAcquired) {
      _watchCameraAcquired = false;
      unawaited(DetectionService.instance.releaseMonitoring());
    }
  }

  void _onNavTap(int i) {
    setState(() => _index = i);
    _syncCameraForTab(i);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('AppLifecycleState changed: $state');
    try {
      unawaited(AppLifecycleService.instance.trackScreenState(state));

      if (state == AppLifecycleState.resumed) {
        // Resume quietly — no Session Paused gate
        SessionTimerService.instance.startTracking();
      } else if (state == AppLifecycleState.inactive ||
          state == AppLifecycleState.paused ||
          state == AppLifecycleState.hidden) {
        SessionTimerService.instance.pauseTrackingQuietly();
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
          backgroundColor: Colors.transparent,
          body: SafeArea(
            bottom: false,
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
              return ColoredBox(
                color: Colors.transparent,
                child: SizedBox(
                  height: 110,
                  child: BottomPillNav(
                    currentIndex: _index,
                    onTap: _onNavTap,
                  ),
                ),
              );
            },
          ),
        ),
        if (_index != 0) TrackingBubble(currentPageIndex: _index),
        const _OfflineAlertOverlay(),
        ValueListenableBuilder<bool>(
          valueListenable: SessionTimerService.instance.showWrapUpWarningNotifier,
          builder: (_, showWarning, __) {
            if (!showWarning) return const SizedBox.shrink();
            return ValueListenableBuilder<int>(
              valueListenable: SessionTimerService.instance.remainingSecondsNotifier,
              builder: (_, seconds, __) {
                return Positioned.fill(
                  child: LumiInterventionModal(
                    title: '${LumiTheme.formatRemainingFriendly(seconds)} left!',
                    message:
                        'Finish early for +20 Stars, or keep watching — you\'re almost there!',
                    mascotAsset: 'assets/mascot/mascot_great_v1.png',
                    barrierColor: Colors.black54,
                    ignorePointer: false,
                    primaryLabel: 'FINISH NOW (+20 STARS)',
                    onPrimary: () => SessionTimerService.instance.wrapUpEarly(),
                    secondaryLabel: 'USE REMAINING TIME',
                    onSecondary: () => SessionTimerService.instance.ignoreWrapUp(),
                  ),
                );
              },
            );
          },
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
          ? 'Try a few blinks — you\'re doing great!'
          : alertLevel == AlertLevel.redOverlay
              ? LumiStrings.movePhoneFarther
              : 'Take a short rest for your eyes.';
    }

    switch (raw) {
      case 'face temporarily lost':
      case 'face not detected - critical tracking state':
        return 'I can\'t see you! Look at the screen so we can keep going.';
      case 'blink suppression detected':
        return 'Blink more with Lumi to keep watching.';
      case 'critical proximity detected':
        return LumiStrings.movePhoneFarther;
      case 'critical proximity or eye fatigue':
        return 'Your eyes need a short rest.';
      case 'adjust distance or blink rhythm':
        return 'Move the phone a little farther and blink.';
      case 'minor correction needed':
        return 'Small tip: blink and keep a safe distance.';
      default:
        return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: WatchTrackingSession.instance.active,
      builder: (_, trackingActive, __) {
        if (!trackingActive) {
          return const SizedBox.shrink();
        }
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

            if (alertLevel == AlertLevel.blinkBubble) {
              return Positioned(
                top: MediaQuery.of(context).padding.top + 12,
                left: 16,
                right: 16,
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                    color: LumiColors.primaryLight,
                    borderRadius: BorderRadius.circular(LumiRadii.pill),
                    border: Border.all(color: LumiColors.primaryPurple, width: ArcadeSizes.cardBorder),
                    boxShadow: LumiShadows.hard(color: LumiColors.primaryPurple, offset: const Offset(0, 4)),
                  ),
                  child: Row(
                    children: [
                      Image.asset(
                        'assets/mascot/mascot_head_v1.png',
                        width: 32,
                        height: 32,
                        errorBuilder: (_, __, ___) =>
                            const ArcadeIcon('like', size: 22),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: LumiTheme.clanMedium(13, color: LumiColors.textDark),
                        ),
                      ),
                    ],
                  ),
                  ),
                ),
              );
            }

            final isFaceLoss = RuleEngineService.instance.overlayMessageNotifier.value.contains('face');
            final title = alertLevel == AlertLevel.redOverlay
                ? (isFaceLoss ? 'Where did you go?' : 'Let\'s move back a little')
                : 'Blink with Lumi!';
            final mascot = alertLevel == AlertLevel.screenLock
                ? 'assets/mascot/mascot_great_v1.png'
                : 'assets/mascot/mascot_head_v1.png';
            final barrier = alertLevel == AlertLevel.redOverlay
                ? LumiColors.coralTrack.withValues(alpha: 0.38)
                : Colors.black.withValues(alpha: 0.35);

            return Positioned.fill(
              child: LumiInterventionModal(
                title: title,
                message: message,
                mascotAsset: mascot,
                barrierColor: barrier,
                ignorePointer: true,
              ),
            );
          },
        );
      },
    );
  }
}

// Dead _TimeLimitOverlay removed — daily lock uses DailyReportScreen.
