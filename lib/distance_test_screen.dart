import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:typed_data';
import 'dart:io'; 

class DistanceTestScreen extends StatefulWidget {
  const DistanceTestScreen({super.key});

  @override
  State<DistanceTestScreen> createState() => _DistanceTestScreenState();
}

class _DistanceTestScreenState extends State<DistanceTestScreen> {
  CameraController? _controller;
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableLandmarks: true,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );
  
  String _distanceResult = "Align Face";
  bool _isProcessing = false;
  int _lastRun = 0; 

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
    final int now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastRun < 300) return; 
    
    if (_isProcessing) return;
    _isProcessing = true;
    _lastRun = now;

    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) return;

      final faces = await _faceDetector.processImage(inputImage);

      if (faces.isNotEmpty) {
        final face = faces.first;
        double pixelWidth = face.boundingBox.width;
        // Calibration Factor (4500 is a baseline)
        double estimatedDistanceCm = (4500 / pixelWidth); 

        String status = "Safe Distance";
        Color color = Colors.green;

        if (estimatedDistanceCm < 30) {
          status = "TOO CLOSE!";
          color = Colors.red;
        } else if (estimatedDistanceCm > 70) {
          status = "Too Far";
          color = Colors.orange;
        }

        if (mounted) {
          setState(() {
            _distanceResult = "${estimatedDistanceCm.toStringAsFixed(1)} cm\n$status";
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _distanceResult = "No Face Detected";
          });
        }
      }
    } catch (e) {
      print("Error processing distance: $e");
    } finally {
      _isProcessing = false;
    }
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    final camera = _controller!.description;
    final rotation = InputImageRotationValue.fromRawValue(camera.sensorOrientation) ?? InputImageRotation.rotation270deg;

    // FIX: ML Kit on Android expects NV21 format for "fromBytes".
    // We must manually construct a valid NV21 byte array from the YUV_420_888 planes.
    // This handles the stride/padding issues on Xiaomi/Samsung.
    
    if (image.format.group == ImageFormatGroup.yuv420) {
      return InputImage.fromBytes(
        bytes: _yuv420ToNv21(image),
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.nv21, // We forced it to NV21
          bytesPerRow: image.width, // NV21 stride is usually just the width
        ),
      );
    } else if (image.format.group == ImageFormatGroup.bgra8888) {
      // iOS usually uses BGRA
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

    // Copy Y Channel (Luma)
    // We must respect the Row Stride (bytesPerRow)
    int idY = 0;
    for (int i = 0; i < height; i++) {
      int srcPos = i * yPlane.bytesPerRow;
      for (int j = 0; j < width; j++) {
        nv21[idY++] = yBuffer[srcPos + j];
      }
    }

    // Copy UV Channels (Chroma) - Interleaved
    // NV21 layout: YYYYY... VUVU...
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

  // FIXED: Use BytesBuilder instead of WriteBuffer
  Uint8List _concatenatePlanes(List<Plane> planes) {
    final BytesBuilder allBytes = BytesBuilder();
    for (Plane plane in planes) {
      allBytes.add(plane.bytes);
    }
    return allBytes.toBytes();
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
      appBar: AppBar(title: const Text("Distance Check")),
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_controller!),
          Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Text(
                _distanceResult,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}