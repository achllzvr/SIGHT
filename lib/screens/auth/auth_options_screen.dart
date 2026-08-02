import 'package:flutter/material.dart';

import '../../theme/lumi_theme.dart';
import '../../widgets/auth_landing_shell.dart';
import '../legal_gate_screen.dart';
import 'child_login_screen.dart';
import 'login_screen.dart';

/// Optional hub — primary entry is [ChildLoginScreen] via `/auth`.
class AuthOptionsScreen extends StatelessWidget {
  const AuthOptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthLandingShell(
      child: AuthStagger(
        children: [
          const AuthHeader(title: 'LUMI', showUserIcon: true),
          const SizedBox(height: LumiSpacing.lg),
          AuthFormCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Care for kids\' eyes while they play',
                  textAlign: TextAlign.center,
                  style: LumiTheme.clanRegular(14, height: 1.4),
                ),
                const SizedBox(height: LumiSpacing.xl),
                AuthPrimaryButton(
                  label: 'Parent Login',
                  onTap: () {
                    Navigator.of(context).push(authSlideRoute(const LoginScreen()));
                  },
                ),
                const SizedBox(height: LumiSpacing.md),
                AuthGreenButton(
                  label: 'Child Login',
                  onTap: () {
                    Navigator.of(context).push(authSlideRoute(const ChildLoginScreen()));
                  },
                ),
                const SizedBox(height: LumiSpacing.md),
                AuthOutlineButton(
                  label: 'Register',
                  onTap: () {
                    Navigator.of(context).push(authSlideRoute(const LegalGateScreen()));
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
