import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';

enum FeedbackType {
  success,   // Task/exercise completion
  warning,   // Intervention triggered
  error,     // Negative action
  info,      // General feedback
  blink,     // Blink event
}

class FeedbackService {
  FeedbackService._private();
  static final FeedbackService instance = FeedbackService._private();

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _enabled = true;
  bool _hapticEnabled = true;
  bool _audioEnabled = true;

  Future<void> initialize() async {
    // Test if haptic feedback is available
    final canVibrate = await Vibration.hasVibrator();
    _hapticEnabled = canVibrate ?? false;

    if (kDebugMode) {
      debugPrint('[FeedbackService] Initialized - Haptic: $_hapticEnabled');
    }
  }

  /// Provide haptic feedback only
  Future<void> provideTactileFeedback(FeedbackType type) async {
    if (!_enabled || !_hapticEnabled) return;

    try {
      switch (type) {
        case FeedbackType.success:
          // Double tap - successful completion
          await Vibration.vibrate(duration: 50);
          await Future.delayed(const Duration(milliseconds: 100));
          await Vibration.vibrate(duration: 50);
          break;
        case FeedbackType.warning:
          // Medium vibration - warning/attention
          await Vibration.vibrate(duration: 100);
          break;
        case FeedbackType.error:
          // Long vibration - error
          await Vibration.vibrate(duration: 150);
          break;
        case FeedbackType.info:
          // Short vibration - info
          await Vibration.vibrate(duration: 30);
          break;
        case FeedbackType.blink:
          // Very short - blink event
          await Vibration.vibrate(duration: 20);
          break;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FeedbackService] Haptic error: $e');
      }
    }
  }

  /// Provide audio feedback only
  Future<void> provideAudioFeedback(FeedbackType type) async {
    if (!_enabled || !_audioEnabled) return;

    try {
      // Use system sounds via HapticFeedback for cross-platform compatibility
      switch (type) {
        case FeedbackType.success:
          // Success tone (higher pitch)
          await HapticFeedback.mediumImpact();
          break;
        case FeedbackType.warning:
          // Warning tone
          await HapticFeedback.mediumImpact();
          break;
        case FeedbackType.error:
          // Error tone
          await HapticFeedback.heavyImpact();
          break;
        case FeedbackType.info:
          // Info tone
          await HapticFeedback.lightImpact();
          break;
        case FeedbackType.blink:
          // Very subtle
          await HapticFeedback.lightImpact();
          break;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FeedbackService] Audio error: $e');
      }
    }
  }

  /// Provide combined haptic + audio feedback (recommended)
  Future<void> provideFeedback(FeedbackType type, {bool haptic = true, bool audio = true}) async {
    if (!_enabled) return;

    try {
      if (haptic && _hapticEnabled) {
        await provideTactileFeedback(type);
      }
      if (audio && _audioEnabled) {
        await provideAudioFeedback(type);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FeedbackService] Combined feedback error: $e');
      }
    }
  }

  /// Task completion feedback
  Future<void> taskCompleted() async {
    await provideFeedback(FeedbackType.success);
  }

  /// Intervention triggered feedback
  Future<void> interventionTriggered() async {
    await provideFeedback(FeedbackType.warning);
  }

  /// Blink event feedback (subtle)
  Future<void> blinkDetected() async {
    await provideFeedback(FeedbackType.blink, audio: false);
  }

  /// Exercise started feedback
  Future<void> exerciseStarted() async {
    await provideFeedback(FeedbackType.info);
  }

  /// Exercise completed feedback
  Future<void> exerciseCompleted() async {
    await provideFeedback(FeedbackType.success);
  }

  /// Negative action feedback
  Future<void> negativeAction() async {
    await provideFeedback(FeedbackType.error);
  }

  /// Enable/disable all feedback
  void setEnabled(bool enabled) {
    _enabled = enabled;
  }

  /// Enable/disable haptic feedback
  void setHapticEnabled(bool enabled) {
    _hapticEnabled = enabled;
  }

  /// Enable/disable audio feedback
  void setAudioEnabled(bool enabled) {
    _audioEnabled = enabled;
  }

  bool get isEnabled => _enabled;
  bool get isHapticEnabled => _hapticEnabled;
  bool get isAudioEnabled => _audioEnabled;

  void dispose() {
    _audioPlayer.dispose();
  }
}
