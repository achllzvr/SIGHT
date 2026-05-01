import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_mesh_detection/google_mlkit_face_mesh_detection.dart';

import 'services/detection_service.dart';
import 'services/metrics_service.dart';
import 'widgets/rounded_card.dart';

class DistanceTestScreen extends StatefulWidget {
  const DistanceTestScreen({super.key});

  @override
  State<DistanceTestScreen> createState() => _DistanceTestScreenState();
}

class _DistanceTestScreenState extends State<DistanceTestScreen> {
  bool _showMesh = true;

  @override
  void initState() {
    super.initState();
    DetectionService.instance.ensureMonitoringWithRetry();
  }

  void _calibrate() {
    DetectionService.instance.calibrateReferenceCm(30.0);
    final calibrated = MetricsService.instance.calibratedNotifier.value;
    if (calibrated) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Calibrated.')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No face detected. Keep face centered and try again.')));
    }
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Distance Monitor', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        actions: [
          Switch.adaptive(
            value: _showMesh,
            onChanged: (v) => setState(() => _showMesh = v),
            activeColor: Colors.blueAccent,
          ),
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
          ValueListenableBuilder<bool>(
            valueListenable: DetectionService.instance.faceDetected,
            builder: (_, detected, __) {
              if (!detected) {
                return Container(
                  color: Colors.red.withValues(alpha: 0.35),
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.white, size: 80),
                      SizedBox(height: 20),
                      Text(
                        'No face detected. Keep your face in frame and retry.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
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
              child: ValueListenableBuilder<bool>(
                valueListenable: MetricsService.instance.calibratedNotifier,
                builder: (_, calibrated, __) {
                  return ValueListenableBuilder<double>(
                    valueListenable: DetectionService.instance.distanceCm,
                    builder: (_, distance, __) {
                      if (!calibrated || distance <= 0) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Calibration Required', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                            const SizedBox(height: 8),
                            const Text('Place phone exactly 30cm away from face.', style: TextStyle(fontSize: 14, color: Colors.white70)),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _calibrate,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF7FC86D),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 13),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                child: const Text('Set 30cm Reference', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        );
                      }

                      final safe = distance >= 30.0;
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Distance', style: TextStyle(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.w500)),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${distance.toStringAsFixed(1)} cm',
                                    style: TextStyle(
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold,
                                      color: safe ? const Color(0xFF9DE18A) : const Color(0xFFE9C37F),
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: safe ? const Color(0xFFEAF4E3) : const Color(0xFFEFD9EE),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white70, width: 0.8),
                                ),
                                child: Text(
                                  safe ? 'SAFE' : 'CLOSE',
                                  style: TextStyle(
                                    color: safe ? const Color(0xFF4A8D3B) : const Color(0xFF8F5A88),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            ],
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: TextButton(
                              onPressed: _calibrate,
                              child: const Text('Recalibrate', style: TextStyle(fontSize: 12.5, color: Color(0xFFA68AC0))),
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
    final paint = Paint()..color = Colors.greenAccent.withValues(alpha: 0.5)..strokeWidth = 1.5..style = PaintingStyle.fill;
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
