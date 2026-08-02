import 'package:flutter/material.dart';

import '../../services/active_child_context_service.dart';
import '../../services/auth_account_service.dart';
import '../../services/auth_session_service.dart';
import '../../services/session_lock_service.dart';
import '../../theme/lumi_theme.dart';
import '../../widgets/arcade/arcade.dart';
import '../../widgets/auth_landing_shell.dart';
import 'login_screen.dart';

class ChildLoginScreen extends StatefulWidget {
  const ChildLoginScreen({super.key});

  @override
  State<ChildLoginScreen> createState() => _ChildLoginScreenState();
}

class _ChildLoginScreenState extends State<ChildLoginScreen> {
  bool _loading = false;
  String? _error;

  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final code = _codeController.text.trim();
      final password = _passwordController.text;
      final child = await AuthAccountService.instance.authenticateChild(
        loginCode: code,
        password: password,
      );
      if (!mounted) return;

      if (child == null) {
        setState(() {
          _loading = false;
          _error = 'Wrong child code or password.';
        });
        return;
      }

      if (child.childId != null) {
        final isLocked = await SessionLockService.isLockedToday(child.childId!);
        if (isLocked) {
          setState(() {
            _loading = false;
            _error = 'LUMI is resting today! Please come back tomorrow.';
          });
          return;
        }
      }

      await AuthSessionService.instance.saveChildSession(
        childLoginCode: child.loginCode,
        childId: child.childId,
      );
      await ActiveChildContextService.instance.setActiveChildId(child.childId);

      if (!mounted) return;
      FocusManager.instance.primaryFocus?.unfocus();
      Navigator.of(context).pushNamedAndRemoveUntil('/child', (route) => false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _openParentLogin() {
    Navigator.of(context).push(authSlideRoute(const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return AuthLandingShell(
      footer: AuthGreenButton(
        label: 'Parent Login',
        onTap: _openParentLogin,
      ),
      child: AuthStagger(
        children: [
          const AuthHeader(title: 'Login', showUserIcon: true),
          const SizedBox(height: LumiSpacing.lg),
          AuthFormCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ArcadeCodeField(
                  label: 'Child Code',
                  controller: _codeController,
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
                const SizedBox(height: LumiSpacing.xl),
                AuthPrimaryButton(
                  label: _loading ? 'Please wait…' : 'Login',
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
