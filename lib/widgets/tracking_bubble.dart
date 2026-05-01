import 'dart:async';

import 'package:flutter/material.dart';

import '../main.dart';
import '../services/metrics_service.dart';
import '../services/offline_models.dart';
import '../services/rule_engine_service.dart';

class TrackingBubble extends StatefulWidget {
  final int currentPageIndex;
  
  const TrackingBubble({super.key, this.currentPageIndex = 0});

  @override
  State<TrackingBubble> createState() => _TrackingBubbleState();
}

class _TrackingBubbleState extends State<TrackingBubble> {
  Offset _offset = const Offset(18, 140);
  bool _expanded = false;
  Timer? _minuteTicker;
  DateTime _now = DateTime.now();

  static const double _margin = 12.0;

  void _toggleExpanded() {
    // On Media Hub screen (index 1), clicking bubble toggles fullscreen instead of expanding
    if (widget.currentPageIndex == 1) {
      mediaHubBubbleTapNotifier.value = !mediaHubBubbleTapNotifier.value;
      return;
    }
    
    // On other screens, toggle expanded state normally
    setState(() {
      _expanded = !_expanded;
    });
  }

  @override
  void initState() {
    super.initState();
    MetricsService.instance.ensureMinuteCounterActive();
    _minuteTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _now = DateTime.now();
      });
    });
  }

  void _snapToNearestEdge(Size screenSize) {
    // Calculate responsive sizes
    final responsiveCollapsedSize = (screenSize.width * 0.15).clamp(60.0, 80.0);
    final responsiveExpandedSize = (screenSize.width * 0.35).clamp(140.0, 180.0);
    final bubbleSize = _expanded ? responsiveExpandedSize : responsiveCollapsedSize;
    
    const leftSnap = _margin;
    final rightSnap = screenSize.width - bubbleSize - _margin;
    final topSnap = _offset.dy.clamp(
      MediaQuery.of(context).padding.top + _margin,
      screenSize.height - bubbleSize - _margin,
    );
    final snappedLeft = (_offset.dx + bubbleSize / 2) < (screenSize.width / 2) ? leftSnap : rightSnap;

    setState(() {
      _offset = Offset(snappedLeft, topSnap);
    });
  }

  @override
  void dispose() {
    _minuteTicker?.cancel();
    super.dispose();
  }

  Color _bubbleColor({required double distanceCm, required AlertLevel alertLevel}) {
    if (alertLevel == AlertLevel.screenLock || alertLevel == AlertLevel.redOverlay) {
      return const Color(0xFFFFE1E1);
    }

    if (distanceCm <= 0) {
      return const Color(0xFFF0F8E9);
    }

    return distanceCm >= 30.0 ? const Color(0xFFF0F8E9) : const Color(0xFFFFE1E1);
  }

  String _statusLabel(double distanceCm, AlertLevel alertLevel) {
    if (alertLevel == AlertLevel.screenLock) {
      return 'CRITICAL';
    }

    if (alertLevel == AlertLevel.redOverlay) {
      return 'UNSAFE';
    }

    if (distanceCm <= 0) {
      return 'CALIBRATING';
    }

    return distanceCm >= 30.0 ? 'SAFE' : 'CLOSE';
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final minuteProgress = ((_now.second + (_now.millisecond / 1000.0)) / 60.0).clamp(0.0, 1.0);
    final padding = MediaQuery.of(context).padding;

    // Make bubble sizes responsive to screen width - more aggressive constraints
    final responsiveCollapsedSize = (screenSize.width * 0.14).clamp(56.0, 76.0);
    final responsiveExpandedSize = (screenSize.width * 0.32).clamp(135.0, 165.0);

    return ValueListenableBuilder<int>(
      valueListenable: MetricsService.instance.currentMinuteBlinkCountNotifier,
      builder: (_, minuteBlinkCount, __) {
        return ValueListenableBuilder<double>(
          valueListenable: MetricsService.instance.distanceCmNotifier,
          builder: (_, distanceCm, ___) {
            return ValueListenableBuilder<AlertLevel>(
              valueListenable: RuleEngineService.instance.alertLevelNotifier,
              builder: (_, alertLevel, ____) {
                final bubbleColor = _bubbleColor(distanceCm: distanceCm, alertLevel: alertLevel);
                final label = _statusLabel(distanceCm, alertLevel);
                final bubbleSize = _expanded ? responsiveExpandedSize : responsiveCollapsedSize;

                return Positioned(
                  left: _offset.dx.clamp(_margin, screenSize.width - bubbleSize - _margin),
                  top: _offset.dy.clamp(padding.top + _margin, screenSize.height - bubbleSize - _margin),
                  child: GestureDetector(
                    onTap: _toggleExpanded,
                    onPanUpdate: (details) {
                      setState(() {
                        _offset = Offset(
                          (_offset.dx + details.delta.dx).clamp(
                            _margin,
                            screenSize.width - bubbleSize - _margin,
                          ),
                          (_offset.dy + details.delta.dy).clamp(
                            padding.top + _margin,
                            screenSize.height - bubbleSize - _margin,
                          ),
                        );
                      });
                    },
                    onPanEnd: (_) => _snapToNearestEdge(screenSize),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      width: bubbleSize,
                      height: bubbleSize,
                      decoration: BoxDecoration(
                        color: bubbleColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.black,
                          width: 2.1,
                        ),
                        boxShadow: const [
                          BoxShadow(color: Color(0x66000000), offset: Offset(4, 4), blurRadius: 14),
                          BoxShadow(color: Color(0x26FFFFFF), offset: Offset(-1, -1), blurRadius: 10),
                        ],
                      ),
                      child: Center(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: bubbleSize,
                              height: bubbleSize,
                              child: CircularProgressIndicator(
                                value: minuteProgress,
                                strokeWidth: _expanded ? 6.0 : 4.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  alertLevel == AlertLevel.screenLock || alertLevel == AlertLevel.redOverlay
                                      ? const Color(0xFFD74E4E)
                                      : const Color(0xFF91C77A),
                                ),
                                backgroundColor: Colors.white.withValues(alpha: 0.25),
                              ),
                            ),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 150),
                              child: _expanded
                                  ? Padding(
                                      key: const ValueKey('bubble-expanded'),
                                      padding: EdgeInsets.all(bubbleSize * 0.12),
                                      child: SingleChildScrollView(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              '$minuteBlinkCount',
                                              style: TextStyle(
                                                fontSize: bubbleSize * 0.22,
                                                fontWeight: FontWeight.w900,
                                                color: Colors.black87,
                                                height: 1,
                                              ),
                                            ),
                                            SizedBox(height: bubbleSize * 0.06),
                                            Text(
                                              'blinks',
                                              style: TextStyle(
                                                fontSize: bubbleSize * 0.11,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.black54,
                                              ),
                                            ),
                                            SizedBox(height: bubbleSize * 0.08),
                                            Container(
                                              padding: EdgeInsets.all(bubbleSize * 0.08),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withValues(alpha: 0.05),
                                                borderRadius: BorderRadius.circular(bubbleSize * 0.06),
                                              ),
                                              child: Text(
                                                '${distanceCm > 0 ? distanceCm.toStringAsFixed(1) : '--'} cm',
                                                style: TextStyle(
                                                  fontSize: bubbleSize * 0.09,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                            ),
                                            SizedBox(height: bubbleSize * 0.06),
                                            Text(
                                              label,
                                              style: TextStyle(
                                                fontSize: bubbleSize * 0.08,
                                                fontWeight: FontWeight.w600,
                                                color: alertLevel == AlertLevel.screenLock || alertLevel == AlertLevel.redOverlay
                                                    ? const Color(0xFFD74E4E)
                                                    : const Color(0xFF91C77A),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  : Column(
                                      key: const ValueKey('bubble-collapsed'),
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '$minuteBlinkCount',
                                          style: TextStyle(
                                            fontSize: bubbleSize * 0.40,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.black87,
                                            height: 1,
                                          ),
                                        ),
                                        Text(
                                          'blinks',
                                          style: TextStyle(
                                            fontSize: bubbleSize * 0.12,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                            Positioned(
                              right: bubbleSize * 0.08,
                              bottom: bubbleSize * 0.08,
                              child: Container(
                                width: bubbleSize * 0.15,
                                height: bubbleSize * 0.15,
                                decoration: BoxDecoration(
                                  color: alertLevel == AlertLevel.screenLock || alertLevel == AlertLevel.redOverlay
                                      ? const Color(0xFFD74E4E)
                                      : const Color(0xFF91C77A),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.black, width: 0.8),
                                ),
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
          },
        );
      },
    );
  }
}