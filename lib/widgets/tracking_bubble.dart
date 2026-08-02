import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../services/metrics_service.dart';
import '../services/session_timer_service.dart';
import '../theme/lumi_theme.dart';
import 'arcade/arcade_icon.dart';

enum _BubbleMode {
  compactTime,
  expandedTime,
  compactBlinks,
  expandedBlinks,
}

/// Draggable arcade status bubble.
/// Tap cycles: Compact Time → Expanded Time → Compact Blinks → Expanded Blinks.
/// Long-press (Play Area): open media controls.
class TrackingBubble extends StatefulWidget {
  final int currentPageIndex;

  const TrackingBubble({super.key, this.currentPageIndex = 0});

  @override
  State<TrackingBubble> createState() => _TrackingBubbleState();
}

class _TrackingBubbleState extends State<TrackingBubble> {
  Offset _offset = const Offset(18, 140);
  _BubbleMode _mode = _BubbleMode.compactTime;

  static const double _margin = 12.0;
  static const double _compactSize = 56.0;
  static const double _expandedW = 148.0;
  static const double _expandedH = 72.0;

  bool get _expanded =>
      _mode == _BubbleMode.expandedTime || _mode == _BubbleMode.expandedBlinks;

  bool get _showingTime =>
      _mode == _BubbleMode.compactTime || _mode == _BubbleMode.expandedTime;

  double get _w => _expanded ? _expandedW : _compactSize;
  double get _h => _expanded ? _expandedH : _compactSize;

  void _onTap() {
    setState(() {
      _mode = switch (_mode) {
        _BubbleMode.compactTime => _BubbleMode.expandedTime,
        _BubbleMode.expandedTime => _BubbleMode.compactBlinks,
        _BubbleMode.compactBlinks => _BubbleMode.expandedBlinks,
        _BubbleMode.expandedBlinks => _BubbleMode.compactTime,
      };
    });
  }

  void _onLongPress() {
    HapticFeedback.mediumImpact();
    if (widget.currentPageIndex == 1) {
      mediaHubBubbleTapNotifier.value = !mediaHubBubbleTapNotifier.value;
    }
  }

  void _snapToNearestEdge(Size screenSize) {
    const leftSnap = _margin;
    final rightSnap = screenSize.width - _w - _margin;
    final topSnap = _offset.dy.clamp(
      MediaQuery.of(context).padding.top + _margin,
      screenSize.height - _h - _margin,
    );
    final snappedLeft =
        (_offset.dx + _w / 2) < (screenSize.width / 2) ? leftSnap : rightSnap;

    setState(() => _offset = Offset(snappedLeft, topSnap));
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;
    final accent = _showingTime ? LumiColors.primaryPurple : LumiColors.primaryGreen;

    return Positioned(
      left: _offset.dx.clamp(_margin, screenSize.width - _w - _margin),
      top: _offset.dy.clamp(padding.top + _margin, screenSize.height - _h - _margin),
      child: GestureDetector(
        onTap: _onTap,
        onLongPress: _onLongPress,
        onPanUpdate: (details) {
          setState(() {
            _offset = Offset(
              (_offset.dx + details.delta.dx).clamp(_margin, screenSize.width - _w - _margin),
              (_offset.dy + details.delta.dy).clamp(
                padding.top + _margin,
                screenSize.height - _h - _margin,
              ),
            );
          });
        },
        onPanEnd: (_) => _snapToNearestEdge(screenSize),
        child: AnimatedContainer(
          duration: LumiMotion.normal,
          curve: LumiMotion.easeStandard,
          width: _w,
          height: _h,
          padding: EdgeInsets.symmetric(
            horizontal: _expanded ? 12 : 6,
            vertical: _expanded ? 10 : 6,
          ),
          decoration: BoxDecoration(
            color: LumiColors.primaryLight,
            borderRadius: BorderRadius.circular(LumiRadii.pill),
            border: Border.all(color: accent, width: ArcadeSizes.badgeBorder),
            boxShadow: LumiShadows.badge(accent),
          ),
          child: ValueListenableBuilder<int>(
            valueListenable: SessionTimerService.instance.remainingSecondsNotifier,
            builder: (_, seconds, __) {
              return ValueListenableBuilder<int>(
                valueListenable: MetricsService.instance.blinkRatePerMinNotifier,
                builder: (_, blinks, __) {
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 320),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      final slide = Tween<Offset>(
                        begin: const Offset(0, 0.28),
                        end: Offset.zero,
                      ).animate(animation);
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(position: slide, child: child),
                      );
                    },
                    child: _BubbleMetric(
                      key: ValueKey(_mode),
                      icon: _showingTime ? 'timer' : 'eye',
                      value: _showingTime ? LumiTheme.formatRemaining(seconds) : '$blinks',
                      caption: _showingTime ? 'TIME LEFT' : 'BLINKS/MIN',
                      accent: accent,
                      expanded: _expanded,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _BubbleMetric extends StatelessWidget {
  const _BubbleMetric({
    super.key,
    required this.icon,
    required this.value,
    required this.caption,
    required this.accent,
    required this.expanded,
  });

  final String icon;
  final String value;
  final String caption;
  final Color accent;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    if (!expanded) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ArcadeIcon(icon, size: 16),
          const SizedBox(height: 2),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                maxLines: 1,
                style: LumiTheme.clanMedium(10, color: accent, height: 1),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ArcadeIcon(icon, size: 18),
            const SizedBox(width: 6),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  maxLines: 1,
                  style: LumiTheme.clanMedium(16, color: accent, height: 1),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          caption,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: LumiTheme.clanRegular(9, color: LumiColors.textMuted, height: 1),
        ),
      ],
    );
  }
}
