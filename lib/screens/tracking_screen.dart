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
                        'Good blinks per minute! ${value}/min',
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
            ? (isDark ? Colors.green.withOpacity(0.15) : Colors.green.withOpacity(0.1))
            : (isDark ? Colors.orange.withOpacity(0.15) : Colors.orange.withOpacity(0.1)),
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

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AlertLevel>(
      valueListenable: RuleEngineService.instance.alertLevelNotifier,
      builder: (_, alertLevel, __) {
        final message = RuleEngineService.instance.overlayMessageNotifier.value;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final background = alertLevel == AlertLevel.none
            ? (isDark ? Colors.white10 : Colors.black12)
            : alertLevel == AlertLevel.blinkBubble
                ? const Color(0xFFEFD9EE)
                : alertLevel == AlertLevel.redOverlay
                    ? Colors.red.withOpacity(0.14)
                    : Colors.black.withOpacity(0.85);

        final label = alertLevel == AlertLevel.none ? 'Offline rules idle' : '${alertLevel.name} • ${message.isEmpty ? 'active' : message}';

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? Colors.white24 : Colors.black12),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: alertLevel == AlertLevel.screenLock ? Colors.white : null,
            ),
            textAlign: TextAlign.center,
          ),
        );
      },
    );
  }
}