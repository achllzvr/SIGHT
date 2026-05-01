import 'package:flutter/material.dart';

class LumiShell extends StatelessWidget {
  final Widget child;
  final Color topColor;
  final Color bottomArchColor;
  final String watermark;

  const LumiShell({
    super.key,
    required this.child,
    this.topColor = const Color(0xFFD8EED8),
    this.bottomArchColor = const Color(0xFFF0F0F8),
    this.watermark = 'SIGHT',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(color: topColor),
      child: Stack(
        children: [
          Positioned(
            top: 20,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                watermark,
                style: TextStyle(
                  fontSize: 110,
                  fontWeight: FontWeight.w900,
                  color: Colors.white.withValues(alpha: 0.28),
                  letterSpacing: 3,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 210,
              decoration: BoxDecoration(
                color: bottomArchColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(120)),
              ),
            ),
          ),
          SafeArea(child: child),
        ],
      ),
    );
  }
}
