import 'package:flutter/material.dart';

import '../../../theme/lumi_theme.dart';
import '../../../widgets/arcade/arcade.dart';

/// Arcade section heading — Super Joyful, always caps.
class GuardianSectionTitle extends StatelessWidget {
  final String text;
  final double size;
  final Color? color;

  const GuardianSectionTitle(this.text, {super.key, this.size = 18, this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      LumiTheme.caps(text),
      style: LumiTheme.joyful(size, color: color ?? LumiColors.textDark),
    );
  }
}

class EmptyDataIndicator extends StatelessWidget {
  final String message;
  const EmptyDataIndicator({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return ArcadeCard(
      padding: const EdgeInsets.all(LumiSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: LumiColors.secondaryPurple,
              shape: BoxShape.circle,
              border: Border.all(color: LumiColors.primaryPurple, width: ArcadeSizes.badgeBorder),
              boxShadow: LumiShadows.badge(LumiColors.primaryPurple),
            ),
            child: const Icon(Icons.monitor_heart_outlined, size: 36, color: LumiColors.primaryPurple),
          ),
          const SizedBox(height: LumiSpacing.lg),
          Text(
            message,
            textAlign: TextAlign.center,
            style: LumiTheme.clanRegular(15, color: LumiColors.textMuted, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class MetricCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;

  const MetricCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: LumiSpacing.md, vertical: LumiSpacing.md),
      decoration: BoxDecoration(
        color: LumiColors.primaryLight,
        borderRadius: BorderRadius.circular(ArcadeSizes.cardRadius),
        border: Border.all(color: LumiColors.secondaryGreen, width: ArcadeSizes.cardBorder),
        boxShadow: LumiShadows.card(LumiColors.primaryGreen),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: LumiColors.secondaryGreen,
              borderRadius: BorderRadius.circular(LumiRadii.md),
              border: Border.all(color: LumiColors.primaryGreen, width: ArcadeSizes.badgeBorder),
              boxShadow: LumiShadows.badge(LumiColors.primaryGreen),
            ),
            child: Icon(icon, color: LumiColors.primaryGreen, size: 20),
          ),
          const SizedBox(width: LumiSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  LumiTheme.caps(title),
                  style: LumiTheme.joyful(15, color: LumiColors.textDark),
                ),
                const SizedBox(height: LumiSpacing.xs),
                Text(subtitle, style: LumiTheme.clanRegular(12, color: LumiColors.textMuted)),
              ],
            ),
          ),
          const SizedBox(width: LumiSpacing.sm),
          Text(value, style: LumiTheme.joyful(18, color: LumiColors.primaryGreen)),
        ],
      ),
    );
  }
}

class AnalyticsMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final String change;

  const AnalyticsMetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.unit,
    required this.change,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(LumiSpacing.lg),
      decoration: BoxDecoration(
        color: LumiColors.primaryLight,
        borderRadius: BorderRadius.circular(ArcadeSizes.cardRadius),
        border: Border.all(color: LumiColors.secondaryPurple, width: ArcadeSizes.cardBorder),
        boxShadow: LumiShadows.card(LumiColors.primaryPurple),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(LumiTheme.caps(title), style: LumiTheme.joyful(15, color: LumiColors.textDark)),
                const SizedBox(height: LumiSpacing.sm),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(value, style: LumiTheme.joyful(24, color: LumiColors.primaryPurple)),
                    const SizedBox(width: LumiSpacing.sm),
                    Text(unit, style: LumiTheme.clanRegular(12, color: LumiColors.textMuted)),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: LumiSpacing.xs),
            decoration: BoxDecoration(
              color: LumiColors.secondaryPurple,
              borderRadius: BorderRadius.circular(LumiRadii.pill),
              border: Border.all(color: LumiColors.primaryPurple, width: 2),
            ),
            child: Text(change, style: LumiTheme.clanMedium(11, color: LumiColors.primaryPurple)),
          ),
        ],
      ),
    );
  }
}

class AccountDetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isCode;

  const AccountDetailRow({super.key, required this.label, required this.value, this.isCode = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: LumiSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: LumiTheme.clanRegular(14, color: LumiColors.textMuted)),
          const SizedBox(width: LumiSpacing.md),
          isCode
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: LumiSpacing.md, vertical: LumiSpacing.sm),
                  decoration: BoxDecoration(
                    color: LumiColors.secondaryGreen,
                    borderRadius: BorderRadius.circular(LumiRadii.md),
                    border: Border.all(color: LumiColors.primaryGreen, width: ArcadeSizes.badgeBorder),
                    boxShadow: LumiShadows.badge(LumiColors.primaryGreen),
                  ),
                  child: Text(
                    value,
                    style: LumiTheme.clanMedium(14, color: LumiColors.textDark, letterSpacing: 2),
                  ),
                )
              : Flexible(
                  child: Text(
                    value,
                    textAlign: TextAlign.right,
                    style: LumiTheme.clanMedium(15, color: LumiColors.textDark),
                  ),
                ),
        ],
      ),
    );
  }
}

String formatLastSync(DateTime? at) {
  if (at == null) return 'Never synced';
  final diff = DateTime.now().difference(at);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  return '${at.month}/${at.day} ${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
}

/// Visual variant for cloud sync status chips.
enum CloudSyncPillKind { synced, needsSync, failed }

/// Compact status pill used on guardian dashboard + settings.
class CloudSyncStatusPill extends StatelessWidget {
  final String label;
  final CloudSyncPillKind kind;

  const CloudSyncStatusPill({
    super.key,
    required this.label,
    required this.kind,
  });

  Color get _accent {
    switch (kind) {
      case CloudSyncPillKind.synced:
        return LumiColors.primaryGreen;
      case CloudSyncPillKind.needsSync:
        return LumiColors.badgeAmber;
      case CloudSyncPillKind.failed:
        return LumiColors.redAlert;
    }
  }

  IconData get _icon {
    switch (kind) {
      case CloudSyncPillKind.synced:
        return Icons.cloud_done_outlined;
      case CloudSyncPillKind.needsSync:
        return Icons.cloud_upload_outlined;
      case CloudSyncPillKind.failed:
        return Icons.cloud_off_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: ArcadeSizes.badgePadH, vertical: ArcadeSizes.badgePadV),
      decoration: BoxDecoration(
        color: LumiColors.primaryLight,
        borderRadius: BorderRadius.circular(LumiRadii.pill),
        border: Border.all(color: accent, width: ArcadeSizes.badgeBorder),
        boxShadow: LumiShadows.badge(accent),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: ArcadeSizes.badgeIcon - 3, color: accent),
          const SizedBox(width: LumiSpacing.sm),
          Text(label, style: LumiTheme.clanMedium(12, color: accent, height: 1.1)),
        ],
      ),
    );
  }
}
