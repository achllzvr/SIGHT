import 'package:flutter/material.dart';

import '../blink_test_screen.dart';
import '../distance_test_screen.dart';
import '../services/detection_service.dart';
import '../services/metrics_service.dart';
import '../services/offline_models.dart';
import '../services/rule_engine_service.dart';
import '../theme/lumi_theme.dart';
import '../widgets/arcade/arcade.dart';

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: LumiSpacing.lg),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Row(
                      children: [
                        Expanded(child: _CameraStatusIndicator()),
                        SizedBox(width: LumiSpacing.sm),
                        Expanded(child: _OfflineRuleBanner()),
                      ],
                    ),
                    const SizedBox(height: LumiSpacing.xl),
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              LumiTheme.caps('Distance Monitor'),
                              textAlign: TextAlign.center,
                              style: LumiTheme.joyful(26, color: LumiColors.textDark),
                            ),
                            const SizedBox(height: LumiSpacing.lg),
                            _TrackingStatCard(
                              title: 'Eye Blinks',
                              statusBuilder: (context) => const _StatusPill(label: 'GOOD'),
                              valueBuilder: (context) => ValueListenableBuilder<int>(
                                valueListenable: MetricsService.instance.blinkRatePerMinNotifier,
                                builder: (_, value, __) => Text(
                                  '$value',
                                  style: LumiTheme.clanMedium(32, color: LumiColors.primaryGreen, height: 1),
                                ),
                              ),
                              unitText: ' blinks per minute',
                              footnoteBuilder: (context) => Text(
                                'Keep blinking — aim for 10 or more each minute',
                                style: LumiTheme.clanRegular(12),
                              ),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const BlinkTestScreen()),
                              ).then((_) => DetectionService.instance.restartMonitoringWithDelay()),
                            ),
                            const SizedBox(height: LumiSpacing.lg),
                            _TrackingStatCard(
                              title: 'Phone Distance',
                              statusBuilder: (context) => ValueListenableBuilder<double>(
                                valueListenable: MetricsService.instance.distanceCmNotifier,
                                builder: (_, distance, __) => _StatusPill(
                                  label: distance >= 30 ? 'SAFE' : (distance > 0 ? 'CLOSE' : 'SAFE'),
                                  safe: distance >= 30 || distance <= 0,
                                ),
                              ),
                              valueBuilder: (context) => ValueListenableBuilder<double>(
                                valueListenable: MetricsService.instance.distanceCmNotifier,
                                builder: (_, value, __) => Text(
                                  value > 0 ? value.toStringAsFixed(0) : '--',
                                  style: LumiTheme.clanMedium(32, color: LumiColors.primaryGreen, height: 1),
                                ),
                              ),
                              unitText: ' centimeters away',
                              footnoteBuilder: (context) => GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const DistanceTestScreen()),
                                ).then((_) => DetectionService.instance.restartMonitoringWithDelay()),
                                child: Text(
                                  'Recalibrate',
                                  style: LumiTheme.clanMedium(12, color: LumiColors.primaryGreen),
                                ),
                              ),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const DistanceTestScreen()),
                              ).then((_) => DetectionService.instance.restartMonitoringWithDelay()),
                            ),
                            const SizedBox(height: LumiSpacing.xl),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
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
    return ArcadeCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: LumiSpacing.lg, vertical: LumiSpacing.lg),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LumiTheme.clanMedium(18, color: LumiColors.textDark),
                ),
              ),
              statusBuilder(context),
            ],
          ),
          const SizedBox(height: LumiSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              valueBuilder(context),
              Flexible(
                child: Text(
                  unitText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LumiTheme.clanRegular(13),
                ),
              ),
            ],
          ),
          const SizedBox(height: LumiSpacing.md),
          Align(alignment: Alignment.centerLeft, child: footnoteBuilder(context)),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final bool safe;
  const _StatusPill({required this.label, this.safe = true});

  @override
  Widget build(BuildContext context) {
    final accent = safe ? LumiColors.primaryGreen : LumiColors.redAlert;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: LumiColors.primaryLight,
        borderRadius: BorderRadius.circular(LumiRadii.pill),
        border: Border.all(color: accent, width: 2),
        boxShadow: LumiShadows.hard(color: accent, offset: const Offset(0, 2)),
      ),
      child: Text(label, style: LumiTheme.clanMedium(10, color: accent, letterSpacing: 0.5)),
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
    final hasFreshFrames = DetectionService.instance.hasFreshFrames;
    final hasReceivedAnyFrame = DetectionService.instance.hasReceivedAnyFrame;
    final statusColor = hasFreshFrames ? LumiColors.primaryGreen : LumiColors.badgeAmber;
    final label = hasFreshFrames
        ? 'CAM ON'
        : hasReceivedAnyFrame
            ? 'CAM PAUSE'
            : 'CAM…';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: LumiColors.primaryLight,
        borderRadius: BorderRadius.circular(LumiRadii.pill),
        border: Border.all(color: statusColor, width: 2.5),
        boxShadow: LumiShadows.hard(color: statusColor, offset: const Offset(0, 3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label, style: LumiTheme.clanMedium(11, color: statusColor, height: 1)),
            ),
          ),
        ],
      ),
    );
  }
}

class _OfflineRuleBanner extends StatelessWidget {
  const _OfflineRuleBanner();

  String _shortMessage(String raw, AlertLevel alertLevel) {
    if (raw.isEmpty) {
      return alertLevel == AlertLevel.none
          ? 'Stable'
          : alertLevel == AlertLevel.blinkBubble
              ? 'Blink'
              : alertLevel == AlertLevel.redOverlay
                  ? 'Too close'
                  : 'Rest';
    }
    switch (raw) {
      case 'face temporarily lost':
        return 'No face';
      case 'critical proximity or eye fatigue':
        return 'Critical';
      case 'adjust distance or blink rhythm':
        return 'Adjust';
      case 'minor correction needed':
        return 'Nudge';
      default:
        return raw.length > 18 ? '${raw.substring(0, 16)}…' : raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AlertLevel>(
      valueListenable: RuleEngineService.instance.alertLevelNotifier,
      builder: (_, alertLevel, __) {
        final message = _shortMessage(
          RuleEngineService.instance.overlayMessageNotifier.value,
          alertLevel,
        );
        final accent = alertLevel == AlertLevel.none
            ? LumiColors.primaryGreen
            : alertLevel == AlertLevel.blinkBubble
                ? LumiColors.primaryPurple
                : alertLevel == AlertLevel.redOverlay
                    ? LumiColors.redAlert
                    : LumiColors.badgeAmber;
        final title = alertLevel == AlertLevel.none
            ? 'OK'
            : alertLevel == AlertLevel.blinkBubble
                ? 'BLINK'
                : alertLevel == AlertLevel.redOverlay
                    ? 'WARN'
                    : 'REST';

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: LumiColors.primaryLight,
            borderRadius: BorderRadius.circular(LumiRadii.pill),
            border: Border.all(color: accent, width: 2.5),
            boxShadow: LumiShadows.hard(color: accent, offset: const Offset(0, 3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(title, style: LumiTheme.clanMedium(11, color: accent, height: 1)),
                ),
              ),
              Container(
                width: 1,
                height: 12,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                color: accent.withValues(alpha: 0.35),
              ),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    message,
                    style: LumiTheme.clanRegular(11, color: LumiColors.textMuted, height: 1),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
