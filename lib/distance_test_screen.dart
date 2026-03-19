import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_face_mesh_detection/google_mlkit_face_mesh_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:typed_data';
import 'dart:io'; 
import 'dart:ui'; 
import 'services/metrics_service.dart';

class DistanceTestScreen extends StatefulWidget {
  const DistanceTestScreen({super.key});

  @override
  State<DistanceTestScreen> createState() => _DistanceTestScreenState();
}

class _DistanceTestScreenState extends State<DistanceTestScreen> {
  CameraController? _controller;
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(enableLandmarks: true, performanceMode: FaceDetectorMode.accurate),
  );
  final FaceMeshDetector _meshDetector = FaceMeshDetector(option: FaceMeshDetectorOptions.faceMesh);
  
  List<FaceMeshPoint> _meshPoints = [];
  bool _showMesh = true;
  bool _isProcessing = false;
  int _lastRun = 0; 
  bool _faceDetected = false;
  double? _calibrationConstant; 
  double _currentDistanceCm = 0.0;
  double _currentFaceWidth = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    await Permission.camera.request();
    final cameras = await availableCameras();
    final frontCamera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );
    _controller = CameraController(frontCamera, ResolutionPreset.medium, enableAudio: false);
    await _controller!.initialize();
    if (mounted) {
      setState(() {});
      _controller!.startImageStream(_processCameraImage);
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    final int now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastRun < 100) return; 
    if (_isProcessing) return;
    _isProcessing = true;
    _lastRun = now;

    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) return;

      final faces = await _faceDetector.processImage(inputImage);
      if (faces.isNotEmpty) {
        final face = faces.first;
        _currentFaceWidth = face.boundingBox.width;
        _faceDetected = true;
        if (_calibrationConstant != null && _currentFaceWidth > 0) {
          _currentDistanceCm = _calibrationConstant! / _currentFaceWidth;
          MetricsService.instance.setDistance(_currentDistanceCm);
          MetricsService.instance.setFaceDetected(true);
        }
      } else {
        _faceDetected = false;
        _currentDistanceCm = 0.0;
        MetricsService.instance.setFaceDetected(false);
        MetricsService.instance.setDistance(0.0);
      }

      if (_showMesh) {
        try {
          final meshes = await _meshDetector.processImage(inputImage);
          if (meshes.isNotEmpty) _meshPoints = meshes.first.points;
          else _meshPoints = [];
        } catch (e) {
          // Mesh failed, ignore
        }
      }
      if (mounted) setState(() {});
    } catch (e) {
      print("Error: $e");
    } finally {
      _isProcessing = false;
    }
  }

  void _calibrate() {
    if (!_faceDetected || _currentFaceWidth == 0) return;
    setState(() {
      _calibrationConstant = 30.0 * _currentFaceWidth;
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Calibrated.")));
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(backgroundColor: Color(0xFF1C1C1E), body: Center(child: CircularProgressIndicator()));
    }

    final size = MediaQuery.of(context).size;
    var scale = size.aspectRatio * _controller!.value.aspectRatio;
    if (scale < 1) scale = 1 / scale;
    bool showRedScreen = !_faceDetected || (_calibrationConstant != null && _currentDistanceCm < 10);

    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E), // Dark Background
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Distance Monitor", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
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
          Transform.scale(
            scale: scale,
            child: Center(child: CameraPreview(_controller!)),
          ),
          if (_showMesh && _meshPoints.isNotEmpty && _faceDetected)
            IgnorePointer(
              child: CustomPaint(
                painter: FaceMeshPainter(
                  points: _meshPoints,
                  imageSize: Size(_controller!.value.previewSize!.height, _controller!.value.previewSize!.width),
                  widgetSize: size,
                ),
              ),
            ),
          if (showRedScreen)
            Container(
              color: Colors.red.withOpacity(0.4),
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 80),
                  const SizedBox(height: 20),
                  const Text(
                    "You are either too close and need to place your phone farther or there is no face in-frame",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(blurRadius: 10, color: Colors.black45, offset: Offset(0, 2))]
                    ),
                  ),
                ],
              ),
            ),
          if (_faceDetected && !showRedScreen)
            Positioned(
              bottom: 40,
              left: 20,
              right: 20,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    // Dark Frosted Card
                    color: const Color(0xFF2C2C2E).withOpacity(0.9), 
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_calibrationConstant == null) ...[
                          const Text(
                            "Calibration Required",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "Place phone exactly 30cm away from face.",
                            style: TextStyle(fontSize: 14, color: Colors.white70),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _calibrate,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blueAccent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: const Text("Set 30cm Reference", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ] else ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Distance",
                                    style: TextStyle(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "${_currentDistanceCm.toStringAsFixed(1)} cm",
                                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  "Safe",
                                  style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold),
                                ),
                              )
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: TextButton(
                              onPressed: () => setState(() => _calibrationConstant = null),
                              child: const Text("Recalibrate", style: TextStyle(color: Colors.blueAccent)),
                            ),
                          )
                        ]
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // --- UTILS (Hidden for brevity, keep same) ---
  InputImage? _inputImageFromCameraImage(CameraImage image) {
    // Keep your existing YUV converter logic here
    final camera = _controller!.description;
    final rotation = InputImageRotationValue.fromRawValue(camera.sensorOrientation) ?? InputImageRotation.rotation270deg;
    if (image.format.group == ImageFormatGroup.yuv420) {
      return InputImage.fromBytes(bytes: _yuv420ToNv21(image), metadata: InputImageMetadata(size: Size(image.width.toDouble(), image.height.toDouble()), rotation: rotation, format: InputImageFormat.nv21, bytesPerRow: image.width));
    } else if (image.format.group == ImageFormatGroup.bgra8888) {
      return InputImage.fromBytes(bytes: image.planes[0].bytes, metadata: InputImageMetadata(size: Size(image.width.toDouble(), image.height.toDouble()), rotation: rotation, format: InputImageFormat.bgra8888, bytesPerRow: image.planes[0].bytesPerRow));
    }
    return null;
  }
  Uint8List _yuv420ToNv21(CameraImage image) {
    final int width = image.width; final int height = image.height; final Plane yPlane = image.planes[0]; final Plane uPlane = image.planes[1]; final Plane vPlane = image.planes[2]; final Uint8List yBuffer = yPlane.bytes; final Uint8List uBuffer = uPlane.bytes; final Uint8List vBuffer = vPlane.bytes; final int numPixels = (width * height * 1.5).toInt(); final Uint8List nv21 = Uint8List(numPixels); int idY = 0; for (int i = 0; i < height; i++) { int srcPos = i * yPlane.bytesPerRow; for (int j = 0; j < width; j++) { nv21[idY++] = yBuffer[srcPos + j]; } } int idUV = width * height; final int uvHeight = height ~/ 2; final int uvWidth = width ~/ 2; final int uPixelStride = uPlane.bytesPerPixel ?? 1; final int uRowStride = uPlane.bytesPerRow; final int vPixelStride = vPlane.bytesPerPixel ?? 1; final int vRowStride = vPlane.bytesPerRow; for (int i = 0; i < uvHeight; i++) { for (int j = 0; j < uvWidth; j++) { int uIndex = i * uRowStride + j * uPixelStride; int vIndex = i * vRowStride + j * vPixelStride; nv21[idUV++] = vBuffer[vIndex]; nv21[idUV++] = uBuffer[uIndex]; } } return nv21;
  }
  @override
  void dispose() { _controller?.dispose(); _faceDetector.close(); _meshDetector.close(); super.dispose(); }
}

// --- PAINTER (cleaned) ---
class FaceMeshPainter extends CustomPainter {
  final List<FaceMeshPoint> points;
  final Size imageSize;
  final Size widgetSize;

  FaceMeshPainter({required this.points, required this.imageSize, required this.widgetSize});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.greenAccent.withOpacity(0.5)..strokeWidth = 1.5..style = PaintingStyle.fill;
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