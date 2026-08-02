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
            child: AuthFadeUp(
              delay: const Duration(milliseconds: 40),
              offsetY: 28,
              duration: const Duration(milliseconds: 480),
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
                              child: AuthFadeUp(
                                delay: const Duration(milliseconds: 220),
                                offsetY: 14,
                                child: footer!,
                              ),
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

/// Soft fade + rise entrance used across auth cards and controls.
class AuthFadeUp extends StatefulWidget {
  const AuthFadeUp({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 420),
    this.offsetY = 18,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final double offsetY;

  @override
  State<AuthFadeUp> createState() => _AuthFadeUpState();
}

class _AuthFadeUpState extends State<AuthFadeUp> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final Animation<double> _opacity = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: Offset(0, widget.offsetY / 100),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}

/// Staggers children with successive fade-up delays.
class AuthStagger extends StatelessWidget {
  const AuthStagger({
    super.key,
    required this.children,
    this.step = const Duration(milliseconds: 80),
    this.initialDelay = const Duration(milliseconds: 90),
  });

  final List<Widget> children;
  final Duration step;
  final Duration initialDelay;

  @override
  Widget build(BuildContext context) {
    var animIndex = 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final child in children)
          if (child is SizedBox)
            child
          else
            AuthFadeUp(
              delay: initialDelay + (step * (animIndex++)),
              offsetY: 16,
              child: child,
            ),
      ],
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
                  color: LumiColors.primaryPurple.withValues(alpha: 0.28),
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
        boxShadow: const [
          BoxShadow(
            color: LumiColors.secondaryLight,
            blurRadius: 0,
            offset: Offset(0, 6),
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
    const accent = LumiColors.primaryPurple;
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
            border: Border.all(color: accent, width: ArcadeSizes.buttonBorder),
            boxShadow: active
                ? const [
                    BoxShadow(
                      color: accent,
                      blurRadius: 0,
                      offset: Offset(0, 4),
                    ),
                  ]
                : const [],
          ),
          child: Text(
            LumiTheme.caps(label),
            style: LumiTheme.clanMedium(16, color: accent, letterSpacing: 1.1),
          ),
        ),
      ),
    );
  }
}

/// White fill + colored border/text — secondary auth option CTA.
class AuthOutlineButton extends StatelessWidget {
  const AuthOutlineButton({
    super.key,
    required this.label,
    required this.onTap,
    this.accent = LumiColors.primaryPurple,
  });

  final String label;
  final VoidCallback? onTap;
  final Color accent;

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
          border: Border.all(color: accent, width: ArcadeSizes.buttonBorder),
          boxShadow: [
            BoxShadow(
              color: accent,
              blurRadius: 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          LumiTheme.caps(label),
          style: LumiTheme.clanMedium(16, color: accent, letterSpacing: 1.1),
        ),
      ),
    );
  }
}

/// Secondary option button — white background, green border/text/shadow.
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
    return AuthOutlineButton(
      label: label,
      onTap: onTap,
      accent: LumiColors.primaryGreen,
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
        decoration: const BoxDecoration(
          color: LumiColors.primaryPurple,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: LumiColors.primaryPurple,
              blurRadius: 0,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

/// Shared auth page transition — soft fade + rise.
Route<T> authSlideRoute<T extends Object?>(
  Widget page, {
  bool reverse = false,
}) {
  return PageRouteBuilder<T>(
    pageBuilder: (_, __, ___) => page,
    transitionDuration: const Duration(milliseconds: 420),
    reverseTransitionDuration: const Duration(milliseconds: 280),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      final outgoing = CurvedAnimation(
        parent: secondaryAnimation,
        curve: Curves.easeInCubic,
      );

      final enterBegin = reverse ? const Offset(0, -0.025) : const Offset(0, 0.045);

      return FadeTransition(
        opacity: Tween<double>(begin: 1, end: 0.92).animate(outgoing),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: Offset.zero,
            end: reverse ? const Offset(0, 0.02) : const Offset(0, -0.015),
          ).animate(outgoing),
          child: FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(begin: enterBegin, end: Offset.zero).animate(curved),
              child: child,
            ),
          ),
        ),
      );
    },
  );
}
