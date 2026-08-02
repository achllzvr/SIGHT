import 'package:flutter/material.dart';

import '../theme/lumi_theme.dart';
import 'arcade/arcade_card.dart';
import 'lumi_form.dart';

/// Arcade modal card.
class LumiDialog extends StatelessWidget {
  const LumiDialog({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
  });

  final String title;
  final Widget content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: ArcadeCard(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(LumiTheme.caps(title), style: LumiTheme.joyful(22, color: LumiColors.textDark)),
              const SizedBox(height: LumiSpacing.lg),
              content,
              const SizedBox(height: 18),
              ...actions,
            ],
          ),
        ),
      ),
    );
  }
}

Future<bool?> showLumiConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  String cancelLabel = 'Cancel',
  String confirmLabel = 'Confirm',
  Color confirmColor = LumiColors.primaryPurple,
  Color confirmForeground = Colors.white,
}) {
  return showDialog<bool>(
    context: context,
    barrierColor: LumiColors.modalOverlay,
    builder: (dialogContext) {
      return LumiDialog(
        title: title,
        content: Text(message, style: LumiTheme.clanRegular(14)),
        actions: [
          LumiPillButton(
            label: cancelLabel,
            onPressed: () => Navigator.of(dialogContext).pop(false),
            backgroundColor: LumiColors.cardWhite,
          ),
          const SizedBox(height: LumiSpacing.md),
          LumiPillButton(
            label: confirmLabel,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            backgroundColor: confirmColor,
            foregroundColor: confirmForeground,
          ),
        ],
      );
    },
  );
}
