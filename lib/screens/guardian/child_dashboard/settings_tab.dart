import 'package:flutter/material.dart';

import '../../../services/active_child_context_service.dart';
import '../../../services/auth_account_service.dart';
import '../../../services/auth_session_service.dart';
import '../../../services/local_metrics_service.dart';
import '../../../theme/lumi_theme.dart';
import '../../../widgets/arcade/arcade.dart';
import '../../../widgets/lumi_dialog.dart';
import '../../../widgets/lumi_form.dart';
import 'shared_widgets.dart';

class ChildDashboardSettingsTab extends StatefulWidget {
  final int? childId;
  const ChildDashboardSettingsTab({super.key, this.childId});

  @override
  State<ChildDashboardSettingsTab> createState() => _ChildDashboardSettingsTabState();
}

class _ChildDashboardSettingsTabState extends State<ChildDashboardSettingsTab> {
  ChildAccount? _childAccount;
  bool _loading = true;
  String? _guardianEmail;
  CloudSyncStatus? _syncStatus;

  @override
  void initState() {
    super.initState();
    _load();
    _refreshSyncStatus();
    LocalMetricsService.instance.lastSuccessfulSyncAt.addListener(_onSyncTimeChanged);
  }

  @override
  void dispose() {
    LocalMetricsService.instance.lastSuccessfulSyncAt.removeListener(_onSyncTimeChanged);
    super.dispose();
  }

  void _onSyncTimeChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    try {
      final session = await AuthSessionService.instance.loadUserSession();
      _guardianEmail = session?.guardianEmail;
      final targetChildId = widget.childId ?? await ActiveChildContextService.instance.getActiveChildId();

      if (_guardianEmail != null && targetChildId != null) {
        final accounts = await AuthAccountService.instance.listChildrenForGuardian(_guardianEmail!);
        try {
          _childAccount = accounts.firstWhere((acc) => acc.childId == targetChildId);
        } catch (_) {
          if (accounts.isNotEmpty) _childAccount = accounts.first;
        }
      }
      if (mounted) setState(() => _loading = false);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refreshSyncStatus() async {
    try {
      final childId = widget.childId ?? await ActiveChildContextService.instance.getActiveChildId();
      final status = await LocalMetricsService.instance.getCloudSyncStatus(childId: childId);
      if (mounted) setState(() => _syncStatus = status);
    } catch (_) {}
  }

  CloudSyncPillKind _pillKind(CloudSyncKind kind) {
    return switch (kind) {
      CloudSyncKind.synced => CloudSyncPillKind.synced,
      CloudSyncKind.needsSync => CloudSyncPillKind.needsSync,
      CloudSyncKind.failed => CloudSyncPillKind.failed,
    };
  }

  Future<void> _showResetPasswordDialog() async {
    if (_guardianEmail == null || _childAccount == null) return;
    final childId = _childAccount!.childId;
    if (childId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Child is not linked to the server yet.')),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final guardianPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();

    try {
      final success = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        barrierColor: LumiColors.scaffoldLight.withValues(alpha: 0.72),
        builder: (dialogContext) {
          String? error;
          bool inProgress = false;

          return StatefulBuilder(
            builder: (_, setDialogState) {
              return LumiDialog(
                title: 'Reset Child Password',
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Authorize this change by entering your Guardian password.',
                      style: LumiTheme.clanRegular(14, color: LumiColors.textMuted, height: 1.45),
                    ),
                    const SizedBox(height: LumiSpacing.lg),
                    LumiPillField(label: 'Guardian Password', controller: guardianPasswordController, obscureText: true),
                    const SizedBox(height: LumiSpacing.md),
                    LumiPillField(label: 'New Child Password', controller: newPasswordController, obscureText: true, errorText: error),
                  ],
                ),
                actions: [
                  LumiPillButton(
                    label: 'Cancel',
                    backgroundColor: Colors.white,
                    onPressed: inProgress ? null : () => Navigator.of(dialogContext).pop(),
                  ),
                  const SizedBox(height: LumiSpacing.md),
                  if (inProgress)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: LumiSpacing.md),
                      child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: LumiColors.primaryPurple))),
                    )
                  else
                    LumiPillButton(
                      label: 'Reset Password',
                      onPressed: () async {
                        setDialogState(() { inProgress = true; error = null; });
                        final result = await AuthAccountService.instance.updateChildPassword(
                          guardianEmail: _guardianEmail!,
                          guardianPassword: guardianPasswordController.text,
                          childId: childId,
                          loginCode: _childAccount!.loginCode,
                          newPassword: newPasswordController.text,
                        );
                        if (!dialogContext.mounted) return;
                        if (result.success) {
                          Navigator.of(dialogContext).pop(true);
                          return;
                        }
                        setDialogState(() { inProgress = false; error = result.message; });
                      },
                    ),
                ],
              );
            },
          );
        },
      );

      if (success == true) {
        messenger.showSnackBar(const SnackBar(content: Text('Child password updated successfully.')));
      }
    } finally {
      Future.delayed(const Duration(milliseconds: 400), () {
        guardianPasswordController.dispose();
        newPasswordController.dispose();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: LumiColors.primaryPurple));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(LumiSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ArcadeCard(
            padding: const EdgeInsets.all(LumiSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(child: GuardianSectionTitle('Keep data up to date', size: 17)),
                    const SizedBox(width: LumiSpacing.sm),
                    if (_syncStatus != null)
                      CloudSyncStatusPill(
                        label: _syncStatus!.shortLabel,
                        kind: _pillKind(_syncStatus!.kind),
                        maxWidth: 88,
                      ),
                  ],
                ),
                const SizedBox(height: LumiSpacing.md),
                ValueListenableBuilder<DateTime?>(
                  valueListenable: LocalMetricsService.instance.lastSuccessfulSyncAt,
                  builder: (_, at, __) => Text(
                    'Last updated: ${formatLastSync(at)}',
                    style: LumiTheme.clanRegular(14, color: LumiColors.textMuted),
                  ),
                ),
                const SizedBox(height: LumiSpacing.sm),
                Text(
                  'This keeps eye-care info matching between this phone and the cloud.',
                  style: LumiTheme.clanRegular(13, color: LumiColors.textMuted, height: 1.4),
                ),
                const SizedBox(height: LumiSpacing.md),
                ArcadeButton(
                  text: 'UPDATE NOW',
                  fontSize: 14,
                  onTap: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Updating…'), duration: Duration(seconds: 2)),
                    );
                    try {
                      final childId = widget.childId ?? await ActiveChildContextService.instance.getActiveChildId();
                      if (childId == null) {
                        throw Exception('Pick a child first.');
                      }
                      final result = await LocalMetricsService.instance.forceSyncFamily([childId]);
                      await _refreshSyncStatus();
                      if (!context.mounted) return;
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(result.message),
                          backgroundColor: LumiColors.primaryGreen,
                        ),
                      );
                    } catch (e) {
                      await _refreshSyncStatus();
                      if (!context.mounted) return;
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            e.toString().replaceAll('Exception: ', ''),
                          ),
                          backgroundColor: LumiColors.redAlert,
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: LumiSpacing.lg),
          if (_childAccount == null)
            const EmptyDataIndicator(message: 'Child account not found.')
          else ...[
            ArcadeCard(
              padding: const EdgeInsets.all(LumiSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const GuardianSectionTitle('Child Account', size: 20),
                  const SizedBox(height: LumiSpacing.md),
                  AccountDetailRow(label: 'Display Name', value: _childAccount!.displayName),
                  const Divider(color: LumiColors.secondaryLight, height: LumiSpacing.lg, thickness: 2),
                  AccountDetailRow(label: 'Login Code', value: _childAccount!.loginCode, isCode: true),
                  const Divider(color: LumiColors.secondaryLight, height: LumiSpacing.lg, thickness: 2),
                  AccountDetailRow(label: 'Server Child ID', value: _childAccount!.childId?.toString() ?? 'Local Only'),
                ],
              ),
            ),
            const SizedBox(height: LumiSpacing.lg),
            ArcadeCard(
              padding: const EdgeInsets.all(LumiSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const GuardianSectionTitle('Child Password', size: 17),
                  const SizedBox(height: LumiSpacing.md),
                  ArcadeButton(
                    text: 'RESET CHILD PASSWORD',
                    fontSize: 14,
                    variant: ArcadeButtonVariant.outline,
                    onTap: _showResetPasswordDialog,
                  ),
                ],
              ),
            ),
            const SizedBox(height: LumiSpacing.xl),
          ],
        ],
      ),
    );
  }
}
