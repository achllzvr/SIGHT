import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/cleanup_service.dart';
import '../services/feedback_service.dart';
import '../services/gamification_service.dart';
import '../services/guardian_auth_service.dart';
import '../services/session_timer_service.dart';
import '../services/task_service.dart';
import '../theme/lumi_theme.dart';
import '../widgets/arcade/arcade.dart';
import '../widgets/lumi_dialog.dart';
import '../widgets/lumi_form.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  bool _cameraMissing = false;
  late final AnimationController _mascotBob;

  @override
  void initState() {
    super.initState();
    _mascotBob = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    await GamificationService.instance.initialize();
    await GamificationService.instance.updatePetState();
    await TaskService.instance.initialize();
    await _checkCameraPermission();
  }

  @override
  void dispose() {
    _mascotBob.dispose();
    super.dispose();
  }

  Future<void> _checkCameraPermission() async {
    final status = await Permission.camera.status;
    if (mounted) setState(() => _cameraMissing = !status.isGranted);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            if (_cameraMissing)
              Padding(
                padding: const EdgeInsets.fromLTRB(LumiSpacing.lg, LumiSpacing.md, LumiSpacing.lg, 0),
                child: Material(
                  color: LumiColors.coralTrack,
                  borderRadius: BorderRadius.circular(LumiRadii.lg),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(LumiRadii.lg),
                    onTap: () async {
                      await openAppSettings();
                      await _checkCameraPermission();
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(LumiSpacing.md),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(LumiRadii.lg),
                        border: Border.all(color: LumiColors.outline, width: LumiColors.borderWidth),
                      ),
                      child: const Text(
                        'Ask a parent to turn on the camera in Settings so LUMI can help your eyes.',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, height: 16 / 12, color: LumiColors.textDark),
                      ),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(LumiSpacing.lg, LumiSpacing.md, LumiSpacing.lg, LumiSpacing.sm),
              child: _HomeTopChrome(onSettings: () => _showSettingsDialog(context)),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final mascotW = (constraints.maxWidth * 0.72).clamp(180.0, 270.0);
                  final mascotH = (constraints.maxHeight * 0.72).clamp(200.0, 340.0);
                  return Column(
                    children: [
                      Expanded(
                        child: Center(
                          child: AnimatedBuilder(
                            animation: _mascotBob,
                            builder: (_, child) {
                              final dy = (_mascotBob.value - 0.5) * 8;
                              return Transform.translate(offset: Offset(0, dy), child: child);
                            },
                            child: SizedBox(
                              width: mascotW,
                              height: mascotH,
                              child: ValueListenableBuilder<int>(
                                valueListenable: GamificationService.instance.healthScoreNotifier,
                                builder: (_, hp, __) {
                                  final path = resolveHomeMascotAsset(hp: hp);
                                  return AnimatedSwitcher(
                                    duration: LumiMotion.slow,
                                    switchInCurve: LumiMotion.easeStandard,
                                    switchOutCurve: LumiMotion.easeStandard,
                                    transitionBuilder: (child, anim) => FadeTransition(
                                      opacity: anim,
                                      child: ScaleTransition(
                                        scale: Tween(begin: 0.96, end: 1.0).animate(anim),
                                        child: child,
                                      ),
                                    ),
                                    child: Image.asset(
                                      path,
                                      key: ValueKey(path),
                                      fit: BoxFit.contain,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.fromLTRB(LumiSpacing.xl, 0, LumiSpacing.xl, LumiSpacing.md),
                        child: _SubtleHealthBar(),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSettingsDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            void refresh() {
              setSheetState(() {});
              setState(() {});
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
                child: Container(
                  decoration: BoxDecoration(
                    color: LumiColors.cardWhite,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(LumiRadii.xl)),
                    border: Border.all(color: LumiColors.secondaryLight, width: ArcadeSizes.cardBorder),
                    boxShadow: LumiShadows.modal(),
                  ),
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.88,
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      LumiSpacing.lg,
                      LumiSpacing.lg,
                      LumiSpacing.lg,
                      LumiSpacing.xl,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                LumiTheme.caps('Settings'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: LumiTheme.joyful(24, color: LumiColors.textDark),
                              ),
                            ),
                            const SizedBox(width: LumiSpacing.sm),
                            GestureDetector(
                              onTap: () => Navigator.pop(sheetContext),
                              child: const ArcadeIcon('close', size: 28),
                            ),
                          ],
                        ),
                        const SizedBox(height: LumiSpacing.lg),
                        _SettingsTile(
                          title: 'Haptic Feedback',
                          subtitle: 'Vibrations and touches',
                          arcadeIcon: 'activity',
                          onTap: () {
                            FeedbackService.instance.setHapticEnabled(
                              !FeedbackService.instance.isHapticEnabled,
                            );
                            refresh();
                          },
                          isEnabled: FeedbackService.instance.isHapticEnabled,
                        ),
                        const SizedBox(height: LumiSpacing.md),
                        ArcadeCard(
                          padding: const EdgeInsets.all(LumiSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Vibration Duration',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: LumiTheme.clanMedium(14, color: LumiColors.textDark),
                                    ),
                                  ),
                                  const SizedBox(width: LumiSpacing.sm),
                                  Text(
                                    '${(FeedbackService.instance.vibrationIntensity * 100).toStringAsFixed(0)}%',
                                    style: LumiTheme.clanMedium(12, color: LumiColors.primaryGreen),
                                  ),
                                ],
                              ),
                              const SizedBox(height: LumiSpacing.md),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final compact = constraints.maxWidth < 340;
                                  final options = [0, 25, 50, 75, 100];
                                  return Wrap(
                                    spacing: compact ? 6 : 8,
                                    runSpacing: 8,
                                    children: options.map((percent) {
                                      final value = percent / 100.0;
                                      final isSelected =
                                          (FeedbackService.instance.vibrationIntensity * 100).round() ==
                                              percent;
                                      final chipWidth = compact
                                          ? (constraints.maxWidth - 6) / 2
                                          : (constraints.maxWidth - 32) / 5;
                                      return SizedBox(
                                        width: chipWidth.clamp(56.0, 120.0),
                                        child: GestureDetector(
                                          onTap: () {
                                            FeedbackService.instance.setVibrationIntensity(value);
                                            FeedbackService.instance.provideFeedback(FeedbackType.info);
                                            refresh();
                                          },
                                          child: AnimatedContainer(
                                            duration: LumiMotion.fast,
                                            alignment: Alignment.center,
                                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? LumiColors.secondaryGreen
                                                  : LumiColors.primaryLight,
                                              border: Border.all(
                                                color: isSelected
                                                    ? LumiColors.primaryGreen
                                                    : LumiColors.secondaryLight,
                                                width: ArcadeSizes.badgeBorder,
                                              ),
                                              borderRadius: BorderRadius.circular(LumiRadii.pill),
                                              boxShadow: isSelected
                                                  ? LumiShadows.badge(LumiColors.primaryGreen)
                                                  : const [],
                                            ),
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: Text(
                                                '$percent%',
                                                maxLines: 1,
                                                style: LumiTheme.clanMedium(
                                                  12,
                                                  color: isSelected
                                                      ? LumiColors.primaryGreen
                                                      : LumiColors.textMuted,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  );
                                },
                              ),
                              const SizedBox(height: LumiSpacing.sm),
                              Text(
                                'Tap a level to adjust vibration duration',
                                style: LumiTheme.clanRegular(12),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: LumiSpacing.md),
                        _SettingsTile(
                          title: 'Audio Feedback',
                          subtitle: 'Sounds and beeps',
                          arcadeIcon: 'like',
                          onTap: () {
                            FeedbackService.instance.setAudioEnabled(
                              !FeedbackService.instance.isAudioEnabled,
                            );
                            refresh();
                          },
                          isEnabled: FeedbackService.instance.isAudioEnabled,
                        ),
                        const SizedBox(height: LumiSpacing.lg),
                        const Divider(color: LumiColors.outline, thickness: 1, height: 1),
                        const SizedBox(height: LumiSpacing.lg),
                        GestureDetector(
                          onTap: () => _handleLogout(sheetContext),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: ArcadeSizes.buttonPadH,
                              vertical: ArcadeSizes.buttonPadV,
                            ),
                            decoration: BoxDecoration(
                              color: LumiColors.primaryLight,
                              borderRadius: BorderRadius.circular(LumiRadii.pill),
                              border: Border.all(
                                color: LumiColors.redAlert,
                                width: ArcadeSizes.buttonBorder,
                              ),
                              boxShadow: LumiShadows.button(LumiColors.redAlert),
                            ),
                            child: Text(
                              LumiTheme.caps('Logout'),
                              textAlign: TextAlign.center,
                              style: LumiTheme.clanMedium(
                                ArcadeSizes.buttonFont,
                                color: LumiColors.redAlert,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    final canAuth = await GuardianAuthService.instance.canAuthenticate();
    if (canAuth) {
      final authenticated = await GuardianAuthService.instance.authenticateWithBiometrics();
      if (authenticated) {
        if (!context.mounted) return;
        await _performLogout(context);
        return;
      }
    }

    if (!context.mounted) return;
    _showPinEntryDialog(context);
  }

  void _showPinEntryDialog(BuildContext context) {
    final pinController = TextEditingController();

    showDialog(
      context: context,
      barrierColor: LumiColors.modalOverlay,
      builder: (dialogContext) => LumiDialog(
        title: 'Guardian Verification',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter guardian passcode to logout',
              style: LumiTheme.clanRegular(14),
            ),
            const SizedBox(height: LumiSpacing.lg),
            ArcadeTextField(
              label: 'Passcode',
              controller: pinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
            ),
          ],
        ),
        actions: [
          LumiPillButton(
            label: 'Cancel',
            onPressed: () => Navigator.pop(dialogContext),
            backgroundColor: LumiColors.cardWhite,
          ),
          const SizedBox(height: LumiSpacing.md),
          LumiPillButton(
            label: 'Verify',
            onPressed: () async {
              final storedPin = await GuardianAuthService.instance.loadFallbackPin();
              if (storedPin != null && GuardianAuthService.instance.verifyFallbackPin(pinController.text, storedPin)) {
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                if (!context.mounted) return;
                await _performLogout(context);
              } else {
                if (!dialogContext.mounted) return;
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Incorrect passcode')),
                );
              }
            },
            backgroundColor: LumiColors.primaryPurple,
            foregroundColor: Colors.white,
          ),
        ],
      ),
    );
  }

  Future<void> _performLogout(BuildContext context) async {
    await CleanupService.instance.performCompleteCleanup();
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/welcome', (route) => false);
  }
}

/// Home mascot reflects persisted HP (same thresholds as GamificationService.updatePetState).
String resolveHomeMascotAsset({required int hp}) {
  if (hp >= 70) return 'assets/mascot/mascot_great_v1.png';
  if (hp >= 30) return 'assets/mascot/mascot_good_v1.png';
  return 'assets/mascot/mascot_bad_v1.png';
}

class _HomeTopChrome extends StatelessWidget {
  const _HomeTopChrome({required this.onSettings});

  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: ValueListenableBuilder<int>(
            valueListenable: GamificationService.instance.coinsNotifier,
            builder: (_, coins, __) => ArcadeScoreBadge(
              arcadeIcon: 'star',
              label: '$coins',
              accentColor: LumiColors.badgeAmber,
              compact: true,
              expand: true,
            ),
          ),
        ),
        const SizedBox(width: LumiSpacing.sm),
        Expanded(
          flex: 4,
          child: ValueListenableBuilder<int>(
            valueListenable: SessionTimerService.instance.remainingSecondsNotifier,
            builder: (_, seconds, __) {
              return ArcadeScoreBadge(
                arcadeIcon: 'timer',
                label: LumiTheme.formatRemaining(seconds),
                accentColor: LumiColors.primaryPurple,
                compact: true,
                expand: true,
              );
            },
          ),
        ),
        const SizedBox(width: LumiSpacing.sm),
        Expanded(
          flex: 2,
          child: ArcadeIconBadge(
            arcadeIcon: 'tshirt',
            accentColor: LumiColors.primaryGreen,
            expand: true,
            onTap: () {
              if (!context.mounted) return;
              Navigator.pushNamed(context, '/store');
            },
          ),
        ),
        const SizedBox(width: LumiSpacing.sm),
        Expanded(
          flex: 2,
          child: ArcadeIconBadge(
            arcadeIcon: 'settings',
            accentColor: LumiColors.badgeCyan,
            expand: true,
            onTap: onSettings,
          ),
        ),
      ],
    );
  }
}

class _SubtleHealthBar extends StatelessWidget {
  const _SubtleHealthBar();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: GamificationService.instance.healthScoreNotifier,
      builder: (_, hp, __) {
        final barColor = hp < 30
            ? LumiColors.redAlert
            : (hp < 70 ? LumiColors.badgeAmber : LumiColors.primaryGreen);
        final clamped = (hp.clamp(0, 100)) / 100.0;
        return Row(
          children: [
            const ArcadeIcon('heart', size: 20),
            const SizedBox(width: LumiSpacing.sm),
            Expanded(
              child: Container(
                height: 16,
                decoration: BoxDecoration(
                  color: LumiColors.primaryLight,
                  borderRadius: BorderRadius.circular(LumiRadii.pill),
                  border: Border.all(color: LumiColors.secondaryLight, width: ArcadeSizes.cardBorder),
                ),
                clipBehavior: Clip.antiAlias,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: clamped),
                  duration: LumiMotion.slow,
                  curve: LumiMotion.easeStandard,
                  builder: (_, value, __) => Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: value,
                      heightFactor: 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: barColor,
                          borderRadius: BorderRadius.circular(LumiRadii.pill),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: LumiSpacing.sm),
            Text('$hp', style: LumiTheme.clanMedium(14, color: barColor)),
          ],
        );
      },
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String arcadeIcon;
  final VoidCallback onTap;
  final bool isEnabled;

  const _SettingsTile({
    required this.title,
    required this.subtitle,
    required this.arcadeIcon,
    required this.onTap,
    required this.isEnabled,
  });

  @override
  Widget build(BuildContext context) {
    return ArcadeCard(
      padding: const EdgeInsets.symmetric(horizontal: LumiSpacing.md, vertical: LumiSpacing.md),
      onTap: onTap,
      child: Row(
        children: [
          ArcadeIcon(arcadeIcon, size: 24, lightMono: !isEnabled),
          const SizedBox(width: LumiSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LumiTheme.clanMedium(14, color: LumiColors.textDark),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: LumiTheme.clanRegular(12),
                ),
              ],
            ),
          ),
          const SizedBox(width: LumiSpacing.sm),
          AnimatedContainer(
            duration: LumiMotion.fast,
            width: 52,
            height: 30,
            padding: const EdgeInsets.all(3),
            alignment: isEnabled ? Alignment.centerRight : Alignment.centerLeft,
            decoration: BoxDecoration(
              color: isEnabled ? LumiColors.secondaryGreen : LumiColors.primaryLight,
              borderRadius: BorderRadius.circular(LumiRadii.pill),
              border: Border.all(
                color: isEnabled ? LumiColors.primaryGreen : LumiColors.secondaryLight,
                width: ArcadeSizes.badgeBorder,
              ),
            ),
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: isEnabled ? LumiColors.primaryGreen : LumiColors.secondaryLight,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
