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
      final status = await LocalMetricsService.instance.getCloudSyncStatus(childId: _selectedChildId);
      if (mounted) setState(() => _syncStatus = status);
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

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GuardianChildDashboardScreen(childId: childId),
      ),
    );
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
        await AuthSessionService.instance.clearUserSession();
        await ActiveChildContextService.instance.clearActiveChild();

        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/welcome', (route) => false);
        }
      } catch (e) {
        debugPrint('Error during logout: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Logout error: $e')),
          );
        }
      }
    }
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
        actions: [
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
                      'No internet — sync and share need a connection.',
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
                  ArcadeCard(
                    padding: const EdgeInsets.all(LumiSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const GuardianSectionTitle('Select Child', size: 20),
                        const SizedBox(height: LumiSpacing.md),
                        ArcadeButton(
                          text: 'ADD CHILD',
                          fontSize: 14,
                          onTap: _addChild,
                        ),
                        if (_syncStatus != null) ...[
                          const SizedBox(height: LumiSpacing.md),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: CloudSyncStatusPill(
                              label: _syncStatus!.label,
                              kind: switch (_syncStatus!.kind) {
                                CloudSyncKind.synced => CloudSyncPillKind.synced,
                                CloudSyncKind.needsSync => CloudSyncPillKind.needsSync,
                                CloudSyncKind.failed => CloudSyncPillKind.failed,
                              },
                            ),
                          ),
                        ],
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
                  const SizedBox(height: LumiSpacing.lg),
                  ArcadeCard(
                    padding: const EdgeInsets.all(LumiSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const GuardianSectionTitle('Guardian Security', size: 20),
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
                          onTap: _showChangePinDialog,
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
                        const GuardianSectionTitle('Parent Account', size: 20),
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
                          onTap: _showParentChangePasswordDialog,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: LumiSpacing.lg),
                  Container(
                    padding: const EdgeInsets.all(LumiSpacing.lg),
                    decoration: BoxDecoration(
                      color: LumiColors.primaryLight,
                      borderRadius: BorderRadius.circular(ArcadeSizes.cardRadius),
                      border: Border.all(color: LumiColors.primaryPurple, width: ArcadeSizes.cardBorder),
                      boxShadow: LumiShadows.card(LumiColors.primaryPurple),
                    ),

                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const GuardianSectionTitle('Share with Doctor', size: 20),
                        const SizedBox(height: LumiSpacing.md),
                        Text(
                          'Generate a temporary code for your doctor. You can end their viewing session anytime from your phone.',
                          style: LumiTheme.clanRegular(14, color: LumiColors.textMuted, height: 1.45),
                        ),
                        const SizedBox(height: LumiSpacing.lg),
                        ArcadeButton(
                          text: 'SHARE WITH DOCTOR',
                          fontSize: 14,
                          onTap: () {
                            if (_selectedChildId == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please select a child first.')),
                              );
                              return;
                            }
                            final child = _children.firstWhere(
                              (c) => c.childId == _selectedChildId,
                              orElse: () => _children.first,
                            );
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ShareTelemetryScreen(
                                  childId: _selectedChildId!,
                                  childName: child.displayName,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: LumiSpacing.md),
                        ArcadeButton(
                          text: 'VIEWING ACCESS HISTORY',
                          fontSize: 14,
                          variant: ArcadeButtonVariant.outline,
                          onTap: () {
                            if (_selectedChildId == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please select a child first.')),
                              );
                              return;
                            }
                            final child = _children.firstWhere(
                              (c) => c.childId == _selectedChildId,
                              orElse: () => _children.first,
                            );
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => GuardianAccessAuditScreen(
                                  childId: _selectedChildId!,
                                  childName: child.displayName,
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
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: _selectedBirthdate ?? DateTime.now().subtract(const Duration(days: 365 * 10)),
                        firstDate: DateTime(1990),
                        lastDate: DateTime.now(),
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
