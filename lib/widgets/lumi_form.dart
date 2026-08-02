import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/lumi_theme.dart';
import 'arcade/arcade_button.dart';
import 'arcade/arcade_fields.dart';

/// Shared field — arcade pill inputs.
class LumiPillField extends StatelessWidget {
  const LumiPillField({
    super.key,
    required this.label,
    required this.controller,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.maxLength,
    this.inputFormatters,
    this.errorText,
  });

  final String label;
  final TextEditingController controller;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return ArcadeTextField(
      label: label,
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
      errorText: errorText,
    );
  }
}

class LumiPillButton extends StatelessWidget {
  const LumiPillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.backgroundColor,
    this.foregroundColor,
  });

  final String label;
  final VoidCallback? onPressed;
  /// Legacy color hint — mapped to arcade variants.
  final Color? backgroundColor;
  final Color? foregroundColor;

  ArcadeButtonVariant get _variant {
    if (onPressed == null) return ArcadeButtonVariant.outline;
    final bg = backgroundColor;
    if (bg == null) return ArcadeButtonVariant.primary;
    if (bg == LumiColors.cardWhite || bg == Colors.white || bg == LumiColors.primaryLight) {
      return ArcadeButtonVariant.outline;
    }
    if (bg == LumiColors.purpleSoft || bg == LumiColors.secondaryPurple || bg == LumiColors.greenSoft) {
      return ArcadeButtonVariant.soft;
    }
    return ArcadeButtonVariant.primary;
  }

  @override
  Widget build(BuildContext context) {
    return ArcadeButton(
      text: label.toUpperCase(),
      onTap: onPressed,
      variant: _variant,
    );
  }
}

class LumiPrimaryButton extends StatelessWidget {
  const LumiPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return ArcadeButton(
      text: label.toUpperCase(),
      onTap: onPressed,
      variant: ArcadeButtonVariant.primary,
    );
  }
}

class LumiSecondaryButton extends StatelessWidget {
  const LumiSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return ArcadeButton(
      text: label.toUpperCase(),
      onTap: onPressed,
      variant: ArcadeButtonVariant.outline,
    );
  }
}
