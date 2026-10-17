import 'package:flutter/material.dart';

import '../../theme/lumi_theme.dart';
import 'arcade_icon.dart';

/// Child bottom nav — soft green pill, Arcade icons, light mono when inactive.
class ArcadeNavBar extends StatelessWidget {
  const ArcadeNavBar({
    super.key,
    this.currentIndex = 0,
    this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int>? onTap;

  static const _icons = ['home', 'play', 'like', 'list'];

  @override
  Widget build(BuildContext context) {
    final scale = ArcadeSizes.chromeScale(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          LumiSpacing.lg * scale,
          LumiSpacing.sm * scale,
          LumiSpacing.lg * scale,
          LumiSpacing.md * scale,
        ),
        child: Align(
          alignment: Alignment.topCenter,
          child: Container(
            constraints: BoxConstraints(maxWidth: 520 * scale),
            padding: EdgeInsets.symmetric(horizontal: 8 * scale, vertical: 12 * scale),
            decoration: BoxDecoration(
              color: LumiColors.navFill,
              borderRadius: BorderRadius.circular(LumiRadii.pill),
              border: Border.all(
                color: LumiColors.navBorder,
                width: ArcadeSizes.navBorder,
              ),
              boxShadow: LumiShadows.float(LumiColors.navBorder),
            ),
            child: Row(
              children: List.generate(_icons.length, (i) {
                final selected = i == currentIndex;
                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onTap?.call(i),
                    child: AnimatedScale(
                      scale: selected ? 1.06 : 1.0,
                      duration: LumiMotion.normal,
                      curve: LumiMotion.easeStandard,
                      child: Center(
                        child: ArcadeIcon(
                          _icons[i],
                          size: ArcadeSizes.navIcon * scale,
                          lightMono: !selected,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
