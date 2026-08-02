import 'package:flutter/material.dart';

import '../../../services/local_metrics_service.dart';
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

const _monthNamesShort = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// e.g. `3:40 PM`
String formatReadableTime(DateTime at) {
  final local = at.toLocal();
  final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour >= 12 ? 'PM' : 'AM';
  return '$hour12:$minute $period';
}

/// e.g. `Aug 2, 2026`
String formatReadableDate(DateTime at) {
  final local = at.toLocal();
  return '${_monthNamesShort[local.month - 1]} ${local.day}, ${local.year}';
}

/// e.g. `Aug 2, 2026 at 3:40 PM`
String formatReadableDateTime(DateTime? at, {String empty = '—'}) {
  if (at == null) return empty;
  return '${formatReadableDate(at)} at ${formatReadableTime(at)}';
}

String formatLastSync(DateTime? at) {
  if (at == null) return 'Not yet';
  final diff = DateTime.now().difference(at);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inHours < 1) return '${diff.inMinutes} min ago';
  if (diff.inDays < 1) return '${diff.inHours} hr ago';
  if (diff.inDays == 1) return 'Yesterday at ${formatReadableTime(at)}';
  if (diff.inDays < 7) return '${diff.inDays} days ago';
  return formatReadableDateTime(at);
}

String formatSyncTimestamp(DateTime? at) {
  return formatReadableDateTime(at, empty: 'Not yet');
}

String friendlySyncSummary({required int pulled, required int pushed}) {
  if (pulled == 0 && pushed == 0) {
    return 'Everything looks up to date!';
  }
  final parts = <String>[];
  if (pulled > 0) {
    parts.add('brought down $pulled update${pulled == 1 ? '' : 's'}');
  }
  if (pushed > 0) {
    parts.add('saved $pushed from this phone');
  }
  final joined = parts.join(' and ');
  return '${joined[0].toUpperCase()}${joined.substring(1)}.';
}

/// Visual variant for cloud sync status chips.
enum CloudSyncPillKind { synced, needsSync, failed }

/// Compact status pill used on guardian dashboard + settings.
class CloudSyncStatusPill extends StatelessWidget {
  final String label;
  final CloudSyncPillKind kind;
  final VoidCallback? onTap;
  final double? maxWidth;
  /// When true, renders a 40×40 icon badge matching [ArcadeIconBadge].
  final bool iconOnly;

  const CloudSyncStatusPill({
    super.key,
    required this.label,
    required this.kind,
    this.onTap,
    this.maxWidth,
    this.iconOnly = false,
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
    final Widget pill;
    if (iconOnly) {
      pill = Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: LumiColors.primaryLight,
          borderRadius: BorderRadius.circular(LumiRadii.pill),
          border: Border.all(color: accent, width: ArcadeSizes.badgeBorder),
          boxShadow: LumiShadows.badge(accent),
        ),
        child: Icon(_icon, size: 20, color: accent),
      );
    } else {
      final widthCap = maxWidth ?? 96;
      pill = ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: 32,
          maxWidth: widthCap,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: LumiColors.primaryLight,
            borderRadius: BorderRadius.circular(LumiRadii.pill),
            border: Border.all(color: accent, width: 2),
            boxShadow: LumiShadows.badge(accent),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_icon, size: 14, color: accent),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: LumiTheme.clanMedium(10, color: accent, height: 1.0),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (onTap == null) return pill;
    return GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: pill);
  }
}

/// Tappable sync badge that opens an arcade popup with online/offline sync details.
class GuardianSyncStatusBadge extends StatelessWidget {
  final CloudSyncStatus status;
  final GuardianSyncDetails details;
  final List<int> childIds;
  final Future<void> Function()? onSyncComplete;

  const GuardianSyncStatusBadge({
    super.key,
    required this.status,
    required this.details,
    this.childIds = const [],
    this.onSyncComplete,
  });

  CloudSyncPillKind get _kind => switch (status.kind) {
        CloudSyncKind.synced => CloudSyncPillKind.synced,
        CloudSyncKind.needsSync => CloudSyncPillKind.needsSync,
        CloudSyncKind.failed => CloudSyncPillKind.failed,
      };

  void _showDetails(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (box == null || overlay == null) return;

    final offset = box.localToGlobal(Offset.zero, ancestor: overlay);
    final size = box.size;

    showDialog<GuardianSyncDetails?>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.25),
      builder: (dialogContext) {
        return _GuardianSyncDetailsDialog(
          initialStatus: status,
          initialDetails: details,
          childIds: childIds,
          anchorTop: offset.dy + size.height + 8,
        );
      },
    ).then((updated) async {
      if (updated != null) {
        await onSyncComplete?.call();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: status.label,
      child: CloudSyncStatusPill(
        label: status.shortLabel,
        kind: _kind,
        iconOnly: true,
        onTap: () => _showDetails(context),
      ),
    );
  }
}

class _GuardianSyncDetailsDialog extends StatefulWidget {
  final CloudSyncStatus initialStatus;
  final GuardianSyncDetails initialDetails;
  final List<int> childIds;
  final double anchorTop;

  const _GuardianSyncDetailsDialog({
    required this.initialStatus,
    required this.initialDetails,
    required this.childIds,
    required this.anchorTop,
  });

  @override
  State<_GuardianSyncDetailsDialog> createState() => _GuardianSyncDetailsDialogState();
}

class _GuardianSyncDetailsDialogState extends State<_GuardianSyncDetailsDialog> {
  late CloudSyncStatus _status = widget.initialStatus;
  late GuardianSyncDetails _details = widget.initialDetails;
  bool _syncing = false;
  String? _syncMessage;
  bool _didSync = false;

  Future<void> _runTwoWaySync() async {
    if (_syncing) return;
    if (widget.childIds.isEmpty) {
      setState(() => _syncMessage = 'Add a child first to keep updates flowing.');
      return;
    }

    setState(() {
      _syncing = true;
      _syncMessage = 'Updating…';
    });

    try {
      final result = await LocalMetricsService.instance.forceSyncFamily(widget.childIds);
      final details = await LocalMetricsService.instance.getGuardianSyncDetails();
      if (!mounted) return;
      setState(() {
        _syncing = false;
        _didSync = true;
        _details = details;
        _status = details.status;
        _syncMessage = friendlySyncSummary(
          pulled: result.pulledMetrics,
          pushed: result.pushedBatches,
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _syncing = false;
        _syncMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: LumiSpacing.lg,
          right: LumiSpacing.lg,
          top: widget.anchorTop,
          child: Material(
            color: Colors.transparent,
            child: ArcadeCard(
              padding: const EdgeInsets.all(LumiSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    LumiTheme.caps('Your updates'),
                    style: LumiTheme.joyful(18, color: LumiColors.primaryPurple),
                  ),
                  const SizedBox(height: LumiSpacing.sm),
                  Text(
                    _status.label,
                    style: LumiTheme.clanMedium(13, color: LumiColors.textMuted),
                  ),
                  const SizedBox(height: LumiSpacing.md),
                  _SyncDetailBlock(
                    title: 'From the cloud',
                    subtitle: 'Latest eye-care info saved onto this phone',
                    accent: LumiColors.primaryPurple,
                    timestamp: _details.lastOnlinePullAt,
                    detail: _details.lastOnlinePullAt == null
                        ? 'Nothing brought down yet'
                        : '${_details.lastOnlinePullCount} update${_details.lastOnlinePullCount == 1 ? '' : 's'} brought down',
                  ),
                  const SizedBox(height: LumiSpacing.md),
                  _SyncDetailBlock(
                    title: 'From this phone',
                    subtitle: 'Updates from play sessions sent to the cloud',
                    accent: LumiColors.primaryGreen,
                    timestamp: _details.lastOfflinePushAt,
                    detail: _details.lastOfflinePushAt == null && _status.pendingCount == 0
                        ? 'Nothing shared from this phone yet'
                        : [
                            if (_details.lastOfflinePushAt != null)
                              '${_details.lastOfflinePushCount} update${_details.lastOfflinePushCount == 1 ? '' : 's'} saved',
                            if (_status.pendingCount > 0)
                              '${_status.pendingCount} still waiting — tap Update Now',
                          ].join(' · '),
                  ),
                  if (_syncMessage != null) ...[
                    const SizedBox(height: LumiSpacing.md),
                    Text(
                      _syncMessage!,
                      textAlign: TextAlign.center,
                      style: LumiTheme.clanMedium(
                        12,
                        color: _syncMessage!.toLowerCase().contains('couldn’t') ||
                                _syncMessage!.toLowerCase().contains('couldn\'t') ||
                                _syncMessage!.toLowerCase().contains('internet') ||
                                _syncMessage!.toLowerCase().contains('try again') ||
                                _syncMessage!.toLowerCase().contains('fail')
                            ? LumiColors.redAlert
                            : LumiColors.primaryGreen,
                      ),
                    ),
                  ],
                  const SizedBox(height: LumiSpacing.md),
                  if (_syncing)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: LumiSpacing.sm),
                      child: Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: LumiColors.primaryPurple,
                          ),
                        ),
                      ),
                    )
                  else
                    ArcadeButton(
                      text: 'UPDATE NOW',
                      fontSize: 13,
                      onTap: _runTwoWaySync,
                    ),
                  const SizedBox(height: LumiSpacing.sm),
                  ArcadeButton(
                    text: 'DONE',
                    fontSize: 12,
                    variant: ArcadeButtonVariant.outline,
                    onTap: () => Navigator.of(context).pop(_didSync ? _details : null),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SyncDetailBlock extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color accent;
  final DateTime? timestamp;
  final String detail;

  const _SyncDetailBlock({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.timestamp,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(LumiSpacing.md),
      decoration: BoxDecoration(
        color: LumiColors.primaryLight,
        borderRadius: BorderRadius.circular(LumiRadii.md),
        border: Border.all(color: accent, width: ArcadeSizes.badgeBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: LumiTheme.clanMedium(14, color: accent)),
          const SizedBox(height: 2),
          Text(subtitle, style: LumiTheme.clanRegular(12, color: LumiColors.textMuted, height: 1.3)),
          const SizedBox(height: LumiSpacing.sm),
          Text(
            'Last updated: ${formatSyncTimestamp(timestamp)}',
            style: LumiTheme.clanMedium(12, color: LumiColors.textDark),
          ),
          if (timestamp != null)
            Text(
              '(${formatLastSync(timestamp)})',
              style: LumiTheme.clanRegular(11, color: LumiColors.textMuted),
            ),
          const SizedBox(height: LumiSpacing.xs),
          Text(detail, style: LumiTheme.clanRegular(12, color: LumiColors.textDark, height: 1.35)),
        ],
      ),
    );
  }
}
