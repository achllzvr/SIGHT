import 'package:flutter/material.dart';

/// A rounded card with a thick ink-style outline and subtle dual shadow.
class RoundedCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  const RoundedCard({
    Key? key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 18,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: Colors.black87, width: 1.6),
        boxShadow: [
          // subtle colored offset shadow to mimic design
          BoxShadow(
            color: Colors.green.withOpacity(0.08),
            offset: const Offset(6, 6),
            blurRadius: 0,
          ),
          BoxShadow(
            color: Colors.purple.withOpacity(0.06),
            offset: const Offset(2, 2),
            blurRadius: 0,
          ),
        ],
      ),
      child: child,
    );
  }
}
