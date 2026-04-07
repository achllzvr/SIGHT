import 'package:flutter/foundation.dart';

import 'active_child_context_service.dart';
import 'offline_database_service.dart';
import 'offline_models.dart';

class GamificationService {
  GamificationService._private();
  static final GamificationService instance = GamificationService._private();

  final ValueNotifier<int> sessionXpNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> dailyStreakNotifier = ValueNotifier<int>(0);
  final ValueNotifier<PetMood> petMoodNotifier = ValueNotifier<PetMood>(PetMood.happy);

  DateTime? _lastXpAwardAt;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    await OfflineDatabaseService.instance.initialize();
    final state = await OfflineDatabaseService.instance.loadGamificationState() ?? const GamificationState.defaults();
    sessionXpNotifier.value = state.sessionXp;
    dailyStreakNotifier.value = state.dailyStreak;
    petMoodNotifier.value = state.petMood;
    _initialized = true;
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

  int calculateSessionXP({
    required double distanceCm,
    required int blinkRatePerMin,
    required bool faceDetected,
    Duration activeDuration = Duration.zero,
  }) {
    int xp = 0;

    if (faceDetected) {
      xp += 3;
    }

    if (distanceCm >= 30.0) {
      xp += 5;
    } else if (distanceCm >= 25.0) {
      xp += 3;
    }

    if (blinkRatePerMin >= 10) {
      xp += 4;
    } else if (blinkRatePerMin >= 6) {
      xp += 2;
    }

    xp += activeDuration.inMinutes;
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

    final now = DateTime.now();
    if (_lastXpAwardAt != null && now.difference(_lastXpAwardAt!) < const Duration(seconds: 30)) {
      return;
    }

    _lastXpAwardAt = now;
    final xp = calculateSessionXP(
      distanceCm: distanceCm,
      blinkRatePerMin: blinkRatePerMin,
      faceDetected: faceDetected,
      activeDuration: const Duration(minutes: 1),
    );
    sessionXpNotifier.value += xp;
    await updatePetState(complianceScore: xp);
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