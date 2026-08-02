import 'package:flutter/material.dart';

import '../../theme/lumi_theme.dart';

/// Icons8 Arcade asset. Use [greyscale] / [lightMono] for inactive states.
class ArcadeIcon extends StatelessWidget {
  const ArcadeIcon(
    this.name, {
    super.key,
    this.size = 22,
    this.greyscale = false,
    this.lightMono = false,
  });

  final String name;
  final double size;
  final bool greyscale;
  final bool lightMono;

  /// Classic dark greyscale (legacy).
  static const greyscaleFilter = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0, 0, 0, 1, 0,
  ]);

  /// Soft light monochrome — very pale mint for inactive nav icons.
  static const lightMonoFilter = ColorFilter.matrix(<double>[
    0.20, 0.35, 0.10, 0, 155,
    0.18, 0.40, 0.10, 0, 165,
    0.15, 0.30, 0.12, 0, 145,
    0, 0, 0, 0.72, 0,
  ]);

  String get _asset => 'assets/icons/arcade/$name.png';

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      _asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.none,
      errorBuilder: (_, __, ___) => SizedBox(
        width: size,
        height: size,
        child: Icon(Icons.broken_image_outlined, size: size * 0.8, color: LumiColors.textMuted),
      ),
    );
    if (lightMono) {
      return ColorFiltered(colorFilter: lightMonoFilter, child: image);
    }
    if (greyscale) {
      return ColorFiltered(colorFilter: greyscaleFilter, child: image);
    }
    return image;
  }
}
