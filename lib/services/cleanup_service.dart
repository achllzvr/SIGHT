import 'package:flutter/foundation.dart';

import 'active_child_context_service.dart';
import 'app_lifecycle_service.dart';
import 'detection_service.dart';
import 'gamification_service.dart';
import 'local_metrics_service.dart';
import 'metrics_service.dart';
import 'offline_models.dart';
import 'rule_engine_service.dart';
import 'task_service.dart';
import 'twenty_twenty_twenty_service.dart';

/// Orchestrates complete cleanup of all tracking and monitoring services
class CleanupService {
  CleanupService._private();
  static final CleanupService instance = CleanupService._private();

  /// Complete cleanup - stops all tracking, timers, services
  /// Call this when user logs out to prevent background tracking
  Future<void> performCompleteCleanup() async {
    if (kDebugMode) {
      debugPrint('[CleanupService] Starting complete cleanup...');
    }

    try {
      // 1. Stop detection and camera
      await DetectionService.instance.dispose();
      if (kDebugMode) {
        debugPrint('[CleanupService] ✓ DetectionService disposed');
      }

      // 2. Stop local metrics timers
      await LocalMetricsService.instance.dispose();
      if (kDebugMode) {
        debugPrint('[CleanupService] ✓ LocalMetricsService disposed');
      }

      // 3. Stop app lifecycle services (background heartbeat, reminders)
      await AppLifecycleService.instance.dispose();
      if (kDebugMode) {
        debugPrint('[CleanupService] ✓ AppLifecycleService disposed');
      }

      // 4. Stop task service timers
      TaskService.instance.dispose();
      if (kDebugMode) {
        debugPrint('[CleanupService] ✓ TaskService disposed');
      }

      // 5. Stop 20-20-20 break service
      TwentyTwentyBreakService.instance.dispose();
      if (kDebugMode) {
        debugPrint('[CleanupService] ✓ TwentyTwentyBreakService disposed');
      }

      // 6. Clear gamification notifiers
      GamificationService.instance.healthScoreNotifier.value = 100;
      GamificationService.instance.coinsNotifier.value = 0;
      GamificationService.instance.dailyStreakNotifier.value = 0;
      if (kDebugMode) {
        debugPrint('[CleanupService] ✓ GamificationService cleared');
      }

      // 7. Clear metrics notifiers
      MetricsService.instance.clearAllMetrics();
      if (kDebugMode) {
        debugPrint('[CleanupService] ✓ MetricsService cleared');
      }

      // 8. Clear active child context
      await ActiveChildContextService.instance.clearActiveChild();
      if (kDebugMode) {
        debugPrint('[CleanupService] ✓ ActiveChildContextService cleared');
      }

      // 9. Reset rule engine state
      RuleEngineService.instance.triggerOverlay(AlertLevel.none, 'session cleared');
      if (kDebugMode) {
        debugPrint('[CleanupService] ✓ RuleEngineService reset');
      }

      if (kDebugMode) {
        debugPrint('[CleanupService] ✅ Complete cleanup finished');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[CleanupService] ❌ Error during cleanup: $e');
      }
    }
  }

  /// Partial cleanup - used when switching child contexts
  /// Doesn't clear auth session
  Future<void> performPartialCleanup() async {
    if (kDebugMode) {
      debugPrint('[CleanupService] Starting partial cleanup...');
    }

    try {
      // Stop detection and metrics
      await DetectionService.instance.dispose();
      await LocalMetricsService.instance.dispose();

      // Clear metrics and gamification
      MetricsService.instance.clearAllMetrics();
      GamificationService.instance.healthScoreNotifier.value = 100;
      GamificationService.instance.coinsNotifier.value = 0;
      GamificationService.instance.dailyStreakNotifier.value = 0;

      // Clear active child context
      await ActiveChildContextService.instance.clearActiveChild();

      if (kDebugMode) {
        debugPrint('[CleanupService] ✅ Partial cleanup finished');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[CleanupService] ❌ Error during partial cleanup: $e');
      }
    }
  }
}
