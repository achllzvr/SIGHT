import 'package:flutter/material.dart';

import '../theme/lumi_theme.dart';
import 'arcade/arcade_card.dart';

/// Soft elevated card — now wraps [ArcadeCard] for child DS consistency.
class RoundedCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? primaryShadowColor;
  final Color? secondaryShadowColor;
  final Offset primaryShadowOffset;
  final Offset secondaryShadowOffset;
  const RoundedCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(LumiSpacing.lg),
    this.borderRadius = LumiRadii.lg,
    this.backgroundColor,
    this.borderColor,
    this.primaryShadowColor,
    this.secondaryShadowColor,
    this.primaryShadowOffset = const Offset(0, ArcadeSizes.cardShadowY),
    this.secondaryShadowOffset = Offset.zero,
  });

  @override
  Widget build(BuildContext context) {
    if (backgroundColor == null && borderColor == null) {
      return ArcadeCard(padding: padding, child: child);
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = backgroundColor ?? (isDark ? const Color(0xFF1E1A24) : LumiColors.cardWhite);
    final stroke = borderColor ?? LumiColors.secondaryLight;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: stroke, width: ArcadeSizes.cardBorder),
        boxShadow: LumiShadows.hard(
          color: primaryShadowColor ?? stroke,
          offset: primaryShadowOffset,
        ),
      ),
      child: child,
    );
  }
}
