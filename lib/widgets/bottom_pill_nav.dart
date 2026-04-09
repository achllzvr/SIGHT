import 'package:flutter/material.dart';

class BottomPillNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int>? onTap;
  const BottomPillNav({Key? key, this.currentIndex = 0, this.onTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navBg = isDark ? const Color(0xFF2A3A2A) : const Color(0xFFE3F1D6);
    final iconDefault = isDark ? Colors.white70 : Colors.white;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Center(
          child: Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: navBg,
              borderRadius: BorderRadius.circular(40),
              border: Border.all(color: isDark ? Colors.white70 : Colors.black87, width: 1.1),
              boxShadow: const [
                BoxShadow(color: Color(0xFFB9E3A4), offset: Offset(3, 3), blurRadius: 0),
                BoxShadow(color: Color(0xFFD5C2E8), offset: Offset(1, 1), blurRadius: 0),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(4, (i) {
                final icon = i == 0
                    ? Icons.home
                    : i == 1
                        ? Icons.video_library
                        : i == 2
                            ? Icons.monitor_heart
                            : Icons.list;
                final selected = i == currentIndex;
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(30),
                    onTap: () => onTap?.call(i),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 7),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: selected
                          ? BoxDecoration(
                              color: const Color(0xFFD5C2E8),
                              border: Border.all(color: isDark ? Colors.white70 : Colors.black87, width: 1),
                              borderRadius: BorderRadius.circular(18),
                            )
                          : null,
                      child: Icon(icon, size: 20, color: selected ? (isDark ? Colors.white : Colors.black87) : iconDefault),
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
