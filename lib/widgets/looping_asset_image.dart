import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Plays a multi-frame asset (animated WebP/GIF) in a continuous loop.
///
/// Flutter's [Image.asset] often freezes animated WebP on the first frame on
/// mobile; this widget drives frames via [ui.instantiateImageCodec] instead.
class LoopingAssetImage extends StatefulWidget {
  const LoopingAssetImage({
    super.key,
    required this.asset,
    this.fit = BoxFit.contain,
    this.width,
    this.height,
    this.alignment = Alignment.center,
  });

  final String asset;
  final BoxFit fit;
  final double? width;
  final double? height;
  final AlignmentGeometry alignment;

  @override
  State<LoopingAssetImage> createState() => _LoopingAssetImageState();
}

class _LoopingAssetImageState extends State<LoopingAssetImage> {
  ui.Codec? _codec;
  ui.Image? _frame;
  Timer? _timer;
  int _loadGen = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load(widget.asset));
  }

  @override
  void didUpdateWidget(covariant LoopingAssetImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset != widget.asset) {
      unawaited(_load(widget.asset));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _loadGen++;
    _frame?.dispose();
    _codec?.dispose();
    super.dispose();
  }

  Future<void> _load(String asset) async {
    final gen = ++_loadGen;
    _timer?.cancel();
    _timer = null;
    _codec?.dispose();
    _codec = null;
    _frame?.dispose();
    _frame = null;

    try {
      final data = await rootBundle.load(asset);
      if (!mounted || gen != _loadGen) return;
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
        allowUpscaling: false,
      );
      if (!mounted || gen != _loadGen) {
        codec.dispose();
        return;
      }
      _codec = codec;
      await _advance(gen);
    } catch (_) {
      if (mounted && gen == _loadGen) setState(() {});
    }
  }

  Future<void> _advance(int gen) async {
    final codec = _codec;
    if (codec == null || !mounted || gen != _loadGen) return;

    final info = await codec.getNextFrame();
    if (!mounted || gen != _loadGen) {
      info.image.dispose();
      return;
    }

    final previous = _frame;
    setState(() => _frame = info.image);
    previous?.dispose();

    final ms = info.duration.inMilliseconds;
    final delay = Duration(milliseconds: ms > 0 ? ms : 33);
    _timer = Timer(delay, () => unawaited(_advance(gen)));
  }

  @override
  Widget build(BuildContext context) {
    final image = _frame;
    if (image == null) {
      return SizedBox(width: widget.width, height: widget.height);
    }
    return RawImage(
      image: image,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      alignment: widget.alignment,
      filterQuality: FilterQuality.medium,
    );
  }
}
