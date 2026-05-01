import 'package:flutter/material.dart';

/// A rounded card with a thick ink-style outline and subtle dual shadow.
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
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 18,
    this.backgroundColor,
    this.borderColor,
    this.primaryShadowColor,
    this.secondaryShadowColor,
    this.primaryShadowOffset = const Offset(3, 3),
    this.secondaryShadowOffset = const Offset(1, 1),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = backgroundColor ?? (isDark ? const Color(0xFF1C1C1E) : Colors.white);
    final stroke = borderColor ?? (isDark ? Colors.white70 : Colors.black87);
    final shadow1 = primaryShadowColor ?? const Color(0xFFB9E3A4).withValues(alpha: 0.85);
    final shadow2 = secondaryShadowColor ?? const Color(0xFFD5C2E8).withValues(alpha: 0.85);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: stroke, width: 1.1),
        boxShadow: [
          BoxShadow(
            color: shadow1,
            offset: primaryShadowOffset,
            blurRadius: 0,
          ),
          BoxShadow(
            color: shadow2,
            offset: secondaryShadowOffset,
            blurRadius: 0,
          ),
        ],
      ),
      child: child,
    );
  }
}
