import 'package:flutter/material.dart';

import '../../theme/lumi_theme.dart';
import 'arcade_icon.dart';

/// Top-bar pill with Arcade icon + optional number/text.
class ArcadeScoreBadge extends StatelessWidget {
  const ArcadeScoreBadge({
    super.key,
    required this.arcadeIcon,
    this.label,
    this.accentColor = LumiColors.badgeAmber,
    this.onTap,
    this.compact = false,
    this.expand = false,
  });

  final String arcadeIcon;
  final String? label;
  final Color accentColor;
  final VoidCallback? onTap;
  final bool compact;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final iconSize = compact ? 16.0 : ArcadeSizes.badgeIcon;
    final fontSize = compact ? 11.0 : ArcadeSizes.badgeFont;
    final padH = compact ? 8.0 : ArcadeSizes.badgePadH;

    return _ArcadePressable(
      onTap: onTap,
      child: Container(
        width: expand ? double.infinity : null,
        constraints: BoxConstraints(
          minHeight: compact ? 36 : ArcadeSizes.badgeHeight,
          maxWidth: expand ? double.infinity : double.infinity,
        ),
        padding: EdgeInsets.symmetric(horizontal: padH, vertical: ArcadeSizes.badgePadV),
        decoration: BoxDecoration(
          color: LumiColors.primaryLight,
          borderRadius: BorderRadius.circular(LumiRadii.pill),
          border: Border.all(color: accentColor, width: ArcadeSizes.badgeBorder),
          boxShadow: LumiShadows.badge(accentColor),
        ),
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ArcadeIcon(arcadeIcon, size: iconSize),
            if (label != null) ...[
              SizedBox(width: compact ? 4 : 6),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label!,
                    maxLines: 1,
                    softWrap: false,
                    style: LumiTheme.clanMedium(fontSize, color: accentColor, height: 1.1),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Top-bar icon-only pill (clothes, gear).
class ArcadeIconBadge extends StatelessWidget {
  const ArcadeIconBadge({
    super.key,
    required this.arcadeIcon,
    required this.accentColor,
    this.onTap,
    this.expand = false,
  });

  final String arcadeIcon;
  final Color accentColor;
  final VoidCallback? onTap;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    return _ArcadePressable(
      onTap: onTap,
      child: Container(
        width: expand ? double.infinity : 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: LumiColors.primaryLight,
          borderRadius: BorderRadius.circular(LumiRadii.pill),
          border: Border.all(color: accentColor, width: ArcadeSizes.badgeBorder),
          boxShadow: LumiShadows.badge(accentColor),
        ),
        child: ArcadeIcon(arcadeIcon, size: 20),
      ),
    );
  }
}

class _ArcadePressable extends StatefulWidget {
  const _ArcadePressable({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<_ArcadePressable> createState() => _ArcadePressableState();
}

class _ArcadePressableState extends State<_ArcadePressable> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap == null ? null : (_) => setState(() => _pressed = true),
      onTapUp: widget.onTap == null
          ? null
          : (_) {
              setState(() => _pressed = false);
              widget.onTap!();
            },
      onTapCancel: widget.onTap == null ? null : () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1,
        duration: LumiMotion.fast,
        curve: LumiMotion.easeStandard,
        child: AnimatedSlide(
          offset: _pressed ? const Offset(0, 0.04) : Offset.zero,
          duration: LumiMotion.fast,
          child: widget.child,
        ),
      ),
    );
  }
}
