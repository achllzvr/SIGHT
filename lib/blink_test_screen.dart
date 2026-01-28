import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:typed_data';
import 'dart:io';

class BlinkTestScreen extends StatefulWidget {
  const BlinkTestScreen({super.key});

  @override
  State<BlinkTestScreen> createState() => _BlinkTestScreenState();
}

class _BlinkTestScreenState extends State<BlinkTestScreen> {
  CameraController? _controller;
  // Enable Classification to get "Eye Open Probability"
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true, 
      performanceMode: FaceDetectorMode.fast, // FAST mode for blinks
    ),
  );

  bool _isProcessing = false;
  int _blinkCount = 0;
  bool _eyesClosed = false; 

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

    _controller = CameraController(
      frontCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await _controller!.initialize();

    if (mounted) {
      setState(() {});
      _controller!.startImageStream((image) {
        _processCameraImage(image);
      });
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
        
        // Probability 0.0 = Closed, 1.0 = Open
        double? leftOpen = face.leftEyeOpenProbability;
        double? rightOpen = face.rightEyeOpenProbability;

        if (leftOpen != null && rightOpen != null) {
          double avgOpen = (leftOpen + rightOpen) / 2.0;
          
          // Threshold for "Closed" (0.2 is a good baseline)
          bool currentlyClosed = avgOpen < 0.2;

          if (currentlyClosed && !_eyesClosed) {
            _eyesClosed = true; // Blink Started
          } else if (!currentlyClosed && _eyesClosed) {
            _eyesClosed = false; // Blink Ended
            if (mounted) {
              setState(() {
                _blinkCount++;
              });
            }
          }
        }
      }
    } catch (e) {
      print("Error counting blinks: $e");
    } finally {
      _isProcessing = false;
    }
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    final camera = _controller!.description;
    final rotation = InputImageRotationValue.fromRawValue(camera.sensorOrientation) 
        ?? InputImageRotation.rotation270deg;

    // FIX: Manually convert YUV420 to NV21 to handle Android stride/padding issues
    if (image.format.group == ImageFormatGroup.yuv420) {
      return InputImage.fromBytes(
        bytes: _yuv420ToNv21(image),
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.nv21, // Force NV21
          bytesPerRow: image.width,      // Packed NV21 has stride == width
        ),
      );
    } 
    
    // Fallback for iOS (BGRA8888)
    if (image.format.group == ImageFormatGroup.bgra8888) {
      return InputImage.fromBytes(
        bytes: image.planes[0].bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.bgra8888,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );
    }
    return null;
  }

  // ROBUST CONVERTER: YUV420 -> NV21
  // This handles the "padding bytes" that crash Xiaomi/Samsung phones
  Uint8List _yuv420ToNv21(CameraImage image) {
    final int width = image.width;
    final int height = image.height;
    
    final Plane yPlane = image.planes[0];
    final Plane uPlane = image.planes[1];
    final Plane vPlane = image.planes[2];

    final Uint8List yBuffer = yPlane.bytes;
    final Uint8List uBuffer = uPlane.bytes;
    final Uint8List vBuffer = vPlane.bytes;

    final int numPixels = (width * height * 1.5).toInt();
    final Uint8List nv21 = Uint8List(numPixels);

    // Copy Y Channel (Luma) row by row to skip padding
    int idY = 0;
    for (int i = 0; i < height; i++) {
      int srcPos = i * yPlane.bytesPerRow;
      for (int j = 0; j < width; j++) {
        nv21[idY++] = yBuffer[srcPos + j];
      }
    }

    // Copy UV Channels (Chroma)
    int idUV = width * height;
    final int uvHeight = height ~/ 2;
    final int uvWidth = width ~/ 2;
    
    final int uPixelStride = uPlane.bytesPerPixel ?? 1;
    final int uRowStride = uPlane.bytesPerRow;
    final int vPixelStride = vPlane.bytesPerPixel ?? 1;
    final int vRowStride = vPlane.bytesPerRow;

    for (int i = 0; i < uvHeight; i++) {
      for (int j = 0; j < uvWidth; j++) {
        int uIndex = i * uRowStride + j * uPixelStride;
        int vIndex = i * vRowStride + j * vPixelStride;
        
        // V first, then U for NV21
        nv21[idUV++] = vBuffer[vIndex];
        nv21[idUV++] = uBuffer[uIndex];
      }
    }
    return nv21;
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
      appBar: AppBar(title: const Text("Blink Rate Test")),
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_controller!),
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Center(
              child: Column(
                children: [
                  const Text(
                    "Blinks Detected",
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  Text(
                    "$_blinkCount",
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 60,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white, size: 40),
                    onPressed: () {
                      setState(() {
                        _blinkCount = 0;
                      });
                    },
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