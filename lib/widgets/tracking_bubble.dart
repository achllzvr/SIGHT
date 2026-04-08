import 'dart:async';

import 'package:flutter/material.dart';

import '../services/metrics_service.dart';
import '../services/offline_models.dart';
import '../services/rule_engine_service.dart';

class TrackingBubble extends StatefulWidget {
  const TrackingBubble({super.key});

  @override
  State<TrackingBubble> createState() => _TrackingBubbleState();
}

class _TrackingBubbleState extends State<TrackingBubble> {
  Offset _offset = const Offset(18, 140);
  bool _expanded = false;
  Timer? _minuteTicker;
  DateTime _now = DateTime.now();

  static const double _collapsedSize = 68.0;
  static const double _expandedSize = 154.0;
  static const double _margin = 12.0;

  void _toggleExpanded() {
    setState(() {
      _expanded = !_expanded;
    });
  }

  @override
  void initState() {
    super.initState();
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
    final bubbleSize = _expanded ? _expandedSize : _collapsedSize;
    final leftSnap = _margin;
    final rightSnap = screenSize.width - bubbleSize - _margin;
    final topSnap = _offset.dy.clamp(MediaQuery.of(context).padding.top + _margin, screenSize.height - bubbleSize - _margin);
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

    return ValueListenableBuilder<int>(
      valueListenable: MetricsService.instance.blinkRatePerMinNotifier,
      builder: (_, blinkCount, __) {
        return ValueListenableBuilder<double>(
          valueListenable: MetricsService.instance.distanceCmNotifier,
          builder: (_, distanceCm, ___) {
            return ValueListenableBuilder<AlertLevel>(
              valueListenable: RuleEngineService.instance.alertLevelNotifier,
              builder: (_, alertLevel, ____) {
                final bubbleColor = _bubbleColor(distanceCm: distanceCm, alertLevel: alertLevel);
                final label = _statusLabel(distanceCm, alertLevel);

                return Positioned(
                  left: _offset.dx,
                  top: _offset.dy,
                  child: GestureDetector(
                    onTap: _toggleExpanded,
                    onPanUpdate: (details) {
                      setState(() {
                        _offset = Offset(
                          (_offset.dx + details.delta.dx).clamp(
                            _margin,
                            screenSize.width - (_expanded ? _expandedSize : _collapsedSize) - _margin,
                          ),
                          (_offset.dy + details.delta.dy).clamp(
                            MediaQuery.of(context).padding.top + _margin,
                            screenSize.height - (_expanded ? _expandedSize : _collapsedSize) - _margin,
                          ),
                        );
                      });
                    },
                    onPanEnd: (_) => _snapToNearestEdge(screenSize),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      width: _expanded ? _expandedSize : _collapsedSize,
                      height: _expanded ? _expandedSize : _collapsedSize,
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
                              width: _expanded ? _expandedSize : _collapsedSize,
                              height: _expanded ? _expandedSize : _collapsedSize,
                              child: CircularProgressIndicator(
                                value: minuteProgress,
                                strokeWidth: _expanded ? 6.0 : 4.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  alertLevel == AlertLevel.screenLock || alertLevel == AlertLevel.redOverlay
                                      ? const Color(0xFFD74E4E)
                                      : const Color(0xFF91C77A),
                                ),
                                backgroundColor: Colors.white.withOpacity(0.25),
                              ),
                            ),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 150),
                              child: _expanded
                                  ? Column(
                                      key: const ValueKey('bubble-expanded'),
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          height: 64,
                                          width: 120,
                                          child: Stack(
                                            clipBehavior: Clip.none,
                                            alignment: Alignment.topCenter,
                                            children: [
                                              Positioned(
                                                top: -6,
                                                child: Image.asset(
                                                  'assets/mascot/mascot_head_v1.png',
                                                  width: 118,
                                                  fit: BoxFit.contain,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          '$blinkCount',
                                          style: const TextStyle(
                                            fontSize: 30,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.black87,
                                            height: 1,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        const Text(
                                          'Blinks',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${distanceCm > 0 ? distanceCm.toStringAsFixed(1) : '--'} cm • $label',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ],
                                    )
                                  : Column(
                                      key: const ValueKey('bubble-collapsed'),
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          height: 36,
                                          width: 58,
                                          child: Stack(
                                            clipBehavior: Clip.none,
                                            alignment: Alignment.topCenter,
                                            children: [
                                              Positioned(
                                                top: -18,
                                                child: Image.asset(
                                                  'assets/mascot/mascot_head_v1.png',
                                                  width: 62,
                                                  fit: BoxFit.contain,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '$blinkCount',
                                          style: const TextStyle(
                                            fontSize: 26,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.black87,
                                            height: 1,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        const Text(
                                          'Blinks',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          label,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                            Positioned(
                              right: 6,
                              bottom: 6,
                              child: Container(
                                width: 10,
                                height: 10,
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