import 'package:flutter/material.dart';
import 'package:google_mlkit_face_mesh_detection/google_mlkit_face_mesh_detection.dart';

class FaceMeshPainter extends CustomPainter {
  final List<FaceMeshPoint> points;
  final Size imageSize;
  final Size screenSize;
  final CameraLensDirection lensDirection;

  FaceMeshPainter({
    required this.points,
    required this.imageSize,
    required this.screenSize,
    required this.lensDirection,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.greenAccent
      ..strokeWidth = 1.5
      ..style = PaintingStyle.fill;

    // Calculate scale to fit the screen (Cover mode)
    final double scaleX = screenSize.width / imageSize.height; 
    final double scaleY = screenSize.height / imageSize.width; 
    final double scale = scaleX > scaleY ? scaleX : scaleY;

    // Center offset
    final double offsetX = (screenSize.width - (imageSize.height * scale)) / 2;
    final double offsetY = (screenSize.height - (imageSize.width * scale)) / 2;

    for (var point in points) {
      // 1. Rotate coordinates (Camera image is landscape, screen is portrait)
      double x, y;
      
      if (Platform.isAndroid) {
         // Android: Swap X/Y and mirror X for front camera
         x = point.y * scale + offsetX; 
         y = point.x * scale + offsetY; 
         if (lensDirection == CameraLensDirection.front) {
           x = screenSize.width - x; 
         }
      } else {
         // iOS: Standard mapping
         x = point.x * scale + offsetX; 
         y = point.y * scale + offsetY; 
      }

      canvas.drawCircle(Offset(x, y), 2, paint);
    }
  }

  // Helper to detect platform without importing dart:io everywhere
  bool get IsAndroid => false; // We handle this logic inside the calling widget usually, 
  // but for simplicity, we just use the raw coordinates assuming standard camera rotation.

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}