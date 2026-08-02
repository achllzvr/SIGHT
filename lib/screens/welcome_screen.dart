import 'package:flutter/material.dart';

import '../copy/lumi_strings.dart';
import '../theme/lumi_theme.dart';
import '../widgets/arcade/arcade.dart';
import '../widgets/auth_landing_shell.dart';
import 'auth/child_login_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthLandingShell(
      footer: AuthPrimaryButton(
        label: LumiStrings.getStarted,
        onTap: () {
          Navigator.of(context).pushReplacement(
            authSlideRoute(const ChildLoginScreen()),
          );
        },
      ),
      child: AuthStagger(
        children: [
          const SizedBox(height: LumiSpacing.xl),
          Text(
            LumiTheme.caps('Welcome'),
            textAlign: TextAlign.center,
            style: LumiTheme.joyful(40, color: LumiColors.primaryPurple),
          ),
          const SizedBox(height: LumiSpacing.md),
          Text(
            LumiStrings.tagline,
            textAlign: TextAlign.center,
            style: LumiTheme.clanMedium(15, color: LumiColors.textDark, height: 1.4),
          ),
          const SizedBox(height: LumiSpacing.xxl),
          Image.asset(
            'assets/mascot/mascot_great_v1.png',
            height: 180,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const ArcadeIcon('like', size: 80),
          ),
        ],
      ),
    );
  }
}
