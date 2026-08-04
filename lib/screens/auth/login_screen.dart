import 'package:flutter/material.dart';

import '../../services/active_child_context_service.dart';
import '../../services/auth_account_service.dart';
import '../../services/auth_session_service.dart';
import '../../services/guardian_login_sync_service.dart';
import '../../services/guardian_setup_service.dart';
import '../../services/onboarding_service.dart';
import '../../theme/lumi_theme.dart';
import '../../widgets/arcade/arcade.dart';
import '../../widgets/auth_landing_shell.dart';
import '../guardian_dashboard_screen.dart';
import '../guardian_setup_screen.dart';
import '../legal_gate_screen.dart';
import '../parent_onboarding_screen.dart';
import 'child_login_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _loading = false;
  String? _error;
  String _status = '';

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
      _status = 'Signing in…';
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      final success = await AuthAccountService.instance.authenticateGuardian(
        email: email,
        password: password,
      );
      if (!mounted) return;

      if (!success) {
        setState(() {
          _loading = false;
          _status = '';
          _error = 'Wrong email or password.';
        });
        return;
      }

      await ActiveChildContextService.instance.clearActiveChild();
      await AuthSessionService.instance.saveGuardianSession(guardianEmail: email);

      if (!mounted) return;
      setState(() => _status = 'Getting your family’s data ready…');

      final sync = await GuardianLoginSyncService.instance.syncAfterLogin(
        email,
        onStatus: (status) {
          if (!mounted) return;
          setState(() => _status = status);
        },
      );

      if (!mounted) return;

      final hasPin = await GuardianSetupService.instance.hasGuardianPin();
      final onboarded = await OnboardingService.instance.isParentOnboardingDone();

      if (!mounted) return;
      FocusManager.instance.primaryFocus?.unfocus();

      if (!sync.success) {
        debugPrint('[LoginScreen] post-login sync failed: ${sync.message}');
      }

      final Widget nextScreen;
      if (!hasPin) {
        nextScreen = const GuardianSetupScreen(mandatory: true);
      } else if (!onboarded) {
        nextScreen = const ParentOnboardingScreen();
      } else {
        nextScreen = const GuardianDashboardScreen();
      }

      // Explicit page route — named pushAndRemoveUntil against `home` was
      // leaving MaterialApp.builder with a null child (blank screen).
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => nextScreen),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _status = '';
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _openRegister() {
    Navigator.of(context).push(authSlideRoute(const LegalGateScreen()));
  }

  void _goBack() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        authSlideRoute(const ChildLoginScreen(), reverse: true),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLandingShell(
      footer: AuthFooterPrompt(
        prompt: "Don't Have An Account?",
        buttonLabel: 'Register',
        onTap: _openRegister,
      ),
      child: AuthStagger(
        children: [
          AuthHeader(
            title: 'Parent Login',
            showBack: true,
            onBack: _goBack,
          ),
          const SizedBox(height: LumiSpacing.lg),
          AuthFormCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ArcadeTextField(
                  label: 'Email',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: LumiSpacing.md),
                ArcadeTextField(
                  label: 'Password',
                  controller: _passwordController,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                ),
                if (_error != null) ...[
                  const SizedBox(height: LumiSpacing.md),
                  Text(
                    _error!,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: LumiTheme.clanMedium(13, color: LumiColors.redAlert),
                  ),
                ],
                if (_loading && _status.isNotEmpty) ...[
                  const SizedBox(height: LumiSpacing.md),
                  Text(
                    _status,
                    textAlign: TextAlign.center,
                    style: LumiTheme.clanMedium(13, color: LumiColors.textMuted),
                  ),
                ],
                const SizedBox(height: LumiSpacing.xl),
                AuthPrimaryButton(
                  label: _loading ? (_status.isNotEmpty ? _status : 'Please wait…') : 'Login',
                  enabled: !_loading,
                  onTap: _login,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
