import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_mesh_detection/google_mlkit_face_mesh_detection.dart';

import 'services/detection_service.dart';
import 'services/metrics_service.dart';
import 'services/task_service.dart';
import 'widgets/rounded_card.dart';

class BlinkTestScreen extends StatefulWidget {
  const BlinkTestScreen({
    super.key,
    this.enforceCompletion = false,
    this.requiredIntentionalBlinks = 15,
    this.taskIdToComplete,
  });

  final bool enforceCompletion;
  final int requiredIntentionalBlinks;
  final String? taskIdToComplete; // Task ID to mark complete on success

  @override
  State<BlinkTestScreen> createState() => _BlinkTestScreenState();
}

class _BlinkTestScreenState extends State<BlinkTestScreen> {
  bool _showMesh = true;
  int _baselineBlinkCount = 0;
  bool _unlockHandled = false;

  int get _intentionalBlinkCount {
    final totalBlinks = MetricsService.instance.blinkCountNotifier.value;
    return math.max(0, totalBlinks - _baselineBlinkCount);
  }

  bool get _isUnlockComplete => _intentionalBlinkCount >= widget.requiredIntentionalBlinks;

  @override
  void initState() {
    super.initState();
    _baselineBlinkCount = MetricsService.instance.blinkCountNotifier.value;
    MetricsService.instance.blinkCountNotifier.addListener(_handleBlinkProgress);
    DetectionService.instance.ensureMonitoringWithRetry();
  }

  @override
  void dispose() {
    MetricsService.instance.blinkCountNotifier.removeListener(_handleBlinkProgress);
    super.dispose();
  }

  void _handleBlinkProgress() {
    if (!widget.enforceCompletion && widget.taskIdToComplete == null) {
      return;
    }
    if (_unlockHandled || !_isUnlockComplete || !mounted) {
      return;
    }

    _unlockHandled = true;

    // Mark task as complete if this was launched from a task
    if (widget.taskIdToComplete != null) {
      TaskService.instance.completeTask(widget.taskIdToComplete!);
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final controller = DetectionService.instance.controller;
    if (controller == null || !controller.value.isInitialized) {
      DetectionService.instance.ensureMonitoringWithRetry();
      return const Scaffold(
        backgroundColor: Color(0xFF1C1C1E),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final size = MediaQuery.of(context).size;
    var scale = size.aspectRatio * controller.value.aspectRatio;
    if (scale < 1) scale = 1 / scale;

    return PopScope(
      canPop: !widget.enforceCompletion || _isUnlockComplete,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !widget.enforceCompletion || _isUnlockComplete) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Complete ${widget.requiredIntentionalBlinks} intentional blinks to continue.',
            ),
          ),
        );
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1C1C1E),
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: !widget.enforceCompletion,
          leading: widget.enforceCompletion
              ? null
              : IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
          title: Text(
            widget.enforceCompletion ? 'Eye Safety Blink Reset' : 'Blink Rate Test',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          actions: [
            Switch.adaptive(
              value: _showMesh,
              onChanged: (v) => setState(() => _showMesh = v),
              activeColor: Colors.yellowAccent,
            )
          ],
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            Transform.scale(scale: scale, child: Center(child: CameraPreview(controller))),
            if (_showMesh)
              ValueListenableBuilder<List<FaceMeshPoint>>(
                valueListenable: DetectionService.instance.meshPoints,
                builder: (_, points, __) {
                  if (points.isEmpty) return const SizedBox.shrink();
                  return IgnorePointer(
                    child: CustomPaint(
                      painter: FaceMeshPainter(
                        points: points,
                        imageSize: Size(controller.value.previewSize!.height, controller.value.previewSize!.width),
                        widgetSize: size,
                      ),
                    ),
                  );
                },
              ),
            Positioned(
              bottom: 40,
              left: 20,
              right: 20,
              child: RoundedCard(
                borderRadius: 22,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                backgroundColor: const Color(0xFF1F1F22),
                borderColor: Colors.white70,
                child: ValueListenableBuilder<int>(
                  valueListenable: MetricsService.instance.blinkCountNotifier,
                  builder: (_, blinkCount, __) {
                    final intentionalCount = _intentionalBlinkCount;
                    final remaining = widget.requiredIntentionalBlinks - intentionalCount;
                    return ValueListenableBuilder<int>(
                      valueListenable: MetricsService.instance.blinkRatePerMinNotifier,
                      builder: (_, perMinute, __) {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.enforceCompletion ? 'Intentional Blinks' : 'Total Blinks',
                                  style: const TextStyle(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.enforceCompletion
                                      ? '$intentionalCount/${widget.requiredIntentionalBlinks}'
                                      : '$blinkCount',
                                  style: const TextStyle(fontSize: 38, fontWeight: FontWeight.bold, letterSpacing: -1, color: Color(0xFF9DE18A)),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.enforceCompletion
                                      ? (remaining > 0 ? '$remaining remaining to unlock' : 'Unlock complete')
                                      : '$perMinute/min',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFFA68AC0), fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            if (!widget.enforceCompletion)
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFD9EE),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.white70, width: 0.8),
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.refresh, size: 20, color: Colors.black87),
                                  onPressed: MetricsService.instance.resetBlinks,
                                ),
                              )
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FaceMeshPainter extends CustomPainter {
  final List<FaceMeshPoint> points;
  final Size imageSize;
  final Size widgetSize;

  FaceMeshPainter({required this.points, required this.imageSize, required this.widgetSize});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.yellowAccent.withValues(alpha: 0.5)..strokeWidth = 1.5..style = PaintingStyle.fill;
    final double scaleX = widgetSize.width / imageSize.width;
    final double scaleY = widgetSize.height / imageSize.height;
    final double scale = scaleX > scaleY ? scaleX : scaleY;
    final double offsetX = (widgetSize.width - imageSize.width * scale) / 2;
    final double offsetY = (widgetSize.height - imageSize.height * scale) / 2;

    for (var point in points) {
      double x = point.x * scale + offsetX;
      double y = point.y * scale + offsetY;
      x = widgetSize.width - x;
      canvas.drawCircle(Offset(x, y), 2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
