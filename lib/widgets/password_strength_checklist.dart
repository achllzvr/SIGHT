import 'package:flutter/material.dart';

import '../theme/lumi_theme.dart';
import '../utils/password_strength.dart';

/// Live checklist that shows what password rules are still needed vs complete.
class PasswordStrengthChecklist extends StatelessWidget {
  const PasswordStrengthChecklist({
    super.key,
    required this.password,
    required this.confirm,
    this.visible = true,
  });

  final String password;
  final String confirm;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();

    final result = evaluatePasswordStrength(password: password, confirm: confirm);
    final rows = <_ChecklistRowData>[
      _ChecklistRowData(
        done: result.hasMinLength,
        incomplete: 'At least 8 characters',
        complete: '8+ characters',
      ),
      _ChecklistRowData(
        done: result.hasLowercase,
        incomplete: 'Add a lowercase letter (a–z)',
        complete: 'Lowercase letter',
      ),
      _ChecklistRowData(
        done: result.hasUppercase,
        incomplete: 'Add an uppercase letter (A–Z)',
        complete: 'Uppercase letter',
      ),
      _ChecklistRowData(
        done: result.hasNumber,
        incomplete: 'Add a number (0–9)',
        complete: 'Number',
      ),
      _ChecklistRowData(
        done: result.hasSymbol,
        incomplete: 'Add a symbol (!@#\$…)',
        complete: 'Symbol',
      ),
      _ChecklistRowData(
        done: result.matchesConfirm,
        incomplete: 'Passwords must match',
        complete: 'Passwords match',
      ),
    ];

    final meterColor = result.complexityScore <= 1
        ? LumiColors.redAlert
        : result.complexityScore <= 3
            ? LumiColors.warning
            : LumiColors.success;

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: LumiSpacing.sm),
        padding: const EdgeInsets.all(LumiSpacing.md),
        decoration: BoxDecoration(
          color: LumiColors.scaffoldMint,
          borderRadius: BorderRadius.circular(LumiRadii.md),
          border: Border.all(color: LumiColors.secondaryLight, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Password strength: ${result.meterLabel}',
                    style: LumiTheme.clanMedium(13, color: meterColor),
                  ),
                ),
                Text(
                  '${result.complexityScore}/5',
                  style: LumiTheme.clanRegular(12, color: LumiColors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: LumiSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: result.complexityScore / 5,
                minHeight: 6,
                backgroundColor: LumiColors.secondaryLight.withValues(alpha: 0.45),
                color: meterColor,
              ),
            ),
            const SizedBox(height: LumiSpacing.md),
            ...rows.map((row) => _ChecklistRow(data: row)),
            if (result.isFullyValid) ...[
              const SizedBox(height: LumiSpacing.sm),
              Text(
                'Password looks good — all requirements met',
                style: LumiTheme.clanMedium(13, color: LumiColors.success),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChecklistRowData {
  const _ChecklistRowData({
    required this.done,
    required this.incomplete,
    required this.complete,
  });

  final bool done;
  final String incomplete;
  final String complete;
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({required this.data});

  final _ChecklistRowData data;

  @override
  Widget build(BuildContext context) {
    final color = data.done ? LumiColors.success : LumiColors.textMuted;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            data.done ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              data.done ? data.complete : data.incomplete,
              style: LumiTheme.clanRegular(13, color: color),
            ),
          ),
        ],
      ),
    );
  }
}
