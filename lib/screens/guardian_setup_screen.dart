import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/guardian_setup_service.dart';
import '../services/onboarding_service.dart';
import '../theme/lumi_theme.dart';
import '../widgets/arcade/arcade.dart';
import '../widgets/lumi_form.dart';
import '../widgets/lumi_shell.dart';
import 'guardian_dashboard_screen.dart';
import 'parent_onboarding_screen.dart';

class GuardianSetupScreen extends StatefulWidget {
  final bool mandatory;

  const GuardianSetupScreen({super.key, this.mandatory = true});

  @override
  State<GuardianSetupScreen> createState() => _GuardianSetupScreenState();
}

class _GuardianSetupScreenState extends State<GuardianSetupScreen> {
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();
  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _savePin() async {
    if (_isSaving) {
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    final result = await GuardianSetupService.instance.createGuardianPin(
      pin: _pinController.text.trim(),
      confirmPin: _confirmPinController.text.trim(),
    );

    if (!mounted) {
      return;
    }

    if (!result.success) {
      setState(() {
        _isSaving = false;
        _error = result.message;
      });
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();

    if (!mounted) return;
    final onboarded = await OnboardingService.instance.isParentOnboardingDone();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => onboarded
            ? const GuardianDashboardScreen()
            : const ParentOnboardingScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.mandatory,
      child: Scaffold(
        body: LumiShell(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(LumiSpacing.lg),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: ArcadeCard(
                  padding: const EdgeInsets.all(LumiSpacing.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        LumiTheme.caps('Parent Setup'),
                        textAlign: TextAlign.center,
                        style: LumiTheme.joyful(26, color: LumiColors.primaryPurple),
                      ),
                      const SizedBox(height: LumiSpacing.md),
                      Text(
                        'Create a 4-digit parent PIN. You will need it for parent controls and to unlock strong rest mode.',
                        style: LumiTheme.clanRegular(14, color: LumiColors.textMuted, height: 1.45),
                      ),
                      const SizedBox(height: LumiSpacing.lg),
                      LumiPillField(
                        label: 'Guardian PIN',
                        controller: _pinController,
                        obscureText: true,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        maxLength: 4,
                      ),
                      const SizedBox(height: LumiSpacing.md),
                      LumiPillField(
                        label: 'Confirm PIN',
                        controller: _confirmPinController,
                        obscureText: true,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        maxLength: 4,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: LumiSpacing.md),
                        Text(_error!, style: LumiTheme.clanMedium(13, color: LumiColors.redAlert)),
                      ],
                      const SizedBox(height: LumiSpacing.lg),
                      ArcadeButton(
                        text: _isSaving ? 'SAVING…' : 'SAVE GUARDIAN PIN',
                        onTap: _isSaving ? null : _savePin,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
