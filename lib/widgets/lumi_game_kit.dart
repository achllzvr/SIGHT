import 'package:flutter/material.dart';

import '../theme/lumi_theme.dart';
import 'arcade/arcade_button.dart';

/// Primary pressable button — arcade pill style.
class LumiPressButton extends StatefulWidget {
  const LumiPressButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.backgroundColor = LumiColors.secondaryPurple,
    this.foregroundColor,
    this.height = 48,
    this.fontSize = 16,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color backgroundColor;
  final Color? foregroundColor;
  final double height;
  final double fontSize;

  @override
  State<LumiPressButton> createState() => _LumiPressButtonState();
}

class _LumiPressButtonState extends State<LumiPressButton> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null;

  @override
  Widget build(BuildContext context) {
    final accent = LumiColors.primaryPurple;
    final fill = widget.backgroundColor == LumiColors.greenMid
        ? LumiColors.secondaryGreen
        : (widget.backgroundColor.computeLuminance() > 0.85
            ? LumiColors.secondaryPurple
            : widget.backgroundColor);

    return GestureDetector(
      onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: _enabled
          ? (_) {
              setState(() => _pressed = false);
              widget.onPressed?.call();
            }
          : null,
      onTapCancel: _enabled ? () => setState(() => _pressed = false) : null,
      child: AnimatedSlide(
        offset: _pressed && _enabled ? const Offset(0, 0.06) : Offset.zero,
        duration: LumiMotion.fast,
        child: AnimatedContainer(
          duration: LumiMotion.fast,
          curve: LumiMotion.easeStandard,
          width: double.infinity,
          height: widget.height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: !_enabled ? Colors.transparent : fill,
            borderRadius: BorderRadius.circular(LumiRadii.pill),
            border: Border.all(color: accent, width: ArcadeSizes.buttonBorder),
            boxShadow: !_enabled || _pressed ? const [] : LumiShadows.button(accent),
          ),
          child: Text(
            widget.label.toUpperCase(),
            style: LumiTheme.clanMedium(
              widget.fontSize,
              color: !_enabled ? accent.withValues(alpha: 0.5) : (widget.foregroundColor ?? accent),
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}

/// Soft elevated card surface.
class LumiGameCard extends StatelessWidget {
  const LumiGameCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(LumiSpacing.xl),
    this.backgroundColor = LumiColors.cardWhite,
    this.borderRadius = LumiRadii.lg,
    this.maxWidth,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color backgroundColor;
  final double borderRadius;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(ArcadeSizes.cardRadius),
        border: Border.all(color: LumiColors.secondaryLight, width: ArcadeSizes.cardBorder),
        boxShadow: LumiShadows.card(),
      ),
      child: child,
    );

    if (maxWidth == null) return card;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth!),
      child: card,
    );
  }
}

/// Mascot + tailed speech bubble for coaching / interventions.
class LumiSpeechBubble extends StatelessWidget {
  const LumiSpeechBubble({
    super.key,
    required this.message,
    this.mascotAsset = 'assets/mascot/mascot_head_v1.png',
    this.mascotSize = 72,
  });

  final String message;
  final String mascotAsset;
  final double mascotSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Image.asset(
          mascotAsset,
          width: mascotSize,
          height: mascotSize,
          errorBuilder: (_, __, ___) => Icon(Icons.pets, size: mascotSize * 0.7, color: LumiColors.greenMid),
        ),
        const SizedBox(width: LumiSpacing.md),
        Expanded(
          child: CustomPaint(
            painter: _BubbleTailPainter(color: LumiColors.cardWhite, border: LumiColors.outline),
            child: Container(
              margin: const EdgeInsets.only(left: 6),
              padding: const EdgeInsets.symmetric(horizontal: LumiSpacing.lg, vertical: 14),
              decoration: BoxDecoration(
                color: LumiColors.cardWhite,
                borderRadius: BorderRadius.circular(LumiRadii.lg),
                border: Border.all(color: LumiColors.outline, width: LumiColors.borderWidth),
                boxShadow: LumiShadows.card(),
              ),
              child: Text(
                message,
                style: LumiTheme.clanMedium(14, color: LumiColors.textDark, height: 1.35),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BubbleTailPainter extends CustomPainter {
  _BubbleTailPainter({required this.color, required this.border});
  final Color color;
  final Color border;

  @override
  void paint(Canvas canvas, Size size) {
    // Tail is approximated via layout; keep painter as no-op stub for API stability.
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Full-screen intervention: dimmed barrier + game card + mascot speech + optional CTAs.
class LumiInterventionModal extends StatelessWidget {
  const LumiInterventionModal({
    super.key,
    required this.title,
    required this.message,
    this.mascotAsset = 'assets/mascot/mascot_great_v1.png',
    this.barrierColor,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.ignorePointer = true,
    this.child,
  });

  final String title;
  final String message;
  final String mascotAsset;
  final Color? barrierColor;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final bool ignorePointer;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      color: barrierColor ?? LumiColors.modalOverlay,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(LumiSpacing.xl),
      child: LumiGameCard(
        maxWidth: 420,
        borderRadius: ArcadeSizes.cardRadius,
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              mascotAsset,
              height: 96,
              errorBuilder: (_, __, ___) => const Icon(Icons.pets, size: 72, color: LumiColors.greenMid),
            ),
            const SizedBox(height: LumiSpacing.lg),
            Text(
              LumiTheme.caps(title),
              textAlign: TextAlign.center,
              style: LumiTheme.joyful(24, color: LumiColors.textDark),
            ),
            const SizedBox(height: LumiSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: LumiTheme.clanRegular(14),
            ),
            if (child != null) ...[
              const SizedBox(height: LumiSpacing.lg),
              child!,
            ],
            if (primaryLabel != null) ...[
              const SizedBox(height: 18),
              ArcadeButton(
                text: primaryLabel!.toUpperCase(),
                onTap: onPrimary,
              ),
            ],
            if (secondaryLabel != null) ...[
              const SizedBox(height: LumiSpacing.md),
              ArcadeButton(
                text: secondaryLabel!.toUpperCase(),
                onTap: onSecondary,
                variant: ArcadeButtonVariant.outline,
              ),
            ],
          ],
        ),
      ),
    );

    if (ignorePointer) {
      return IgnorePointer(child: content);
    }
    return content;
  }
}
