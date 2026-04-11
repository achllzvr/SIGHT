import 'dart:async';

import 'package:flutter/foundation.dart';

import 'active_child_context_service.dart';
import 'offline_database_service.dart';
import 'offline_models.dart';
import 'feedback_service.dart';

class GamificationService {
  GamificationService._private();
  static final GamificationService instance = GamificationService._private();

  final ValueNotifier<int> sessionXpNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> dailyStreakNotifier = ValueNotifier<int>(0);
  final ValueNotifier<PetMood> petMoodNotifier = ValueNotifier<PetMood>(PetMood.happy);

  bool _initialized = false;
  bool _isFlushingMinuteBuffer = false;

  Timer? _minuteBufferTimer;
  final List<double> _distanceSamples = <double>[];
  final List<int> _blinkRateSamples = <int>[];
  int _pendingHealthyBlinkXp = 0;
  int _pendingBreakXp = 0;

  static const int _safeDistanceAndBlinkXp = 1;
  static const int _harmfulDistanceXp = -1;
  static const int _healthyBlinkEventXp = 5;
  static const int _blinkSuppressionXp = -5;
  static const int _breakCompletedXp = 10;
  static const int _minuteWindowSeconds = 60;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    await OfflineDatabaseService.instance.initialize();
    final state = await OfflineDatabaseService.instance.loadGamificationState() ?? const GamificationState.defaults();
    sessionXpNotifier.value = state.sessionXp;
    dailyStreakNotifier.value = state.dailyStreak;
    petMoodNotifier.value = state.petMood;
    _startMinuteBufferTimer();
    _initialized = true;
  }

  void _startMinuteBufferTimer() {
    _minuteBufferTimer?.cancel();
    _minuteBufferTimer = Timer.periodic(const Duration(seconds: _minuteWindowSeconds), (_) {
      unawaited(_flushMinuteBuffer());
    });
  }

  Future<void> _persistState() async {
    await OfflineDatabaseService.instance.saveGamificationState(
      GamificationState(
        sessionXp: sessionXpNotifier.value,
        dailyStreak: dailyStreakNotifier.value,
        petMood: petMoodNotifier.value,
        lastComplianceDateIso: DateTime.now().toIso8601String(),
      ),
    );
  }

  int _calculateMinuteXp({required double averageDistanceCm, required double averageBlinkRatePerMin}) {
    int xp = 0;

    if (averageDistanceCm > 30.0 && averageBlinkRatePerMin > 10.0) {
      xp += _safeDistanceAndBlinkXp;
    }

    if (averageDistanceCm >= 10.0 && averageDistanceCm <= 30.0) {
      xp += _harmfulDistanceXp;
    }

    if (averageBlinkRatePerMin < 10.0) {
      xp += _blinkSuppressionXp;
    }

    return xp;
  }

  Future<void> updatePetState({required int complianceScore}) async {
    final mood = complianceScore >= 9
        ? PetMood.happy
        : complianceScore >= 5
            ? PetMood.sleeping
            : PetMood.sad;
    petMoodNotifier.value = mood;
    await _persistState();
  }

  Future<void> recordLiveSample({
    required double distanceCm,
    required int blinkRatePerMin,
    required bool faceDetected,
  }) async {
    await initialize();

    if (!faceDetected) {
      return;
    }

    if (distanceCm > 0) {
      _distanceSamples.add(distanceCm);
    }
    if (blinkRatePerMin >= 0) {
      _blinkRateSamples.add(blinkRatePerMin);
    }
  }

  Future<void> recordHealthyBlinkLogged() async {
    await initialize();
    _pendingHealthyBlinkXp += _healthyBlinkEventXp;
    // Note: No feedback on individual blinks to avoid overwhelming vibrations
  }

  Future<void> recordBreakCompleted202020() async {
    await initialize();
    _pendingBreakXp += _breakCompletedXp;
    // Provide success feedback for exercise completion
    FeedbackService.instance.exerciseCompleted();
  }

  Future<void> _flushMinuteBuffer() async {
    if (_isFlushingMinuteBuffer) {
      return;
    }
    _isFlushingMinuteBuffer = true;

    try {
      final averageDistance = _distanceSamples.isEmpty
          ? 0.0
          : _distanceSamples.reduce((a, b) => a + b) / _distanceSamples.length;
      final averageBlinkRate = _blinkRateSamples.isEmpty
          ? 0.0
          : _blinkRateSamples.reduce((a, b) => a + b) / _blinkRateSamples.length;

      int xp = _calculateMinuteXp(
        averageDistanceCm: averageDistance,
        averageBlinkRatePerMin: averageBlinkRate,
      );
      xp += _pendingHealthyBlinkXp;
      xp += _pendingBreakXp;

      // Provide feedback based on XP outcome
      if (xp < 0) {
        FeedbackService.instance.interventionTriggered();
      }

      sessionXpNotifier.value += xp;
      await updatePetState(complianceScore: xp);
      await _persistState();

      _distanceSamples.clear();
      _blinkRateSamples.clear();
      _pendingHealthyBlinkXp = 0;
      _pendingBreakXp = 0;
    } finally {
      _isFlushingMinuteBuffer = false;
    }
  }

  Future<bool> processWalletTransaction({
    required String itemKey,
    required String itemName,
    required int itemCost,
  }) async {
    await initialize();
    if (sessionXpNotifier.value < itemCost) {
      return false;
    }

    sessionXpNotifier.value -= itemCost;
    final childId = await ActiveChildContextService.instance.getActiveChildId();
    await OfflineDatabaseService.instance.addInventoryItem(
      childId: childId,
      itemKey: itemKey,
      itemName: itemName,
      cost: itemCost,
    );
    await _persistState();
    return true;
  }

  Future<int> evaluateDailyStreak({required bool dailyGoalMet}) async {
    await initialize();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final previousState = await OfflineDatabaseService.instance.loadGamificationState();
    final previousDate = DateTime.tryParse(previousState?.lastComplianceDateIso ?? '');

    if (!dailyGoalMet) {
      await _persistState();
      return dailyStreakNotifier.value;
    }

    if (previousDate != null) {
      final lastDay = DateTime(previousDate.year, previousDate.month, previousDate.day);
      if (lastDay == today) {
        return dailyStreakNotifier.value;
      }

      if (today.difference(lastDay).inDays == 1) {
        dailyStreakNotifier.value += 1;
      } else {
        dailyStreakNotifier.value = 1;
      }
    } else {
      dailyStreakNotifier.value = 1;
    }

    await _persistState();
    return dailyStreakNotifier.value;
  }
}