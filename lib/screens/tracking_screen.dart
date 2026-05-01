import 'package:flutter/material.dart';

import '../blink_test_screen.dart';
import '../distance_test_screen.dart';
import '../services/detection_service.dart';
import '../services/metrics_service.dart';
import '../services/offline_models.dart';
import '../services/rule_engine_service.dart';
import '../widgets/rounded_card.dart';

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  @override
  void initState() {
    super.initState();
    DetectionService.instance.ensureMonitoringWithRetry();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  const _CameraStatusIndicator(),
                  const SizedBox(height: 12),
                  const _OfflineRuleBanner(),
                  const SizedBox(height: 24),
                  _TrackingStatCard(
                    title: 'Blink Analysis',
                    statusBuilder: (context) => const _StatusPill(label: 'GOOD'),
                    valueBuilder: (context) => ValueListenableBuilder<int>(
                      valueListenable: MetricsService.instance.blinkRatePerMinNotifier,
                      builder: (_, value, __) => Text(
                        '$value',
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF7FC86D),
                          height: 1,
                        ),
                      ),
                    ),
                    unitText: ' blinks per minute',
                    footnoteBuilder: (context) => ValueListenableBuilder<int>(
                      valueListenable: MetricsService.instance.blinkRatePerMinNotifier,
                      builder: (_, value, __) => Text(
                        'Good blinks per minute! $value/min',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFA68AC0),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const BlinkTestScreen()),
                    ).then((_) => DetectionService.instance.restartMonitoringWithDelay()),
                  ),
                  const SizedBox(height: 18),
                  _TrackingStatCard(
                    title: 'Screen Distance',
                    statusBuilder: (context) => ValueListenableBuilder<double>(
                      valueListenable: MetricsService.instance.distanceCmNotifier,
                      builder: (_, distance, __) => _StatusPill(
                        label: distance >= 30 ? 'SAFE' : (distance > 0 ? 'CLOSE' : 'SAFE'),
                      ),
                    ),
                    valueBuilder: (context) => ValueListenableBuilder<double>(
                      valueListenable: MetricsService.instance.distanceCmNotifier,
                      builder: (_, value, __) => Text(
                        value > 0 ? value.toStringAsFixed(0) : '--',
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF7FC86D),
                          height: 1,
                        ),
                      ),
                    ),
                    unitText: ' centimeters away',
                    footnoteBuilder: (context) => ValueListenableBuilder<double>(
                      valueListenable: MetricsService.instance.distanceCmNotifier,
                      builder: (_, value, __) => Text(
                        value > 0 ? 'Current distance: ${value.toStringAsFixed(1)}cm' : 'Tap to open distance monitor',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFA68AC0),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const DistanceTestScreen()),
                    ).then((_) => DetectionService.instance.restartMonitoringWithDelay()),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TrackingStatCard extends StatelessWidget {
  final String title;
  final WidgetBuilder statusBuilder;
  final WidgetBuilder valueBuilder;
  final String unitText;
  final WidgetBuilder footnoteBuilder;
  final VoidCallback onTap;

  const _TrackingStatCard({
    required this.title,
    required this.statusBuilder,
    required this.valueBuilder,
    required this.unitText,
    required this.footnoteBuilder,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: RoundedCard(
        borderRadius: 20,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                statusBuilder(context),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                valueBuilder(context),
                Text(
                  unitText,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.white60 : Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Align(alignment: Alignment.centerLeft, child: footnoteBuilder(context)),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  const _StatusPill({required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFEFD9EE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white70 : Colors.black54, width: 0.9),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _CameraStatusIndicator extends StatefulWidget {
  const _CameraStatusIndicator();

  @override
  State<_CameraStatusIndicator> createState() => _CameraStatusIndicatorState();
}

class _CameraStatusIndicatorState extends State<_CameraStatusIndicator> {
  @override
  void initState() {
    super.initState();
    _startRefresh();
  }

  Future<void> _startRefresh() async {
    while (mounted) {
      setState(() {});
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  @override
  Widget build(BuildContext context) {
    final frameFreshness = DetectionService.instance.millisSinceLastFrame;
    final hasReceivedAnyFrame = DetectionService.instance.hasReceivedAnyFrame;
    final hasFreshFrames = DetectionService.instance.hasFreshFrames;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: hasFreshFrames
            ? (isDark ? Colors.green.withValues(alpha: 0.15) : Colors.green.withValues(alpha: 0.1))
            : (isDark ? Colors.orange.withValues(alpha: 0.15) : Colors.orange.withValues(alpha: 0.1)),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasFreshFrames ? Colors.green.shade400 : Colors.orange.shade300,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: hasFreshFrames ? Colors.green.shade400 : Colors.orange.shade300,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              hasFreshFrames
                  ? 'Camera active (${frameFreshness}ms)'
                  : hasReceivedAnyFrame
                      ? 'Camera paused (${frameFreshness}ms)'
                      : 'Starting camera...',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: hasFreshFrames ? Colors.green.shade700 : Colors.orange.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OfflineRuleBanner extends StatelessWidget {
  const _OfflineRuleBanner();

  String _friendlyMessage(String raw, AlertLevel alertLevel) {
    if (raw.isEmpty) {
      return alertLevel == AlertLevel.none
          ? 'Monitoring is active.'
          : alertLevel == AlertLevel.blinkBubble
              ? 'A small blink correction is needed.'
              : alertLevel == AlertLevel.redOverlay
                  ? 'Please move the device a bit farther away.'
                  : 'Critical threshold reached. Guardian intervention required.';
    }

    switch (raw) {
      case 'face temporarily lost':
        return 'Face not detected. Keep your face centered in view.';
      case 'critical proximity or eye fatigue':
        return 'Critical threshold reached. Guardian intervention required.';
      case 'adjust distance or blink rhythm':
        return 'Move farther from the screen and blink naturally.';
      case 'minor correction needed':
        return 'Small correction needed for healthy viewing.';
      default:
        return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AlertLevel>(
      valueListenable: RuleEngineService.instance.alertLevelNotifier,
      builder: (_, alertLevel, __) {
        final message = _friendlyMessage(
          RuleEngineService.instance.overlayMessageNotifier.value,
          alertLevel,
        );
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final background = alertLevel == AlertLevel.none
            ? (isDark ? const Color(0xFF2C2C2E) : Colors.white)
            : alertLevel == AlertLevel.blinkBubble
                ? const Color(0xFFEFD9EE)
                : alertLevel == AlertLevel.redOverlay
                    ? const Color(0xFFFFE3E1)
                    : const Color(0xFFFFD6D2);

        final borderColor = isDark ? Colors.white70 : Colors.black87;
        final title = alertLevel == AlertLevel.none
            ? 'Monitoring'
            : alertLevel == AlertLevel.blinkBubble
                ? 'Blink Reminder'
                : alertLevel == AlertLevel.redOverlay
                    ? 'Distance Warning'
                    : 'Rest Mode';
        final icon = alertLevel == AlertLevel.none
            ? Icons.radar
            : alertLevel == AlertLevel.blinkBubble
                ? Icons.remove_red_eye_outlined
                : alertLevel == AlertLevel.redOverlay
                    ? Icons.warning_amber_rounded
                    : Icons.lock;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: 0.9),
            boxShadow: const [
              BoxShadow(color: Color(0xFFB9E3A4), offset: Offset(2, 2), blurRadius: 0),
              BoxShadow(color: Color(0xFFD5C2E8), offset: Offset(1, 1), blurRadius: 0),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, size: 19, color: Colors.black87),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      message,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.black87 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}