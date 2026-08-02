import 'package:flutter/material.dart';

import '../theme/lumi_theme.dart';

class LumiShell extends StatelessWidget {
  final Widget child;
  final Color topColor;
  final Color bottomArchColor;
  final String watermark;
  /// When false, [child] fills the safe area (needed for Expanded layouts).
  final bool scrollable;

  const LumiShell({
    super.key,
    required this.child,
    this.topColor = LumiColors.scaffoldMint,
    this.bottomArchColor = LumiColors.secondaryPurple,
    this.watermark = 'LUMI',
    this.scrollable = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: LumiSpacing.xl,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                watermark,
                style: LumiTheme.joyful(72, color: LumiColors.primaryPurple.withValues(alpha: 0.18)),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Container(
                height: 180,
                decoration: BoxDecoration(
                  color: bottomArchColor.withValues(alpha: 0.45),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(LumiRadii.xl)),
                  border: const Border(
                    top: BorderSide(color: LumiColors.secondaryLight, width: ArcadeSizes.cardBorder),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: scrollable
                ? LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        padding: EdgeInsets.zero,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: constraints.maxHeight),
                          child: child,
                        ),
                      );
                    },
                  )
                : child,
          ),
        ],
      ),
    );
  }
}
