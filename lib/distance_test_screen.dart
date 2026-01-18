import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:flutter/foundation.dart';
import 'main.dart'; // To access the 'cameras' list

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
      enableLandmarks: true,       // Needed for accurate width
      enableTracking: true,
      performanceMode: FaceDetectorMode.fast,
    ),
  );

  bool _isBusy = false;
  String _statusMessage = "Initializing...";
  double _currentDistanceCm = 0.0;
  Color _statusColor = Colors.grey;

  // --- CALIBRATION CONSTANTS ---
  final double _avgFaceWidthCm = 15.0; 
  double _focalLength = 500.0; 

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final frontCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _controller = CameraController(
      frontCamera,
      ResolutionPreset.medium, 
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21, // <-- NEW (Fixes Samsung padding)
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
        setState(() {
          _statusMessage = "No Face Detected";
          _statusColor = Colors.grey;
          _currentDistanceCm = 0.0;
        });
      } else {
        final face = faces.first;
        final boundingBox = face.boundingBox;
        
        // Calculate Distance: (RealWidth * FocalLength) / PixelWidth
        double faceWidthPixels = boundingBox.width;
        double distance = (_avgFaceWidthCm * _focalLength) / faceWidthPixels;

        setState(() {
          _currentDistanceCm = distance;
          
          if (distance < 30.0) {
            _statusMessage = "⚠️ TOO CLOSE! (Harmful Zone)";
            _statusColor = Colors.red;
          } else if (distance > 30.0 && distance < 60.0) {
            _statusMessage = "✅ Good Distance";
            _statusColor = Colors.green;
          } else {
            _statusMessage = "ℹ️ Far Away";
            _statusColor = Colors.blue;
          }
        });
      }
    } catch (e) {
      debugPrint("Error detecting face: $e");
    } finally {
      _isBusy = false;
    }
  }

  InputImage? _convertCameraImageToInputImage(CameraImage image) {
    final camera = _controller!.description;
    final sensorOrientation = camera.sensorOrientation;
    
    // 1. Calculate Rotation
    final InputImageRotation rotation = InputImageRotationValue.fromRawValue(sensorOrientation) ?? InputImageRotation.rotation0deg;

    // 2. Force Format to NV21 (Since we asked for it in the controller)
    final format = InputImageFormat.nv21;

    // 3. Concatenate Planes
    // NV21 format is strictly: Y Plane followed by V and U interleaved.
    // The camera package gives us 3 planes. We merge them safely here.
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    // 4. Create the InputImage
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
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Module A: Distance")),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              color: Colors.black,
              child: Center(child: CameraPreview(_controller!)),
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "${_currentDistanceCm.toStringAsFixed(1)} cm",
                    style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(color: _statusColor, borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      _statusMessage,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                  const Divider(height: 30),
                  const Text("🛠️ Calibration Slider (Focal Length)", style: TextStyle(fontWeight: FontWeight.bold)),
                  Slider(
                    value: _focalLength,
                    min: 200,
                    max: 1500,
                    divisions: 130,
                    label: _focalLength.round().toString(),
                    onChanged: (double value) {
                      setState(() {
                        _focalLength = value;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}