import 'package:flutter/material.dart';

import '../copy/lumi_strings.dart';
import '../services/auth_session_service.dart';
import '../theme/lumi_theme.dart';
import '../widgets/lumi_shell.dart';
import '../widgets/rounded_card.dart';
import 'welcome_screen.dart';

/// Shown when a child signs in before the parent finishes camera/setup onboarding.
class ChildSetupGateScreen extends StatelessWidget {
  const ChildSetupGateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LumiShell(
        watermark: LumiStrings.brand,
        child: Padding(
          padding: const EdgeInsets.all(LumiSpacing.lg),
          child: Center(
            child: RoundedCard(
              padding: const EdgeInsets.all(LumiSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(LumiStrings.askParentSetupTitle, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
                  const SizedBox(height: LumiSpacing.md),
                  Text(LumiStrings.askParentSetupBody, style: Theme.of(context).textTheme.bodyLarge, textAlign: TextAlign.center),
                  const SizedBox(height: LumiSpacing.lg),
                  ElevatedButton(
                    onPressed: () async {
                      await AuthSessionService.instance.clearSession();
                      if (!context.mounted) return;
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                        (_) => false,
                      );
                    },
                    child: const Text('Back to start'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
