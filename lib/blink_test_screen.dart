import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'services/critical_overlay_service.dart';
import 'services/detection_service.dart';
import 'services/metrics_service.dart';
import 'services/task_service.dart';
import 'theme/lumi_theme.dart';
import 'widgets/lumi_game_kit.dart';

enum _BlinkGamePhase { ready, playing, done }

/// Blinking Game modal — progress bar with mascot thumb (no circle grid).
class BlinkTestScreen extends StatefulWidget {
  const BlinkTestScreen({
    super.key,
    this.enforceCompletion = false,
    this.requiredIntentionalBlinks = 15,
    this.taskIdToComplete,
  });

  final bool enforceCompletion;
  final int requiredIntentionalBlinks;
  final String? taskIdToComplete;

  @override
  State<BlinkTestScreen> createState() => _BlinkTestScreenState();
}

class _BlinkTestScreenState extends State<BlinkTestScreen> {
  _BlinkGamePhase _phase = _BlinkGamePhase.ready;
  int _baselineBlinkCount = 0;
  bool _unlockHandled = false;
  bool _cameraReady = false;
  bool _cameraError = false;

  int get _required => widget.requiredIntentionalBlinks.clamp(1, 20);

  int get _intentionalBlinkCount {
    final totalBlinks = MetricsService.instance.blinkCountNotifier.value;
    return math.max(0, totalBlinks - _baselineBlinkCount);
  }

  bool get _isUnlockComplete => _intentionalBlinkCount >= _required;

  double get _progress => (_intentionalBlinkCount.clamp(0, _required) / _required).clamp(0.0, 1.0);

  @override
  void initState() {
    super.initState();
    DetectionService.instance.faceDetected.addListener(_onFaceChanged);
    unawaited(_startCamera());
  }

  Future<void> _startCamera() async {
    try {
      await DetectionService.instance.acquireMonitoring(resolution: ResolutionPreset.medium);
      if (!mounted) return;
      setState(() {
        _cameraReady = true;
        _cameraError = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _phase == _BlinkGamePhase.ready) {
          _startGame();
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cameraReady = false;
        _cameraError = true;
      });
    }
  }

  void _onFaceChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    DetectionService.instance.faceDetected.removeListener(_onFaceChanged);
    MetricsService.instance.blinkCountNotifier.removeListener(_handleBlinkProgress);
    unawaited(DetectionService.instance.releaseMonitoring());
    unawaited(CriticalOverlayService.instance.hideCriticalOverlay());
    super.dispose();
  }

  void _startGame() {
    if (!_cameraReady) return;
    setState(() {
      _phase = _BlinkGamePhase.playing;
      _baselineBlinkCount = MetricsService.instance.blinkCountNotifier.value;
      _unlockHandled = false;
    });
    MetricsService.instance.blinkCountNotifier.addListener(_handleBlinkProgress);
  }

  void _handleBlinkProgress() {
    if (_phase != _BlinkGamePhase.playing || !mounted) return;
    setState(() {});
    if (_isUnlockComplete) {
      setState(() => _phase = _BlinkGamePhase.done);
      MetricsService.instance.blinkCountNotifier.removeListener(_handleBlinkProgress);
    }
  }

  Future<void> _finish() async {
    if (_unlockHandled) return;
    if (widget.enforceCompletion && !_isUnlockComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Blink $_required times to finish.')),
      );
      return;
    }
    _unlockHandled = true;
    if (widget.taskIdToComplete != null) {
      TaskService.instance.completeTask(widget.taskIdToComplete!);
    }
    await CriticalOverlayService.instance.hideCriticalOverlay();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final canPop = !widget.enforceCompletion || _isUnlockComplete;
    final faceOk = DetectionService.instance.faceDetected.value;

    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || canPop) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Blink $_required times to keep going.')),
        );
      },
      child: Scaffold(
        backgroundColor: Colors.black.withValues(alpha: 0.55),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Container(
                  decoration: BoxDecoration(
                    color: LumiColors.cardWhite,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: LumiColors.outline, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: LumiColors.shadowFor(LumiColors.cardWhite),
                        offset: const Offset(0, LumiColors.pressShadowY),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Time to start our',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: LumiColors.textDark),
                      ),
                      const Text(
                        'BLINKING GAME!',
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: LumiColors.textDark, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Blink to fill the bar!',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: LumiColors.textDark),
                      ),
                      if (_phase == _BlinkGamePhase.playing && _cameraReady && !faceOk) ...[
                        const SizedBox(height: 10),
                        const Text(
                          'Looking for your face…',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: LumiColors.textMuted),
                        ),
                      ],
                      if (_cameraError) ...[
                        const SizedBox(height: 10),
                        const Text(
                          'Oops! Camera needs a quick boost. Close and try again.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: LumiColors.redAlert),
                        ),
                      ],
                      const SizedBox(height: 22),
                      _buildGameBoard(),
                      const SizedBox(height: 20),
                      _buildActionButton(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGameBoard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F2F7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: LumiColors.outline, width: 1.4),
      ),
      child: Column(
        children: [
          _buildProgressBarWithMascot(),
          const SizedBox(height: 14),
          Text(
            'Blinks: ${_intentionalBlinkCount.clamp(0, _required)} / $_required',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: LumiColors.textDark),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBarWithMascot() {
    final fill = _phase == _BlinkGamePhase.ready ? 0.0 : _progress;
    return SizedBox(
      height: 44,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          const thumb = 36.0;
          final petX = (fill * (w - thumb)).clamp(0.0, w - thumb);
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 11,
                child: Container(
                  height: 22,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: LumiColors.outline, width: 1.4),
                    color: LumiColors.coralTrack,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: fill <= 0 ? 0.001 : fill,
                      child: Container(color: LumiColors.greenSoft),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: petX,
                top: 0,
                child: Image.asset(
                  'assets/mascot/mascot_head_v1.png',
                  width: thumb,
                  height: thumb,
                  errorBuilder: (_, __, ___) => Container(
                    width: thumb,
                    height: thumb,
                    decoration: BoxDecoration(
                      color: LumiColors.greenSoft,
                      shape: BoxShape.circle,
                      border: Border.all(color: LumiColors.outline, width: 1.4),
                    ),
                    child: const Icon(Icons.pets, size: 18),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildActionButton() {
    late final String label;
    late final VoidCallback? onPressed;
    late final Color bg;

    switch (_phase) {
      case _BlinkGamePhase.ready:
        label = _cameraError
            ? 'CAMERA NEEDED'
            : (_cameraReady ? 'GET READY…' : 'GETTING CAMERA…');
        onPressed = null;
        bg = const Color(0xFFD8C6EB);
        break;
      case _BlinkGamePhase.playing:
        label = _isUnlockComplete ? 'FINISH GAME' : 'YOU\'RE DOING GREAT!';
        onPressed = _isUnlockComplete ? _finish : null;
        bg = _isUnlockComplete ? LumiColors.purpleSoft : const Color(0xFFD8C6EB);
        break;
      case _BlinkGamePhase.done:
        label = 'FINISH GAME';
        onPressed = _finish;
        bg = LumiColors.purpleSoft;
        break;
    }

    return LumiPressButton(
      label: label,
      onPressed: onPressed,
      backgroundColor: bg,
    );
  }
}
