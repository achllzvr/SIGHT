import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_face_mesh_detection/google_mlkit_face_mesh_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:typed_data';
import 'services/metrics_service.dart';
import 'services/detection_service.dart';
import 'dart:io';
import 'widgets/rounded_card.dart';
import 'main.dart' as app;

class BlinkTestScreen extends StatefulWidget {
  const BlinkTestScreen({super.key});

  @override
  State<BlinkTestScreen> createState() => _BlinkTestScreenState();
}

class _BlinkTestScreenState extends State<BlinkTestScreen> {
  CameraController? _controller;
  final FaceDetector _faceDetector = FaceDetector(options: FaceDetectorOptions(enableClassification: true, performanceMode: FaceDetectorMode.fast));
  final FaceMeshDetector _meshDetector = FaceMeshDetector(option: FaceMeshDetectorOptions.faceMesh);
  List<FaceMeshPoint> _meshPoints = [];
  bool _showMesh = true;
  bool _isProcessing = false;
  int _lastMeshRun = 0;
  static const int _meshIntervalMs = 66;
  int _blinkCount = 0;
  bool _eyesClosed = false; 

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final permission = await Permission.camera.status;
    if (!permission.isGranted) {
      final requested = await Permission.camera.request();
      if (!requested.isGranted) return;
    }

    final cameras = app.cameras.isNotEmpty ? app.cameras : await availableCameras();
    final frontCamera = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.front, orElse: () => cameras.first);
    _controller = CameraController(
      frontCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );
    await _controller!.initialize();
    if (mounted) {
      setState(() {});
      _controller!.startImageStream(_processCameraImage);
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isProcessing) return;
    _isProcessing = true;
    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) return;
      final faces = await _faceDetector.processImage(inputImage);
          if (faces.isNotEmpty) {
        final face = faces.first;
        if (face.leftEyeOpenProbability != null && face.rightEyeOpenProbability != null) {
          final avg = (face.leftEyeOpenProbability! + face.rightEyeOpenProbability!) / 2.0;
          final currentlyClosed = avg < 0.38;
          if (currentlyClosed && !_eyesClosed) _eyesClosed = true;
                else if (avg > 0.58 && _eyesClosed) {
                _eyesClosed = false;
                // register blink in central metrics service
                if (mounted) setState(() => _blinkCount++);
                MetricsService.instance.registerBlink();
               }
        }
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      if (_showMesh && now - _lastMeshRun >= _meshIntervalMs) {
        _lastMeshRun = now;
        try {
          final meshes = await _meshDetector.processImage(inputImage);
          if (meshes.isNotEmpty && mounted) setState(() => _meshPoints = meshes.first.points);
          else if (mounted) setState(() => _meshPoints = []);
        } catch (e) {}
      }
    } catch (e) {
      print("Error: $e");
    } finally {
      _isProcessing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) return const Scaffold(backgroundColor: Color(0xFF1C1C1E), body: Center(child: CircularProgressIndicator()));
    final size = MediaQuery.of(context).size;
    var scale = size.aspectRatio * _controller!.value.aspectRatio;
    if (scale < 1) scale = 1 / scale;

    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: const Text("Blink Rate Test", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        actions: [Switch.adaptive(value: _showMesh, onChanged: (v) => setState(() => _showMesh = v), activeColor: Colors.yellowAccent)],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Transform.scale(scale: scale, child: Center(child: CameraPreview(_controller!))),
          if (_showMesh && _meshPoints.isNotEmpty) IgnorePointer(child: CustomPaint(painter: FaceMeshPainter(points: _meshPoints, imageSize: Size(_controller!.value.previewSize!.height, _controller!.value.previewSize!.width), widgetSize: size))),
          Positioned(
            bottom: 40, left: 20, right: 20,
            child: RoundedCard(
              borderRadius: 22,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              backgroundColor: const Color(0xFF1F1F22),
              borderColor: Colors.white70,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Total Blinks", style: TextStyle(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text("$_blinkCount", style: const TextStyle(fontSize: 38, fontWeight: FontWeight.bold, letterSpacing: -1, color: Color(0xFF9DE18A))),
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
                      onPressed: () {
                        setState(() => _blinkCount = 0);
                        MetricsService.instance.resetBlinks();
                      },
                    ),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // (Include Utils and Painter from previous files)
  InputImage? _inputImageFromCameraImage(CameraImage image) {
    // Same util function as distance screen...
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
  void dispose() {
    _controller?.dispose();
    _faceDetector.close();
    _meshDetector.close();
    DetectionService.instance.restartMonitoringWithDelay();
    super.dispose();
  }
}

class FaceMeshPainter extends CustomPainter {
  final List<FaceMeshPoint> points; final Size imageSize; final Size widgetSize;
  FaceMeshPainter({required this.points, required this.imageSize, required this.widgetSize});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.yellowAccent.withOpacity(0.5)..strokeWidth = 1.5..style = PaintingStyle.fill;
    final double scaleX = widgetSize.width / imageSize.width; final double scaleY = widgetSize.height / imageSize.height; final double scale = scaleX > scaleY ? scaleX : scaleY; final double offsetX = (widgetSize.width - imageSize.width * scale) / 2; final double offsetY = (widgetSize.height - imageSize.height * scale) / 2;
    for (var point in points) { double x = point.x * scale + offsetX; double y = point.y * scale + offsetY; x = widgetSize.width - x; canvas.drawCircle(Offset(x, y), 2, paint); }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}