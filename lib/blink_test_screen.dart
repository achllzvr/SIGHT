import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_mesh_detection/google_mlkit_face_mesh_detection.dart';

import 'services/detection_service.dart';
import 'services/metrics_service.dart';
import 'widgets/rounded_card.dart';

class BlinkTestScreen extends StatefulWidget {
  const BlinkTestScreen({super.key});

  @override
  State<BlinkTestScreen> createState() => _BlinkTestScreenState();
}

class _BlinkTestScreenState extends State<BlinkTestScreen> {
  bool _showMesh = true;

  @override
  void initState() {
    super.initState();
    DetectionService.instance.ensureMonitoringWithRetry();
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

    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: const Text('Blink Rate Test', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
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
                  return ValueListenableBuilder<int>(
                    valueListenable: MetricsService.instance.blinkRatePerMinNotifier,
                    builder: (_, perMinute, __) {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Total Blinks', style: TextStyle(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text('$blinkCount', style: const TextStyle(fontSize: 38, fontWeight: FontWeight.bold, letterSpacing: -1, color: Color(0xFF9DE18A))),
                              const SizedBox(height: 4),
                              Text('$perMinute/min', style: const TextStyle(fontSize: 12, color: Color(0xFFA68AC0), fontWeight: FontWeight.w600)),
                            ],
                          ),
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
    final paint = Paint()..color = Colors.yellowAccent.withOpacity(0.5)..strokeWidth = 1.5..style = PaintingStyle.fill;
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
