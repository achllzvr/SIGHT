import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'main.dart';

class DistanceTestScreen extends StatefulWidget {
  const DistanceTestScreen({super.key});

  @override
  State<DistanceTestScreen> createState() => _DistanceTestScreenState();
}

class _DistanceTestScreenState extends State<DistanceTestScreen> {
  CameraController? _controller;
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: false,
      enableLandmarks: true,
      enableTracking: true,
      performanceMode: FaceDetectorMode.fast,
    ),
  );

  bool _isBusy = false;
  String _statusMessage = "Align Face";
  double _currentDistanceCm = 0.0;
  Color _statusColor = Colors.grey;
  final double _avgFaceWidthCm = 15.0;
  double _focalLength = 500.0;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final frontCamera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _controller = CameraController(
      frontCamera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21,
    );

    await _controller!.initialize();
    if (!mounted) return;
    _controller!.startImageStream(_processCameraImage);
    setState(() {});
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isBusy) return;
    _isBusy = true;

    try {
      final inputImage = _convertCameraImageToInputImage(image);
      if (inputImage == null) return;

      final faces = await _faceDetector.processImage(inputImage);

      if (faces.isEmpty) {
        if (mounted) {
          setState(() {
            _statusMessage = "No Face Detected";
            _statusColor = Colors.grey;
            _currentDistanceCm = 0.0;
          });
        }
      } else {
        final face = faces.first;
        final boundingBox = face.boundingBox;
        double faceWidthPixels = boundingBox.width;
        double distance = (_avgFaceWidthCm * _focalLength) / faceWidthPixels;

        if (mounted) {
          setState(() {
            _currentDistanceCm = distance;
            if (distance < 30.0) {
              _statusMessage = "TOO CLOSE";
              _statusColor = Colors.redAccent;
            } else if (distance > 30.0 && distance < 60.0) {
              _statusMessage = "OPTIMAL";
              _statusColor = Colors.green;
            } else {
              _statusMessage = "TOO FAR";
              _statusColor = Colors.blue;
            }
          });
        }
      }
    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      _isBusy = false;
    }
  }

  InputImage? _convertCameraImageToInputImage(CameraImage image) {
    final camera = _controller!.description;
    final sensorOrientation = camera.sensorOrientation;
    final InputImageRotation rotation =
        InputImageRotationValue.fromRawValue(sensorOrientation) ??
            InputImageRotation.rotation0deg;
    final format = InputImageFormat.nv21;

    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Distance Monitor"),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showInstructions(context),
          )
        ],
      ),
      body: Column(
        children: [
          // 1. Camera Viewfinder (Uniform Style)
          Expanded(
            flex: 4,
            child: Container(
              margin: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: _controller == null || !_controller!.value.isInitialized
                    ? const Center(child: CircularProgressIndicator())
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          // FIX: FittedBox prevents warping/stretching
                          FittedBox(
                            fit: BoxFit.cover,
                            child: SizedBox(
                              width: _controller!.value.previewSize!.height,
                              height: _controller!.value.previewSize!.width,
                              child: CameraPreview(_controller!),
                            ),
                          ),
                          // Gradient Overlay
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: _statusColor.withOpacity(0.5),
                                width: 4,
                              ),
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),

          // 2. Data Panel
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: _statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _statusMessage,
                      style: TextStyle(
                        color: _statusColor,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "${_currentDistanceCm.toStringAsFixed(0)} cm",
                    style: TextStyle(
                      fontSize: 72,
                      fontWeight: FontWeight.w300,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text("Estimated Distance", style: TextStyle(color: Colors.grey.shade500)),
                  const Spacer(),
                  Row(
                    children: [
                      const Icon(Icons.tune, size: 16, color: Colors.grey),
                      const SizedBox(width: 10),
                      Text("Calibrate", style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                      Expanded(
                        child: Slider.adaptive(
                          value: _focalLength,
                          min: 200,
                          max: 1000,
                          activeColor: Theme.of(context).colorScheme.primary,
                          onChanged: (val) => setState(() => _focalLength = val),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showInstructions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text("How to Test", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Text("1. Hold a ruler against your face.\n2. Move phone to exactly 30cm.\n3. Adjust the bottom slider until the app reads '30 cm'."),
          ],
        ),
      ),
    );
  }
}