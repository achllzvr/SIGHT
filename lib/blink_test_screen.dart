import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:flutter/foundation.dart';
import 'main.dart'; // To access the 'cameras' list

class BlinkTestScreen extends StatefulWidget {
  const BlinkTestScreen({super.key});

  @override
  State<BlinkTestScreen> createState() => _BlinkTestScreenState();
}

class _BlinkTestScreenState extends State<BlinkTestScreen> {
  CameraController? _controller;
  // CRITICAL: enableClassification must be TRUE to see eyes!
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true, // <--- THIS IS THE MAGIC SWITCH
      enableLandmarks: true,
      performanceMode: FaceDetectorMode.fast,
    ),
  );

  bool _isBusy = false;
  
  // Logic Variables
  int _blinkCount = 0;
  String _eyeState = "OPEN";
  Color _stateColor = Colors.green;
  
  // Thresholds
  // If prob < 0.2, eye is definitely closed. 
  // If prob > 0.5, eye is definitely open.
  bool _wasClosed = false; 

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

      if (faces.isNotEmpty) {
        final face = faces.first;
        
        // 1. Get Probabilities (Null means the AI isn't sure or face is too far)
        final double? leftOpenProb = face.leftEyeOpenProbability;
        final double? rightOpenProb = face.rightEyeOpenProbability;

        if (leftOpenProb != null && rightOpenProb != null) {
          // Average the two eyes for stability
          double avgProb = (leftOpenProb + rightOpenProb) / 2.0;

          // 2. Blink Logic (Finite State Machine)
          bool isCurrentlyClosed = avgProb < 0.2; // Threshold for "Closed"

          if (isCurrentlyClosed) {
            // State: Eyes are SHUT
            setState(() {
              _eyeState = "CLOSED (${(avgProb * 100).toStringAsFixed(0)}%)";
              _stateColor = Colors.red;
              _wasClosed = true; // Mark that we are in the middle of a blink
            });
          } else {
            // State: Eyes are OPEN
             setState(() {
              _eyeState = "OPEN (${(avgProb * 100).toStringAsFixed(0)}%)";
              _stateColor = Colors.green;
            });

            // Did we just finish a blink?
            if (_wasClosed && avgProb > 0.5) {
              setState(() {
                _blinkCount++; // BINGO!
                _wasClosed = false; // Reset
              });
            }
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
      appBar: AppBar(title: const Text("Module B: Blink Counter")),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: CameraPreview(_controller!),
          ),
          Expanded(
            flex: 2,
            child: Container(
              color: Colors.white,
              width: double.infinity,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Blink Count", style: TextStyle(color: Colors.grey)),
                  Text(
                    "$_blinkCount",
                    style: const TextStyle(fontSize: 60, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: _stateColor,
                      borderRadius: BorderRadius.circular(10)
                    ),
                    child: Text(
                      _eyeState,
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      "Look at the camera and blink naturally.\nDoes the counter go up exactly once per blink?",
                      textAlign: TextAlign.center,
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
}