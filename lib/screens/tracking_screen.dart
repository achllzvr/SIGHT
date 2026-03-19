import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_mesh_detection/google_mlkit_face_mesh_detection.dart';
import 'dart:ui';

import '../widgets/rounded_card.dart';
import '../services/detection_service.dart';

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({Key? key}) : super(key: key);

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  bool _showMesh = true;

  @override
  void initState() {
    super.initState();
    DetectionService.instance.initialize();
  }

  @override
  Widget build(BuildContext context) {
    final controller = DetectionService.instance.controller;
    if (controller == null || !controller.value.isInitialized) {
      return const Scaffold(backgroundColor: Color(0xFF1C1C1E), body: Center(child: CircularProgressIndicator()));
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
        title: const Text('Distance Monitor', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        actions: [Switch.adaptive(value: _showMesh, onChanged: (v) => setState(() => _showMesh = v), activeColor: Colors.blueAccent)],
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
                    painter: _TrackingMeshPainter(points: points, imageSize: Size(controller.value.previewSize!.height, controller.value.previewSize!.width), widgetSize: size),
                  ),
                );
              },
            ),
          ValueListenableBuilder<bool>(
            valueListenable: DetectionService.instance.faceDetected,
            builder: (_, detected, __) {
              if (!detected) return Container(color: Colors.red.withOpacity(0.4));
              return const SizedBox.shrink();
            },
          ),
          Positioned(
            bottom: 40, left: 20, right: 20,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  color: const Color(0xFF2C2C2E).withOpacity(0.9),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ValueListenableBuilder<double>(
                        valueListenable: DetectionService.instance.distanceCm,
                        builder: (_, value, __) {
                          if (value <= 0) {
                            return Column(
                              children: [
                                const Text('Calibration Required', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                                const SizedBox(height: 8),
                                const Text('Place phone exactly 30cm away from face.', style: TextStyle(fontSize: 14, color: Colors.white70)),
                                const SizedBox(height: 20),
                                SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => DetectionService.instance.calibrateReferenceCm(30.0), style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white, padding: EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: const Text('Set 30cm Reference', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)))),
                              ],
                            );
                          }
                          return Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Distance', style: TextStyle(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.w500)), const SizedBox(height: 4), Text('${value.toStringAsFixed(1)} cm', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white))]),
                                  Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: Colors.green.withOpacity(0.2), borderRadius: BorderRadius.circular(12)), child: const Text('Safe', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)))
                                ],
                              ),
                              const SizedBox(height: 16),
                              SizedBox(width: double.infinity, child: TextButton(onPressed: () => DetectionService.instance.calibrateReferenceCm(30.0), child: const Text('Recalibrate', style: TextStyle(color: Colors.blueAccent)))),
                            ],
                          );
                        },
                      )
                    ],
                  ),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}

class _TrackingMeshPainter extends CustomPainter {
  final List<FaceMeshPoint> points; final Size imageSize; final Size widgetSize;
  _TrackingMeshPainter({required this.points, required this.imageSize, required this.widgetSize});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.greenAccent.withOpacity(0.5)..strokeWidth = 1.5..style = PaintingStyle.fill;
    final double scaleX = widgetSize.width / imageSize.width; final double scaleY = widgetSize.height / imageSize.height; final double scale = scaleX > scaleY ? scaleX : scaleY; final double offsetX = (widgetSize.width - imageSize.width * scale) / 2; final double offsetY = (widgetSize.height - imageSize.height * scale) / 2;
    for (var point in points) { double x = point.x * scale + offsetX; double y = point.y * scale + offsetY; x = widgetSize.width - x; canvas.drawCircle(Offset(x, y), 2, paint); }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
