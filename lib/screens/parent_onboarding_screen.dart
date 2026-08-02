import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../copy/lumi_strings.dart';
import '../distance_test_screen.dart';
import '../services/critical_overlay_service.dart';
import '../services/onboarding_service.dart';
import '../theme/lumi_theme.dart';
import '../widgets/arcade/arcade.dart';
import '../widgets/lumi_dialog.dart';
import '../widgets/lumi_form.dart';
import '../widgets/lumi_shell.dart';
import 'guardian_dashboard_screen.dart';

/// Compressed parent onboarding: permissions → first child → calibrate → done.
class ParentOnboardingScreen extends StatefulWidget {
  const ParentOnboardingScreen({super.key});

  @override
  State<ParentOnboardingScreen> createState() => _ParentOnboardingScreenState();
}

class _ParentOnboardingScreenState extends State<ParentOnboardingScreen> {
  /// 0 permissions, 1 first child hint, 2 calibrate, 3 done
  int _step = 0;
  bool _busy = false;

  Future<void> _grantPermissions() async {
    setState(() => _busy = true);
    await Permission.camera.request();
    await Permission.notification.request();
    if (Platform.isAndroid) {
      var granted = await CriticalOverlayService.instance.ensurePermission();
      if (!granted) {
        await CriticalOverlayService.instance.openOverlaySettings();
        granted = await CriticalOverlayService.instance.hasPermission();
      }
    }
    setState(() => _busy = false);
    if (!mounted) return;
    setState(() => _step = 1);
  }

  Future<void> _openDistanceSetup() async {
    final cam = await Permission.camera.status;
    if (!cam.isGranted) {
      final requested = await Permission.camera.request();
      if (!requested.isGranted) {
        if (!mounted) return;
        await _showDeniedDialog(title: LumiStrings.cameraDeniedTitle, body: LumiStrings.cameraDeniedBody);
        return;
      }
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const DistanceTestScreen(initialReferenceCm: 30)),
    );
    if (!mounted) return;
    setState(() => _step = 3);
  }

  Future<void> _finish() async {
    await OnboardingService.instance.markParentOnboardingDone();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const GuardianDashboardScreen()),
    );
  }

  Future<void> _showDeniedDialog({required String title, required String body}) async {
    await showDialog<void>(
      context: context,
      barrierColor: LumiColors.modalOverlay,
      builder: (ctx) => LumiDialog(
        title: title,
        content: Text(body, style: LumiTheme.clanRegular(14, color: LumiColors.textMuted, height: 1.45)),
        actions: [
          LumiPillButton(
            label: LumiStrings.notNow,
            backgroundColor: LumiColors.cardWhite,
            onPressed: () => Navigator.pop(ctx),
          ),
          const SizedBox(height: LumiSpacing.md),
          LumiPillButton(
            label: LumiStrings.openSettings,
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LumiShell(
        watermark: LumiStrings.brand,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(LumiSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  LumiTheme.caps(LumiStrings.parentSetupTitle),
                  textAlign: TextAlign.center,
                  style: LumiTheme.joyful(26, color: LumiColors.primaryPurple),
                ),
                const SizedBox(height: LumiSpacing.sm),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: LumiSpacing.md, vertical: LumiSpacing.xs),
                    decoration: BoxDecoration(
                      color: LumiColors.secondaryGreen,
                      borderRadius: BorderRadius.circular(LumiRadii.pill),
                      border: Border.all(color: LumiColors.primaryGreen, width: 3),
                      boxShadow: LumiShadows.badge(LumiColors.primaryGreen),
                    ),
                    child: Text(
                      LumiTheme.caps('Step ${_step + 1} of 4'),
                      style: LumiTheme.clanMedium(12, color: LumiColors.primaryGreen, letterSpacing: 0.8),
                    ),
                  ),
                ),
                const SizedBox(height: LumiSpacing.lg),
                Expanded(child: _buildStep()),
                if (_busy)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(LumiRadii.pill),
                    child: const LinearProgressIndicator(
                      minHeight: 8,
                      color: LumiColors.primaryPurple,
                      backgroundColor: LumiColors.secondaryLight,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _StepCard(
          title: 'Turn on permissions',
          body: 'Camera and alerts let LUMI watch distance and blink habits. On Android, allow appear-on-top for gentle reminders.',
          primaryLabel: 'Allow permissions',
          onPrimary: _grantPermissions,
          secondaryLabel: LumiStrings.notNow,
          onSecondary: () => setState(() => _step = 1),
        );
      case 1:
        return _StepCard(
          title: 'Add your first child',
          body: 'From the Parent Dashboard, tap Add Child and save the login code. Your child uses that code to sign in on their device.',
          primaryLabel: 'Got it — continue',
          onPrimary: () => setState(() => _step = 2),
        );
      case 2:
        return _StepCard(
          title: LumiStrings.distanceSetup,
          body: 'Hold the phone about 30 cm from your face so LUMI learns a safe viewing distance.',
          primaryLabel: 'Start distance setup',
          onPrimary: _openDistanceSetup,
          secondaryLabel: 'Skip for now',
          onSecondary: () => setState(() => _step = 3),
        );
      default:
        return _StepCard(
          title: 'You\'re all set!',
          body: LumiStrings.howLumiWorksBody,
          primaryLabel: LumiStrings.finishSetup,
          onPrimary: _finish,
        );
    }
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.title,
    required this.body,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String title;
  final String body;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return ArcadeCard(
      padding: const EdgeInsets.all(LumiSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            LumiTheme.caps(title),
            style: LumiTheme.joyful(20, color: LumiColors.textDark, height: 1.25),
          ),
          const SizedBox(height: LumiSpacing.md),
          Text(body, style: LumiTheme.clanRegular(15, color: LumiColors.textMuted, height: 1.5)),
          const Spacer(),
          ArcadeButton(text: LumiTheme.caps(primaryLabel), onTap: onPrimary),
          if (secondaryLabel != null && onSecondary != null) ...[
            const SizedBox(height: LumiSpacing.md),
            ArcadeButton(
              text: LumiTheme.caps(secondaryLabel!),
              variant: ArcadeButtonVariant.outline,
              onTap: onSecondary,
            ),
          ],
        ],
      ),
    );
  }
}
