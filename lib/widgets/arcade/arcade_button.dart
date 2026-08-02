import 'package:flutter/material.dart';

import '../../theme/lumi_theme.dart';

enum ArcadeButtonVariant { primary, outline, soft }

/// Arcade pill button — primary (fill+shadow), outline (inactive), soft (fill no shadow).
class ArcadeButton extends StatefulWidget {
  const ArcadeButton({
    super.key,
    required this.text,
    this.onTap,
    this.variant = ArcadeButtonVariant.primary,
    this.expand = true,
    this.fontSize,
  });

  final String text;
  final VoidCallback? onTap;
  final ArcadeButtonVariant variant;
  final bool expand;
  final double? fontSize;

  @override
  State<ArcadeButton> createState() => _ArcadeButtonState();
}

class _ArcadeButtonState extends State<ArcadeButton> {
  bool _pressed = false;

  bool get _enabled => widget.onTap != null;

  @override
  Widget build(BuildContext context) {
    final accent = LumiColors.primaryPurple;
    final fill = switch (widget.variant) {
      ArcadeButtonVariant.primary => LumiColors.secondaryPurple,
      ArcadeButtonVariant.soft => LumiColors.secondaryPurple,
      ArcadeButtonVariant.outline => Colors.transparent,
    };
    final showShadow = widget.variant == ArcadeButtonVariant.primary && _enabled && !_pressed;

    final child = AnimatedContainer(
      duration: LumiMotion.fast,
      curve: LumiMotion.easeStandard,
      width: widget.expand ? double.infinity : null,
      padding: const EdgeInsets.symmetric(
        horizontal: ArcadeSizes.buttonPadH,
        vertical: ArcadeSizes.buttonPadV,
      ),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(LumiRadii.pill),
        border: Border.all(color: accent, width: ArcadeSizes.buttonBorder),
        boxShadow: showShadow ? LumiShadows.button(accent) : const [],
      ),
      child: Text(
        widget.text,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: LumiTheme.clanMedium(
          widget.fontSize ?? ArcadeSizes.buttonFont,
          color: accent,
          letterSpacing: 1.2,
        ),
      ),
    );

    return GestureDetector(
      onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: _enabled
          ? (_) {
              setState(() => _pressed = false);
              widget.onTap?.call();
            }
          : null,
      onTapCancel: _enabled ? () => setState(() => _pressed = false) : null,
      child: AnimatedSlide(
        offset: _pressed && widget.variant == ArcadeButtonVariant.primary
            ? const Offset(0, 0.06)
            : Offset.zero,
        duration: LumiMotion.fast,
        child: child,
      ),
    );
  }
}
