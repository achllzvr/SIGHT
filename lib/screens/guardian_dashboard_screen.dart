import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/active_child_context_service.dart';
import '../services/auth_account_service.dart';
import '../services/auth_session_service.dart';
import '../services/cleanup_service.dart';
import '../services/connectivity_service.dart';
import '../services/guardian_setup_service.dart';
import '../theme/lumi_theme.dart';
import '../widgets/arcade/arcade.dart';
import '../widgets/lumi_dialog.dart';
import '../widgets/lumi_form.dart';
import '../services/local_metrics_service.dart';
import 'auth/verify_email_otp_screen.dart';
import 'guardian_access_audit_screen.dart';
import 'guardian_child_dashboard_screen.dart';
import 'guardian/child_dashboard/shared_widgets.dart';
import 'share_telemetry_screen.dart';

/// Model for child with basic info and login code
class ChildInfo {
  final int childId;
  final String displayName;
  final int ageYears;
  final String loginCode;
  final DateTime? birthdate;

  ChildInfo({
    required this.childId,
    required this.displayName,
    required this.ageYears,
    required this.loginCode,
    this.birthdate,
  });
}

class GuardianDashboardScreen extends StatefulWidget {
  const GuardianDashboardScreen({super.key});

  @override
  State<GuardianDashboardScreen> createState() => _GuardianDashboardScreenState();
}

class _GuardianDashboardScreenState extends State<GuardianDashboardScreen> {
  List<ChildInfo> _children = [];
  int? _selectedChildId;
  bool _loading = true;
  String? _guardianEmail;
  CloudSyncStatus? _syncStatus;
  GuardianSyncDetails? _syncDetails;
  bool _isOffline = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  @override
  void initState() {
    super.initState();
    _loadChildren();
    _initConnectivity();
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  Future<void> _initConnectivity() async {
    final online = await ConnectivityService.instance.isOnline();
    if (mounted) setState(() => _isOffline = !online);
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final offline = results.isEmpty || results.contains(ConnectivityResult.none);
      if (mounted) setState(() => _isOffline = offline);
    });
  }

  Future<void> _refreshSyncStatus() async {
    try {
      final details = await LocalMetricsService.instance.getGuardianSyncDetails();
      if (mounted) {
        setState(() {
          _syncDetails = details;
          _syncStatus = details.status;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadChildren() async {
    try {
      final session = await AuthSessionService.instance.loadUserSession();
      _guardianEmail = session?.guardianEmail;

      if (_guardianEmail != null) {
        final childAccounts = await AuthAccountService.instance.listChildrenForGuardian(_guardianEmail!);

        final children = childAccounts.map((child) {
          int age = 0;
          if (child.birthdate != null) {
            age = _calculateAge(child.birthdate!);
          }

          return ChildInfo(
            childId: child.childId ?? 0,
            displayName: child.displayName,
            ageYears: age,
            loginCode: child.loginCode,
            birthdate: child.birthdate,
          );
        }).toList();

        await ActiveChildContextService.instance.initialize();
        final activeChildId = await ActiveChildContextService.instance.getActiveChildId();

        if (mounted) {
          setState(() {
            _children = children;
            _selectedChildId = activeChildId ?? (children.isNotEmpty ? children[0].childId : null);
            _loading = false;
          });
          _refreshSyncStatus();
        }
      } else {
        if (mounted) {
          setState(() => _loading = false);
        }
      }
    } catch (e) {
      debugPrint('Error loading children: $e');
      if (mounted) {
        setState(() => _loading = false);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(e.toString().replaceAll('Exception: ', '')),
                backgroundColor: LumiColors.redAlert,
              ),
            );
          }
        });
      }
    }
  }

  int _calculateAge(DateTime birthDate) {
    final today = DateTime.now();
    int age = today.year - birthDate.year;
    if (today.month < birthDate.month || (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  void _selectChild(int childId) {
    setState(() => _selectedChildId = childId);
    ActiveChildContextService.instance.setActiveChildId(childId);

    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => GuardianChildDashboardScreen(childId: childId),
          ),
        )
        .then((_) {
          if (mounted) _refreshSyncStatus();
        });
  }

  Future<void> _addChild() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddChildModal(),
    );

    if (result == true) {
      _loadChildren();
    }
  }

  Future<void> _showChangePinDialog() async {
    final messenger = ScaffoldMessenger.of(context);

    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();

    try {
      final successMsg = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        barrierColor: LumiColors.scaffoldLight.withValues(alpha: 0.72),
        builder: (dialogContext) {
          String? error;
          bool inProgress = false;

          return StatefulBuilder(
            builder: (_, setDialogState) {
              return LumiDialog(
                title: 'Change Guardian PIN',
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LumiPillField(
                      label: 'Current PIN',
                      controller: currentController,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      maxLength: 4,
                    ),
                    const SizedBox(height: LumiSpacing.md),
                    LumiPillField(
                      label: 'New PIN',
                      controller: newController,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      maxLength: 4,
                    ),
                    const SizedBox(height: LumiSpacing.md),
                    LumiPillField(
                      label: 'Confirm New PIN',
                      controller: confirmController,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      maxLength: 4,
                      errorText: error,
                    ),
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
                      child: Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.4, color: LumiColors.greenMid),
                        ),
                      ),
                    )
                  else
                    LumiPillButton(
                      label: 'Update PIN',
                      backgroundColor: LumiColors.greenMid,
                      foregroundColor: Colors.white,
                      onPressed: () async {
                        setDialogState(() {
                          inProgress = true;
                          error = null;
                        });

                        final result = await GuardianSetupService.instance.changeGuardianPin(
                          currentPin: currentController.text.trim(),
                          newPin: newController.text.trim(),
                          confirmNewPin: confirmController.text.trim(),
                        );

                        if (!dialogContext.mounted) return;

                        if (result.success) {
                          Navigator.of(dialogContext).pop(result.message);
                          return;
                        }

                        setDialogState(() {
                          inProgress = false;
                          error = result.message;
                        });
                      },
                    ),
                ],
              );
            },
          );
        },
      );

      if (successMsg != null) {
        messenger.showSnackBar(SnackBar(content: Text(successMsg)));
      }
    } finally {
      Future.delayed(const Duration(milliseconds: 400), () {
        currentController.dispose();
        newController.dispose();
        confirmController.dispose();
      });
    }
  }

  Future<void> _showParentChangePasswordDialog() async {
    final messenger = ScaffoldMessenger.of(context);

    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();

    try {
      final successMsg = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        barrierColor: LumiColors.scaffoldLight.withValues(alpha: 0.72),
        builder: (dialogContext) {
          String? error;
          bool inProgress = false;

          return StatefulBuilder(
            builder: (_, setDialogState) {
              return LumiDialog(
                title: 'Change Account Password',
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LumiPillField(
                      label: 'Current Password',
                      controller: currentController,
                      obscureText: true,
                    ),
                    const SizedBox(height: LumiSpacing.md),
                    LumiPillField(
                      label: 'New Password',
                      controller: newController,
                      obscureText: true,
                    ),
                    const SizedBox(height: LumiSpacing.md),
                    LumiPillField(
                      label: 'Confirm New Password',
                      controller: confirmController,
                      obscureText: true,
                      errorText: error,
                    ),
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
                      child: Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.4, color: LumiColors.greenMid),
                        ),
                      ),
                    )
                  else
                    LumiPillButton(
                      label: 'Update Password',
                      backgroundColor: LumiColors.greenMid,
                      foregroundColor: Colors.white,
                      onPressed: () async {
                        setDialogState(() {
                          inProgress = true;
                          error = null;
                        });

                        if (newController.text != confirmController.text) {
                          setDialogState(() {
                            inProgress = false;
                            error = 'New passwords do not match.';
                          });
                          return;
                        }

                        final result = await AuthAccountService.instance.resetParentPassword(
                          _guardianEmail!,
                          currentController.text,
                          newController.text,
                        );

                        if (!dialogContext.mounted) return;

                        if (result.success) {
                          Navigator.of(dialogContext).pop(result.message);
                        } else {
                          setDialogState(() {
                            inProgress = false;
                            error = result.message;
                          });
                        }
                      },
                    ),
                ],
              );
            },
          );
        },
      );

      if (successMsg != null) {
        messenger.showSnackBar(SnackBar(content: Text(successMsg)));
      }
    } finally {
      Future.delayed(const Duration(milliseconds: 400), () {
        currentController.dispose();
        newController.dispose();
        confirmController.dispose();
      });
    }
  }

  Future<void> _logout() async {
    final confirmed = await showLumiConfirmDialog(
      context: context,
      title: 'Logout',
      message: 'Are you sure you want to logout? All tracking will stop.',
      confirmLabel: 'Logout',
      confirmColor: LumiColors.redAlert,
      confirmForeground: Colors.white,
    );

    if (confirmed == true) {
      try {
        await CleanupService.instance.performCompleteCleanup();

        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/welcome', (route) => false);
        }
      } catch (e) {
        debugPrint('Error during logout: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Logout failed: $e'), backgroundColor: LumiColors.redAlert),
          );
        }
      }
    }
  }

  void _showAccountSecurityModal() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final bottomInset = MediaQuery.viewInsetsOf(sheetContext).bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.82,
            ),
            decoration: const BoxDecoration(
              color: LumiColors.scaffoldMint,
              borderRadius: BorderRadius.vertical(top: Radius.circular(LumiRadii.xl)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: LumiSpacing.md),
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: LumiColors.secondaryLight,
                    borderRadius: BorderRadius.circular(LumiRadii.pill),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(LumiSpacing.lg, LumiSpacing.lg, LumiSpacing.lg, LumiSpacing.sm),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          LumiTheme.caps('Account & Security'),
                          style: LumiTheme.joyful(20, color: LumiColors.primaryPurple),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close, color: LumiColors.textMuted),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(LumiSpacing.lg, 0, LumiSpacing.lg, LumiSpacing.xl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ArcadeCard(
                          padding: const EdgeInsets.all(LumiSpacing.lg),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const GuardianSectionTitle('Parent Account', size: 18),
                              const SizedBox(height: LumiSpacing.md),
                              Row(
                                children: [
                                  const Icon(Icons.email_outlined, size: 20, color: LumiColors.primaryPurple),
                                  const SizedBox(width: LumiSpacing.md),
                                  Expanded(
                                    child: Text(
                                      _guardianEmail ?? 'Loading...',
                                      style: LumiTheme.clanMedium(15, color: LumiColors.textDark),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: LumiSpacing.lg),
                              ArcadeButton(
                                text: 'VERIFY EMAIL ADDRESS',
                                fontSize: 14,
                                variant: ArcadeButtonVariant.outline,
                                onTap: _guardianEmail == null
                                    ? null
                                    : () {
                                        Navigator.pop(sheetContext);
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => VerifyEmailOtpScreen(email: _guardianEmail!),
                                          ),
                                        );
                                      },
                              ),
                              const SizedBox(height: LumiSpacing.md),
                              ArcadeButton(
                                text: 'RESET PARENT PASSWORD',
                                fontSize: 14,
                                variant: ArcadeButtonVariant.outline,
                                onTap: () {
                                  Navigator.pop(sheetContext);
                                  _showParentChangePasswordDialog();
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: LumiSpacing.lg),
                        ArcadeCard(
                          padding: const EdgeInsets.all(LumiSpacing.lg),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const GuardianSectionTitle('Guardian Security', size: 18),
                              const SizedBox(height: LumiSpacing.md),
                              Text(
                                'Update your guardian PIN used for strict lock override and guardian access.',
                                style: LumiTheme.clanRegular(14, color: LumiColors.textMuted, height: 1.45),
                              ),
                              const SizedBox(height: LumiSpacing.lg),
                              ArcadeButton(
                                text: 'CHANGE GUARDIAN PIN',
                                fontSize: 14,
                                variant: ArcadeButtonVariant.outline,
                                onTap: () {
                                  Navigator.pop(sheetContext);
                                  _showChangePinDialog();
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showShareModal() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _ShareWithDoctorSheet(
          children: _children,
          initialChildId: _selectedChildId,
          onGenerate: (child) {
            Navigator.pop(sheetContext);
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ShareTelemetryScreen(
                  childId: child.childId,
                  childName: child.displayName,
                ),
              ),
            );
          },
          onOpenHistory: ({ChildInfo? child}) {
            Navigator.pop(sheetContext);
            final childIds = _children
                .map((c) => c.childId)
                .where((id) => id > 0)
                .toList(growable: false);
            final childNames = {
              for (final c in _children)
                if (c.childId > 0) c.childId: c.displayName,
            };
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => child == null
                    ? GuardianAccessAuditScreen(
                        allChildren: true,
                        childIds: childIds,
                        childNames: childNames,
                      )
                    : GuardianAccessAuditScreen(
                        childId: child.childId,
                        childName: child.displayName,
                        childIds: childIds,
                        childNames: childNames,
                      ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: LumiColors.scaffoldMint,
        body: Center(child: CircularProgressIndicator(color: LumiColors.primaryPurple)),
      );
    }

    return Scaffold(
      backgroundColor: LumiColors.scaffoldMint,
      appBar: AppBar(
        title: Text(
          LumiTheme.caps('Parent Home'),
          style: LumiTheme.joyful(20, color: LumiColors.primaryPurple),
        ),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: LumiColors.textDark,
        leadingWidth: 72,
        leading: _syncStatus != null && _syncDetails != null
            ? Padding(
                padding: const EdgeInsets.only(left: LumiSpacing.md),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: GuardianSyncStatusBadge(
                    status: _syncStatus!,
                    details: _syncDetails!,
                    childIds: _children
                        .map((c) => c.childId)
                        .where((id) => id > 0)
                        .toList(growable: false),
                    onSyncComplete: _refreshSyncStatus,
                  ),
                ),
              )
            : null,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: LumiSpacing.sm),
            child: Center(
              child: Tooltip(
                message: 'Share with doctor',
                child: ArcadeIconBadge(
                  arcadeIcon: 'users',
                  accentColor: LumiColors.primaryPurple,
                  onTap: _showShareModal,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: LumiSpacing.md),
            child: Center(
              child: Tooltip(
                message: 'Logout',
                child: ArcadeIconBadge(
                  arcadeIcon: 'lock',
                  accentColor: LumiColors.redAlert,
                  onTap: _logout,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isOffline)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: LumiSpacing.lg),
              padding: const EdgeInsets.symmetric(horizontal: LumiSpacing.md, vertical: LumiSpacing.md),
              decoration: BoxDecoration(
                color: LumiColors.tipYellow,
                borderRadius: BorderRadius.circular(LumiRadii.md),
                border: Border.all(color: LumiColors.badgeAmber, width: ArcadeSizes.badgeBorder),
                boxShadow: LumiShadows.badge(LumiColors.badgeAmber),
              ),
              child: Row(
                children: [
                  const Icon(Icons.wifi_off, size: 18, color: LumiColors.textDark),
                  const SizedBox(width: LumiSpacing.md),
                  Expanded(
                    child: Text(
                      'You’re offline — connect to update data and share with a doctor.',
                      style: LumiTheme.clanMedium(13, color: LumiColors.textDark),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(LumiSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GestureDetector(
                    onTap: _showAccountSecurityModal,
                    child: ArcadeCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: LumiSpacing.lg,
                        vertical: LumiSpacing.md,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: LumiColors.secondaryPurple,
                              borderRadius: BorderRadius.circular(LumiRadii.md),
                              border: Border.all(
                                color: LumiColors.primaryPurple,
                                width: ArcadeSizes.badgeBorder,
                              ),
                              boxShadow: LumiShadows.badge(LumiColors.primaryPurple),
                            ),
                            child: const ArcadeIcon('settings', size: 20),
                          ),
                          const SizedBox(width: LumiSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  LumiTheme.caps('Account & Security'),
                                  style: LumiTheme.joyful(16, color: LumiColors.textDark),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _guardianEmail ?? 'Parent settings',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: LumiTheme.clanRegular(12, color: LumiColors.textMuted),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: LumiColors.primaryPurple),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: LumiSpacing.lg),
                  ArcadeCard(
                    padding: const EdgeInsets.all(LumiSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(child: GuardianSectionTitle('Select Child', size: 20)),
                            Tooltip(
                              message: 'Add child',
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _addChild,
                                  customBorder: const CircleBorder(),
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: LumiColors.secondaryGreen,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: LumiColors.primaryGreen,
                                        width: ArcadeSizes.badgeBorder,
                                      ),
                                      boxShadow: LumiShadows.badge(LumiColors.primaryGreen),
                                    ),
                                    child: const ArcadeIcon('plus', size: 18),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: LumiSpacing.lg),
                        if (_children.isEmpty)
                          Center(
                            child: Text(
                              'Add a child to get started',
                              style: LumiTheme.clanRegular(15, color: LumiColors.textMuted),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _children.length,
                            separatorBuilder: (_, __) => const SizedBox(height: LumiSpacing.md),
                            itemBuilder: (context, index) {
                              final child = _children[index];
                              final isSelected = child.childId == _selectedChildId;
                              final accent =
                                  isSelected ? LumiColors.primaryGreen : LumiColors.secondaryLight;
                              return GestureDetector(
                                onTap: () => _selectChild(child.childId),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isSelected ? LumiColors.secondaryGreen : LumiColors.primaryLight,
                                    borderRadius: BorderRadius.circular(LumiRadii.lg),
                                    border: Border.all(color: accent, width: ArcadeSizes.cardBorder),
                                    boxShadow: LumiShadows.card(accent),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: LumiSpacing.md,
                                    vertical: LumiSpacing.md,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 50,
                                        height: 50,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: LumiColors.secondaryPurple,
                                          borderRadius: BorderRadius.circular(LumiRadii.md),
                                          border: Border.all(
                                            color: LumiColors.primaryPurple,
                                            width: ArcadeSizes.badgeBorder,
                                          ),
                                          boxShadow: LumiShadows.badge(LumiColors.primaryPurple),
                                        ),
                                        child: const Icon(
                                          Icons.face,
                                          size: 26,
                                          color: LumiColors.primaryPurple,
                                        ),
                                      ),
                                      const SizedBox(width: LumiSpacing.md),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              LumiTheme.caps(child.displayName),
                                              style: LumiTheme.joyful(17, color: LumiColors.textDark),
                                            ),
                                            const SizedBox(height: LumiSpacing.xs),
                                            Text(
                                              '${child.ageYears} years old',
                                              style: LumiTheme.clanRegular(13, color: LumiColors.textMuted),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isSelected)
                                        const Icon(
                                          Icons.check_circle,
                                          color: LumiColors.primaryGreen,
                                          size: 24,
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: LumiSpacing.xxl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareWithDoctorSheet extends StatefulWidget {
  final List<ChildInfo> children;
  final int? initialChildId;
  final void Function(ChildInfo child) onGenerate;
  final void Function({ChildInfo? child}) onOpenHistory;

  const _ShareWithDoctorSheet({
    required this.children,
    required this.initialChildId,
    required this.onGenerate,
    required this.onOpenHistory,
  });

  @override
  State<_ShareWithDoctorSheet> createState() => _ShareWithDoctorSheetState();
}

class _ShareWithDoctorSheetState extends State<_ShareWithDoctorSheet> {
  late int? _selectedId = widget.initialChildId ??
      (widget.children.isNotEmpty ? widget.children.first.childId : null);

  ChildInfo? get _selectedChild {
    if (_selectedId == null) return null;
    for (final child in widget.children) {
      if (child.childId == _selectedId) return child;
    }
    return widget.children.isNotEmpty ? widget.children.first : null;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.78,
        ),
        decoration: const BoxDecoration(
          color: LumiColors.scaffoldMint,
          borderRadius: BorderRadius.vertical(top: Radius.circular(LumiRadii.xl)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(LumiSpacing.lg, LumiSpacing.md, LumiSpacing.lg, LumiSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: LumiColors.secondaryLight,
                    borderRadius: BorderRadius.circular(LumiRadii.pill),
                  ),
                ),
              ),
              const SizedBox(height: LumiSpacing.lg),
              Text(
                LumiTheme.caps('Share with Doctor'),
                style: LumiTheme.joyful(20, color: LumiColors.primaryPurple),
              ),
              const SizedBox(height: LumiSpacing.sm),
              Text(
                'Pick a child to generate a temporary code/QR, or review who has viewed your family’s data.',
                style: LumiTheme.clanRegular(14, color: LumiColors.textMuted, height: 1.45),
              ),
              const SizedBox(height: LumiSpacing.lg),
              if (widget.children.isEmpty)
                Text(
                  'Add a child first before sharing with a doctor.',
                  style: LumiTheme.clanRegular(14, color: LumiColors.textMuted),
                )
              else ...[
                Text(
                  LumiTheme.caps('Select Child'),
                  style: LumiTheme.joyful(15, color: LumiColors.textDark),
                ),
                const SizedBox(height: LumiSpacing.sm),
                ...widget.children.map((child) {
                  final selected = child.childId == _selectedId;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: LumiSpacing.sm),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedId = child.childId),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: LumiSpacing.md,
                          vertical: LumiSpacing.md,
                        ),
                        decoration: BoxDecoration(
                          color: selected ? LumiColors.secondaryGreen : LumiColors.primaryLight,
                          borderRadius: BorderRadius.circular(LumiRadii.md),
                          border: Border.all(
                            color: selected ? LumiColors.primaryGreen : LumiColors.secondaryLight,
                            width: ArcadeSizes.badgeBorder,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                LumiTheme.caps(child.displayName),
                                style: LumiTheme.clanMedium(15, color: LumiColors.textDark),
                              ),
                            ),
                            if (selected)
                              const Icon(Icons.check_circle, color: LumiColors.primaryGreen, size: 20),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: LumiSpacing.md),
                ArcadeButton(
                  text: 'GENERATE CODE / QR',
                  fontSize: 14,
                  onTap: () {
                    final child = _selectedChild;
                    if (child == null || child.childId <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please select a child first.')),
                      );
                      return;
                    }
                    widget.onGenerate(child);
                  },
                ),
              ],
              const SizedBox(height: LumiSpacing.md),
              ArcadeButton(
                text: 'VIEWING ACCESS HISTORY',
                fontSize: 14,
                variant: ArcadeButtonVariant.outline,
                onTap: () => widget.onOpenHistory(child: null),
              ),
              if (_selectedChild != null) ...[
                const SizedBox(height: LumiSpacing.sm),
                TextButton(
                  onPressed: () => widget.onOpenHistory(child: _selectedChild),
                  child: Text(
                    'History for ${_selectedChild!.displayName} only',
                    style: LumiTheme.clanMedium(13, color: LumiColors.primaryPurple),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class AddChildModal extends StatefulWidget {
  const AddChildModal({super.key});

  @override
  State<AddChildModal> createState() => _AddChildModalState();
}

class _AddChildModalState extends State<AddChildModal> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _birthdateController = TextEditingController();
  final _passwordController = TextEditingController();

  DateTime? _selectedBirthdate;
  bool _isLoading = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _birthdateController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Arcade pill decoration — kept as a decoration (not [ArcadeTextField]) so
  /// the form validators on these fields keep working.
  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: LumiTheme.clanRegular(14, color: LumiColors.textDisabled),
      filled: true,
      fillColor: LumiColors.cardWhite,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(LumiRadii.pill),
        borderSide: const BorderSide(color: LumiColors.secondaryLight, width: ArcadeSizes.fieldBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(LumiRadii.pill),
        borderSide: const BorderSide(color: LumiColors.secondaryLight, width: ArcadeSizes.fieldBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(LumiRadii.pill),
        borderSide: const BorderSide(color: LumiColors.primaryPurple, width: ArcadeSizes.fieldBorder),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(LumiRadii.pill),
        borderSide: const BorderSide(color: LumiColors.redAlert, width: ArcadeSizes.fieldBorder),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(LumiRadii.pill),
        borderSide: const BorderSide(color: LumiColors.redAlert, width: ArcadeSizes.fieldBorder),
      ),
      errorStyle: LumiTheme.clanRegular(12, color: LumiColors.redAlert),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: LumiSpacing.lg,
        vertical: LumiSpacing.md,
      ),
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final session = await AuthSessionService.instance.loadUserSession();
      final guardianEmail = session?.guardianEmail ?? '';

      if (guardianEmail.isEmpty) {
        setState(() => _isLoading = false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Guardian session required.')));
        return;
      }

      final result = await AuthAccountService.instance.createChildAccount(
        guardianEmail: guardianEmail,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        password: _passwordController.text,
        birthdate: _selectedBirthdate!,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (result.success) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          barrierColor: LumiColors.scaffoldLight.withValues(alpha: 0.72),
          builder: (dialogContext) => LumiDialog(
            title: 'Account Created!',
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Write down this Login Code:',
                  style: LumiTheme.clanRegular(14, color: LumiColors.textMuted),
                ),
                const SizedBox(height: LumiSpacing.md),
                Text(
                  result.account?.loginCode ?? '—',
                  style: LumiTheme.joyful(30, color: LumiColors.primaryPurple, letterSpacing: 4),
                ),
              ],
            ),
            actions: [
              LumiPillButton(
                label: 'Done',
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  Navigator.of(context).pop(true);
                },
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: LumiColors.primaryLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(LumiRadii.xl)),
        border: const Border(
          top: BorderSide(color: LumiColors.primaryPurple, width: ArcadeSizes.cardBorder),
          left: BorderSide(color: LumiColors.primaryPurple, width: ArcadeSizes.cardBorder),
          right: BorderSide(color: LumiColors.primaryPurple, width: ArcadeSizes.cardBorder),
        ),
        boxShadow: LumiShadows.modal(LumiColors.primaryPurple),
      ),
      padding: EdgeInsets.only(
        left: LumiSpacing.lg,
        right: LumiSpacing.lg,
        top: LumiSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + LumiSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(child: GuardianSectionTitle('Add Child', size: 22)),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: LumiColors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: LumiSpacing.lg),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _firstNameController,
                    style: LumiTheme.clanMedium(15, color: LumiColors.textDark),
                    decoration: _fieldDecoration('First Name'),
                    validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: LumiSpacing.md),
                  TextFormField(
                    controller: _lastNameController,
                    style: LumiTheme.clanMedium(15, color: LumiColors.textDark),
                    decoration: _fieldDecoration('Last Name'),
                  ),
                  const SizedBox(height: LumiSpacing.md),
                  TextFormField(
                    controller: _birthdateController,
                    readOnly: true,
                    style: LumiTheme.clanMedium(15, color: LumiColors.textDark),
                    onTap: () async {
                      final pickedDate = await LumiTheme.pickDate(
                        context,
                        initialDate: _selectedBirthdate ?? DateTime.now().subtract(const Duration(days: 365 * 10)),
                        firstDate: DateTime(1990),
                        lastDate: DateTime.now(),
                        helpText: 'SELECT BIRTHDATE',
                      );
                      if (pickedDate != null) {
                        setState(() {
                          _selectedBirthdate = pickedDate;
                          _birthdateController.text =
                              '${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}';
                        });
                      }
                    },
                    decoration: _fieldDecoration('Birthdate (YYYY-MM-DD)').copyWith(
                      suffixIcon: const Icon(Icons.calendar_today, color: LumiColors.textMuted),
                    ),
                    validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: LumiSpacing.md),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    style: LumiTheme.clanMedium(15, color: LumiColors.textDark),
                    decoration: _fieldDecoration('Child Password'),
                    validator: (value) => value == null || value.length < 4 ? 'Min 4 characters' : null,
                  ),
                  const SizedBox(height: LumiSpacing.lg),
                  ArcadeButton(
                    text: _isLoading ? 'SAVING…' : 'SAVE CHILD',
                    onTap: _isLoading ? null : _submitForm,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
