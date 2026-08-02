import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/lumi_theme.dart';

/// Soft base + faint saturated purple/green haze blobs behind child pages.
class AnimatedHueBackground extends StatefulWidget {
  const AnimatedHueBackground({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<AnimatedHueBackground> createState() => _AnimatedHueBackgroundState();
}

class _AnimatedHueBackgroundState extends State<AnimatedHueBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_HueBlob> _blobs;

  @override
  void initState() {
    super.initState();
    final rng = math.Random(7);
    _blobs = List.generate(10, (i) {
      final purple = i.isEven;
      return _HueBlob(
        x: rng.nextDouble(),
        y: rng.nextDouble(),
        radius: 48 + rng.nextDouble() * 70,
        speedX: (rng.nextDouble() - 0.5) * 0.045,
        speedY: (rng.nextDouble() - 0.5) * 0.045,
        // Saturated brand hues at very low opacity — soft wash, not solid discs.
        color: purple
            ? const Color(0xFFB07AE8) // saturated soft purple
            : const Color(0xFF6FCF4A), // saturated soft green
        opacity: 0.10 + rng.nextDouble() * 0.06,
      );
    });
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 28),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: LumiColors.primaryLight),
            CustomPaint(
              painter: _SoftBlobsPainter(blobs: _blobs, t: _controller.value),
            ),
            child ?? const SizedBox.shrink(),
          ],
        );
      },
      child: widget.child,
    );
  }
}

class _HueBlob {
  const _HueBlob({
    required this.x,
    required this.y,
    required this.radius,
    required this.speedX,
    required this.speedY,
    required this.color,
    required this.opacity,
  });

  final double x;
  final double y;
  final double radius;
  final double speedX;
  final double speedY;
  final Color color;
  final double opacity;
}

class _SoftBlobsPainter extends CustomPainter {
  _SoftBlobsPainter({required this.blobs, required this.t});

  final List<_HueBlob> blobs;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (final blob in blobs) {
      var dx = (blob.x + blob.speedX * t * 20) % 1.0;
      var dy = (blob.y + blob.speedY * t * 20) % 1.0;
      if (dx < 0) dx += 1;
      if (dy < 0) dy += 1;
      final center = Offset(dx * size.width, dy * size.height);

      final paint = Paint()
        ..shader = ui.Gradient.radial(
          center,
          blob.radius,
          [
            blob.color.withValues(alpha: blob.opacity),
            blob.color.withValues(alpha: blob.opacity * 0.35),
            blob.color.withValues(alpha: 0),
          ],
          const [0.0, 0.45, 1.0],
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28);

      canvas.drawCircle(center, blob.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SoftBlobsPainter oldDelegate) => oldDelegate.t != t;
}
