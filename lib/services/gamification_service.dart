import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';

import 'active_child_context_service.dart';
import 'offline_database_service.dart';
import 'offline_models.dart';
import 'feedback_service.dart';
import 'watch_tracking_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GamificationService {
  GamificationService._private();
  static final GamificationService instance = GamificationService._private();

  // === Dual-Loop Notifiers ===
  final ValueNotifier<int> healthScoreNotifier = ValueNotifier<int>(100);
  final ValueNotifier<int> coinsNotifier = ValueNotifier<int>(0);
  
  final ValueNotifier<int> dailyStreakNotifier = ValueNotifier<int>(0);
  final ValueNotifier<PetMood> petMoodNotifier = ValueNotifier<PetMood>(PetMood.happy);

  final ValueNotifier<String> mascotNameNotifier = ValueNotifier<String>('LUMI');
  final ValueNotifier<String?> equippedItemKeyNotifier = ValueNotifier<String?>(null);

  static const _equippedPrefsKey = 'lumi_equipped_item';

  Timer? _faceLossTimer;

  // Improvement #3: Deduct 0.2 HP per second when face is lost (Watch Area only)
  void startFaceLossPenalty() {
    if (!WatchTrackingSession.instance.active.value) {
      return;
    }
    _faceLossTimer?.cancel();
    _faceLossTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!WatchTrackingSession.instance.active.value) {
        timer.cancel();
        return;
      }
      double newHp = healthScoreNotifier.value - 0.2;
      healthScoreNotifier.value = newHp.clamp(0, 100).toInt();
      if (newHp <= 0) timer.cancel();
      _persistState();
    });
  }

  void stopFaceLossPenalty() {
    _faceLossTimer?.cancel();
  }

  // Improvement #5: Rename Mascot
  void renameMascot(String newName) {
    mascotNameNotifier.value = newName;
    _persistState();
  }

  bool _initialized = false;
  bool _isFlushingMinuteBuffer = false;
  Timer? _minuteBufferTimer;

  final List<double> _distanceSamples = <double>[];
  final List<int> _blinkRateSamples = <int>[];

  int _pendingHpRecovery = 0;
  int _pendingCoins = 0;

  // === Gamification tuning (Phase 4) ===
  // M1/M2 scale how harshly distance (diopters) and low blink rate drain HP per minute.
  // Rewards: break/blink exercises restore HP; safe viewing minutes earn Stars (coins).
  // Streak increments when all 3 daily eye-health goals complete (see TaskService).
  static const double _m1DioptricMultiplier = 4.0;
  static const double _m2BlinkMultiplier = 4.0;
  static const int _breakCompletedHpReward = 10;
  static const int _blinkExerciseHpReward = 5;
  static const int _safeMinuteCoinReward = 1;
  static const int dailyGoalCountForStreak = 3;

  static const int _minuteWindowSeconds = 60;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    await OfflineDatabaseService.instance.initialize();
    final state = await OfflineDatabaseService.instance.loadGamificationState() ?? const GamificationState.defaults();

    healthScoreNotifier.value = state.healthScore;
    coinsNotifier.value = state.coins;
    dailyStreakNotifier.value = state.dailyStreak;
    petMoodNotifier.value = state.petMood;
    mascotNameNotifier.value = state.mascotName;

    final prefs = await SharedPreferences.getInstance();
    equippedItemKeyNotifier.value = prefs.getString(_equippedPrefsKey);

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
        healthScore: healthScoreNotifier.value,
        coins: coinsNotifier.value,
        dailyStreak: dailyStreakNotifier.value,
        petMood: petMoodNotifier.value,
        lastComplianceDateIso: DateTime.now().toIso8601String(),
        mascotName: mascotNameNotifier.value,
      ),
    );
  }

  // === THE CLINICAL SCORING ALGORITHM ===
  int _calculateHpLoss({required double averageDistanceCm, required double averageBlinkRatePerMin}) {
    if (averageDistanceCm <= 0) return 0; // Ignore invalid/calibrating data

    // Step 1: Accommodative Demand (Diopters)
    final double demand = 100.0 / averageDistanceCm;

    // Step 2: Dioptric Penalty (Safe Baseline: 30cm = ~3.33 D)
    final double pDiopter = math.max(0.0, (demand - 3.33) * _m1DioptricMultiplier);

    // Step 3: Ocular Protection Deficit (Safe Baseline: 10 blinks/min)
    final double pBlink = math.max(0.0, (10.0 - averageBlinkRatePerMin) * _m2BlinkMultiplier);

    // Step 4: Total HP Deduction
    return (pDiopter + pBlink).round();
  }

  Future<void> updatePetState() async {
    final hp = healthScoreNotifier.value;
    
    final mood = hp >= 70
        ? PetMood.happy
        : hp >= 30
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
    if (!WatchTrackingSession.instance.active.value) {
      return;
    }
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

  // === Hooks for 20-20-20 & Blink Tests ===
  Future<void> recordHealthyBlinkLogged() async {
    await initialize();
    // Handled in bulk by blink exercises, but hook remains open.
  }

  Future<void> recordBreakCompleted202020() async {
    await initialize();
    _pendingHpRecovery += _breakCompletedHpReward;
    FeedbackService.instance.exerciseCompleted();
  }
  
  Future<void> recordBlinkExerciseCompleted() async {
    await initialize();
    _pendingHpRecovery += _blinkExerciseHpReward;
    FeedbackService.instance.exerciseCompleted();
  }

  Future<void> _flushMinuteBuffer() async {
    if (_isFlushingMinuteBuffer) {
      return;
    }
    _isFlushingMinuteBuffer = true;

    try {
      // Only apply Watch-Area tracking damage while session is active.
      // Still allow pending recovery/coins from exercises breaks.
      final trackingActive = WatchTrackingSession.instance.active.value;

      final averageDistance = (!trackingActive || _distanceSamples.isEmpty)
          ? 0.0
          : _distanceSamples.reduce((a, b) => a + b) / _distanceSamples.length;

      final averageBlinkRate = (!trackingActive || _blinkRateSamples.isEmpty)
          ? 0.0
          : _blinkRateSamples.reduce((a, b) => a + b) / _blinkRateSamples.length;

      final int hpLoss = trackingActive
          ? _calculateHpLoss(
              averageDistanceCm: averageDistance,
              averageBlinkRatePerMin: averageBlinkRate,
            )
          : 0;

      int coinsEarned = 0;
      if (trackingActive && hpLoss == 0 && _distanceSamples.isNotEmpty) {
        coinsEarned = _safeMinuteCoinReward;
      }

      int newHp = healthScoreNotifier.value - hpLoss + _pendingHpRecovery;
      newHp = newHp.clamp(0, 100);

      if (hpLoss > 0) {
        FeedbackService.instance.interventionTriggered();
      }

      healthScoreNotifier.value = newHp;
      coinsNotifier.value += coinsEarned + _pendingCoins;

      await updatePetState();
      await _persistState();

      _distanceSamples.clear();
      _blinkRateSamples.clear();
      _pendingHpRecovery = 0;
      _pendingCoins = 0;
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
    if (coinsNotifier.value < itemCost) {
      return false;
    }
    coinsNotifier.value -= itemCost;
    
    final childId = await ActiveChildContextService.instance.getActiveChildId();
    await OfflineDatabaseService.instance.addInventoryItem(
      childId: childId,
      itemKey: itemKey,
      itemName: itemName,
      cost: itemCost,
    );

    await equipItem(itemKey);
    await _persistState();
    return true;
  }

  Future<bool> ownsItem(String itemKey) async {
    await initialize();
    final childId = await ActiveChildContextService.instance.getActiveChildId();
    return OfflineDatabaseService.instance.hasInventoryItem(childId: childId, itemKey: itemKey);
  }

  Future<void> equipItem(String itemKey) async {
    await initialize();
    equippedItemKeyNotifier.value = itemKey;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_equippedPrefsKey, itemKey);
  }

  Future<void> unequipItem() async {
    equippedItemKeyNotifier.value = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_equippedPrefsKey);
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