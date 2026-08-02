import 'package:flutter/material.dart';

import '../../theme/lumi_theme.dart';

/// Universal rounded rectangle card — grey border + hard downward shadow.
class ArcadeCard extends StatelessWidget {
  const ArcadeCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.onTap,
    this.clip = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      margin: margin,
      padding: padding,
      clipBehavior: clip ? Clip.antiAlias : Clip.none,
      decoration: BoxDecoration(
        color: LumiColors.primaryLight,
        borderRadius: BorderRadius.circular(ArcadeSizes.cardRadius),
        border: Border.all(color: LumiColors.secondaryLight, width: ArcadeSizes.cardBorder),
        boxShadow: LumiShadows.card(),
      ),
      child: child,
    );

    if (onTap == null) return card;
    return GestureDetector(onTap: onTap, child: card);
  }
}
