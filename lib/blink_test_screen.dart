import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'main.dart';

class BlinkTestScreen extends StatefulWidget {
  const BlinkTestScreen({super.key});

  @override
  State<BlinkTestScreen> createState() => _BlinkTestScreenState();
}

class _BlinkTestScreenState extends State<BlinkTestScreen> {
  CameraController? _controller;
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      enableLandmarks: true,
      performanceMode: FaceDetectorMode.fast,
    ),
  );

  bool _isBusy = false;
  int _blinkCount = 0;
  String _eyeState = "Waiting...";
  double _eyeOpenProb = 0.0;
  bool _wasClosed = false;

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

      if (faces.isNotEmpty) {
        final face = faces.first;
        final double? leftProb = face.leftEyeOpenProbability;
        final double? rightProb = face.rightEyeOpenProbability;

        if (leftProb != null && rightProb != null) {
          double avgProb = (leftProb + rightProb) / 2.0;

          if (mounted) {
            setState(() {
              _eyeOpenProb = avgProb;
              if (avgProb < 0.2) {
                _eyeState = "CLOSED";
                _wasClosed = true;
              } else {
                _eyeState = "OPEN";
                if (_wasClosed && avgProb > 0.5) {
                  _blinkCount++;
                  _wasClosed = false;
                }
              }
            });
          }
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text("Blink Analysis")),
      body: Column(
        children: [
          // 1. Camera Viewfinder (Matches Distance Screen Size)
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
                          // FIX: FittedBox prevents warping
                          FittedBox(
                            fit: BoxFit.cover,
                            child: SizedBox(
                              width: _controller!.value.previewSize!.height,
                              height: _controller!.value.previewSize!.width,
                              child: CameraPreview(_controller!),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),

          // 2. Data Panel (Matches Distance Screen Size)
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.all(30),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Column(
                children: [
                  const Text("Total Blinks", style: TextStyle(color: Colors.grey)),
                  Text(
                    "$_blinkCount",
                    style: TextStyle(
                      fontSize: 90,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Eye Openness", style: TextStyle(fontWeight: FontWeight.bold)),
                      Text("${(_eyeOpenProb * 100).toStringAsFixed(0)}%"),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: _eyeOpenProb,
                      minHeight: 15,
                      backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _eyeOpenProb < 0.2 ? Colors.red : Colors.green,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _eyeState,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _eyeState == "CLOSED" ? Colors.red : Colors.green,
                    ),
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