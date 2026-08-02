import 'package:flutter/material.dart';

import 'arcade/arcade_nav.dart';

/// Legacy name — delegates to [ArcadeNavBar].
class BottomPillNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int>? onTap;
  const BottomPillNav({super.key, this.currentIndex = 0, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ArcadeNavBar(currentIndex: currentIndex, onTap: onTap);
  }
}
