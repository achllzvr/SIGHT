import 'package:flutter/material.dart';

import '../theme/lumi_theme.dart';
import 'arcade/arcade_icon.dart';

/// Mint top + white curved sheet used by all auth landing screens.
class AuthLandingShell extends StatelessWidget {
  const AuthLandingShell({
    super.key,
    required this.child,
    this.footer,
  });

  final Widget child;
  final Widget? footer;

  static const _mint = Color(0xFFE8F5E0);

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    final h = MediaQuery.sizeOf(context).height;

    return Scaffold(
      backgroundColor: _mint,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: _mint),
          // Faint repeating LUMI watermark (matches mock).
          Positioned(
            top: topPad,
            left: -24,
            right: -24,
            height: h * 0.28,
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.18,
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: Text(
                    'LUMI  LUMI\nLUMI  LUMI',
                    textAlign: TextAlign.center,
                    style: LumiTheme.joyful(96, color: LumiColors.primaryGreen),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: h * 0.14,
            left: 0,
            right: 0,
            bottom: 0,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeOutCubic,
              builder: (context, t, sheet) {
                return Transform.translate(
                  offset: Offset(0, (1 - t) * 28),
                  child: Opacity(opacity: t.clamp(0.0, 1.0), child: sheet ?? const SizedBox.shrink()),
                );
              },
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: LumiColors.primaryLight,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(64)),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(
                            LumiSpacing.lg,
                            LumiSpacing.xl,
                            LumiSpacing.lg,
                            LumiSpacing.md,
                          ),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 420),
                              child: child,
                            ),
                          ),
                        ),
                      ),
                      if (footer != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            LumiSpacing.xl,
                            0,
                            LumiSpacing.xl,
                            LumiSpacing.lg,
                          ),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 420),
                              child: footer!,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AuthHeader extends StatelessWidget {
  const AuthHeader({
    super.key,
    required this.title,
    this.showBack = false,
    this.onBack,
    this.showUserIcon = false,
  });

  final String title;
  final bool showBack;
  final VoidCallback? onBack;
  final bool showUserIcon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (showBack)
          _AuthRoundButton(
            onTap: onBack ?? () => Navigator.maybePop(context),
            child: const ArcadeIcon('back', size: 22),
          )
        else if (showUserIcon)
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 0,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const ArcadeIcon('user', size: 48),
          ),
        if (showBack || showUserIcon) const SizedBox(width: LumiSpacing.md),
        Expanded(
          child: Text(
            LumiTheme.caps(title),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: LumiTheme.joyful(24, color: LumiColors.textDark),
          ),
        ),
      ],
    );
  }
}

class AuthFormCard extends StatelessWidget {
  const AuthFormCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        color: LumiColors.primaryLight,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: LumiColors.secondaryLight, width: ArcadeSizes.cardBorder),
        boxShadow: [
          BoxShadow(
            color: LumiColors.secondaryLight.withValues(alpha: 0.85),
            blurRadius: 0,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final active = enabled && onTap != null;
    return GestureDetector(
      onTap: active ? onTap : null,
      child: AnimatedOpacity(
        duration: LumiMotion.fast,
        opacity: active ? 1 : 0.55,
        child: Container(
          width: double.infinity,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: LumiColors.secondaryPurple,
            borderRadius: BorderRadius.circular(LumiRadii.pill),
            border: Border.all(color: LumiColors.primaryPurple, width: ArcadeSizes.buttonBorder),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: LumiColors.primaryPurple.withValues(alpha: 0.45),
                      blurRadius: 0,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : const [],
          ),
          child: Text(
            LumiTheme.caps(label),
            style: LumiTheme.clanMedium(16, color: LumiColors.primaryPurple, letterSpacing: 1.1),
          ),
        ),
      ),
    );
  }
}

class AuthOutlineButton extends StatelessWidget {
  const AuthOutlineButton({
    super.key,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: LumiColors.primaryLight,
          borderRadius: BorderRadius.circular(LumiRadii.pill),
          border: Border.all(color: LumiColors.primaryPurple, width: ArcadeSizes.buttonBorder),
        ),
        child: Text(
          LumiTheme.caps(label),
          style: LumiTheme.clanMedium(16, color: LumiColors.primaryPurple, letterSpacing: 1.1),
        ),
      ),
    );
  }
}

class AuthGreenButton extends StatelessWidget {
  const AuthGreenButton({
    super.key,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: LumiColors.secondaryGreen,
          borderRadius: BorderRadius.circular(LumiRadii.pill),
          border: Border.all(color: LumiColors.primaryGreen, width: ArcadeSizes.buttonBorder),
          boxShadow: [
            BoxShadow(
              color: LumiColors.primaryGreen.withValues(alpha: 0.35),
              blurRadius: 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          LumiTheme.caps(label),
          style: LumiTheme.clanMedium(16, color: LumiColors.primaryGreen, letterSpacing: 1.1),
        ),
      ),
    );
  }
}

class AuthFooterPrompt extends StatelessWidget {
  const AuthFooterPrompt({
    super.key,
    required this.prompt,
    required this.buttonLabel,
    required this.onTap,
  });

  final String prompt;
  final String buttonLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          prompt,
          textAlign: TextAlign.center,
          style: LumiTheme.clanMedium(14, color: LumiColors.textDark),
        ),
        const SizedBox(height: LumiSpacing.sm),
        AuthGreenButton(label: buttonLabel, onTap: onTap),
      ],
    );
  }
}

class _AuthRoundButton extends StatelessWidget {
  const _AuthRoundButton({
    required this.onTap,
    required this.child,
  });

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: LumiColors.primaryPurple,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

/// Shared page transition for auth screens.
Route<T> authSlideRoute<T extends Object?>(
  Widget page, {
  bool reverse = false,
}) {
  return PageRouteBuilder<T>(
    pageBuilder: (_, __, ___) => page,
    transitionDuration: const Duration(milliseconds: 380),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      final outCurved = CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeInCubic);
      final begin = Offset(reverse ? -0.1 : 0.1, 0.03);
      return SlideTransition(
        position: Tween<Offset>(begin: Offset.zero, end: Offset(reverse ? 0.06 : -0.06, 0))
            .animate(outCurved),
        child: FadeTransition(
          opacity: Tween<double>(begin: 1, end: 0.86).animate(outCurved),
          child: FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(begin: begin, end: Offset.zero).animate(curved),
              child: child,
            ),
          ),
        ),
      );
    },
  );
}
