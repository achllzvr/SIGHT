import 'dart:typed_data';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/services.dart';
import '../utils/image_utils.dart';
import 'package:flutter/foundation.dart';

class EyeDiagnosisService {
  Interpreter? _interpreter;
  late FaceDetector _faceDetector;
  List<String> _labels = [];
  bool _isBusy = false;
  int _lastRun = 0;
  bool _isDisposed = false; // Guard against SIGSEGV

  Future<void> initialize() async {
    try {
      final options = InterpreterOptions();
      // On some Samsungs, NNAPI causes crashes. Disabling it is safer.
      options.useNnApiForAndroid = false; 
      
      _interpreter = await Interpreter.fromAsset('assets/sight_model_quant.tflite', options: options);
      
      final labelData = await rootBundle.loadString('assets/labels.txt');
      _labels = labelData.split('\n');

      _faceDetector = FaceDetector(
        options: FaceDetectorOptions(
          enableLandmarks: true,
          performanceMode: FaceDetectorMode.accurate,
        ),
      );
      print("SIGHT AI Service: Ready.");
    } catch (e) {
      print("Error initializing AI Service: $e");
    }
  }

  Future<Map<String, String>> analyzeFrame(CameraImage cameraImage, int sensorRotation) async {
    if (_isDisposed) return {}; // Prevent crash
    
    // Throttle
    final int now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastRun < 350) return {};
    _lastRun = now;

    if (_isBusy || _interpreter == null) return {};
    _isBusy = true;

    Map<String, String> results = {};

    try {
      // Conversion for TFLite
      img.Image fullImage = convertYUV420ToImage(cameraImage);

      // ML Kit Input Preparation
      final rotation = InputImageRotationValue.fromRawValue(sensorRotation) 
          ?? InputImageRotation.rotation270deg;

      Uint8List bytes;
      InputImageFormat format;
      int bytesPerRow;

      if (cameraImage.format.group == ImageFormatGroup.yuv420) {
        // Android: Convert YUV_420_888 to NV21 manually
        bytes = _yuv420ToNv21(cameraImage);
        format = InputImageFormat.nv21;
        bytesPerRow = cameraImage.width;
      } else {
        // iOS/Fallback: Use BGRA8888
        bytes = _concatenatePlanes(cameraImage.planes);
        format = InputImageFormat.bgra8888;
        bytesPerRow = cameraImage.planes[0].bytesPerRow;
      }

      final inputImage = InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(cameraImage.width.toDouble(), cameraImage.height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: bytesPerRow,
        ),
      );

      final faces = await _faceDetector.processImage(inputImage);

      if (faces.isNotEmpty) {
        final face = faces.first;
        results['Left'] = _predictEye(fullImage, face.landmarks[FaceLandmarkType.leftEye]);
        results['Right'] = _predictEye(fullImage, face.landmarks[FaceLandmarkType.rightEye]);
      }
    } catch (e) {
      print("Inference Error: $e");
    } finally {
      _isBusy = false;
    }

    return results;
  }

  // ROBUST CONVERTER: YUV420 -> NV21
  // This handles stride and padding correctly for Xiaomi/Samsung
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
    int idY = 0;
    for (int i = 0; i < height; i++) {
      int srcPos = i * yPlane.bytesPerRow;
      for (int j = 0; j < width; j++) {
        nv21[idY++] = yBuffer[srcPos + j];
      }
    }

    // Copy UV Channels (Chroma) - Interleaved
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

  Uint8List _concatenatePlanes(List<Plane> planes) {
    final BytesBuilder allBytes = BytesBuilder();
    for (Plane plane in planes) {
      allBytes.add(plane.bytes);
    }
    return allBytes.toBytes();
  }

  String _predictEye(img.Image fullImage, FaceLandmark? landmark) {
    if (landmark == null || _interpreter == null) return "Not Visible";

    int size = 100;
    int x = landmark.position.x.toInt() - (size ~/ 2);
    int y = landmark.position.y.toInt() - (size ~/ 2);
    
    if (x < 0) x = 0;
    if (y < 0) y = 0;
    if (x + size > fullImage.width) size = fullImage.width - x;
    if (y + size > fullImage.height) size = fullImage.height - y;

    img.Image eyeCrop = img.copyCrop(fullImage, x: x, y: y, width: size, height: size);
    img.Image resized = img.copyResize(eyeCrop, width: 224, height: 224);

    var input = imageToByteListFloat32(resized, 224);
    // Flat buffer for input
    var output = List.filled(1 * 5, 0.0).reshape([1, 5]);

    try {
      _interpreter!.run(input, output); 
    } catch (e) {
      // If flat fails, try reshaping the input list itself in Dart
      try {
         var inputReshaped = input.reshape([1, 224, 224, 3]);
         _interpreter!.run(inputReshaped, output);
      } catch (e2) {
         print("Run Error: $e2");
         return "Error";
      }
    }

    List<dynamic> probs = output[0];
    int maxIndex = 0;
    double maxVal = 0.0;

    for (int i = 0; i < probs.length; i++) {
      if (probs[i] > maxVal) {
        maxVal = probs[i];
        maxIndex = i;
      }
    }

    String disease = _labels.length > maxIndex ? _labels[maxIndex] : "Unknown";
    int percentage = (maxVal * 100).toInt();

    return "$disease ($percentage%)";
  }

  void dispose() {
    _isDisposed = true; // Signal everything to stop
    _interpreter?.close();
    _interpreter = null;
    _faceDetector.close();
  }
}