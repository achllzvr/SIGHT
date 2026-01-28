import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/services.dart';
import '../utils/image_utils.dart'; 

class EyeDiagnosisService {
  Interpreter? _interpreter;
  late FaceDetector _faceDetector;
  List<String> _labels = [];
  bool _isBusy = false;

  Future<void> initialize() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/sight_model_quant.tflite');
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

  Future<Map<String, String>> analyzeFrame(CameraImage cameraImage) async {
    if (_isBusy || _interpreter == null) return {};
    _isBusy = true;
    Map<String, String> results = {};

    try {
      img.Image fullImage = convertYUV420ToImage(cameraImage);
      
      final inputImage = InputImage.fromBytes(
        bytes: _concatenatePlanes(cameraImage.planes),
        metadata: InputImageMetadata(
          size: Size(cameraImage.width.toDouble(), cameraImage.height.toDouble()),
          rotation: InputImageRotation.rotation270deg, 
          format: InputImageFormat.nv21,
          bytesPerRow: cameraImage.planes[0].bytesPerRow,
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

  Uint8List _concatenatePlanes(List<Plane> planes) {
    final WriteBuffer allBytes = WriteBuffer();
    for (Plane plane in planes) {
      allBytes.putUint8List(plane.bytes);
    }
    return allBytes.done().buffer.asUint8List();
  }

  String _predictEye(img.Image fullImage, FaceLandmark? landmark) {
    if (landmark == null) return "Not Visible";

    // 1. Crop
    int size = 100;
    int x = landmark.position.x.toInt() - (size ~/ 2);
    int y = landmark.position.y.toInt() - (size ~/ 2);
    if (x < 0) x = 0; if (y < 0) y = 0;
    if (x + size > fullImage.width) x = fullImage.width - size;
    if (y + size > fullImage.height) y = fullImage.height - size;

    img.Image eyeCrop = img.copyCrop(fullImage, x: x, y: y, width: size, height: size);
    img.Image resized = img.copyResize(eyeCrop, width: 224, height: 224);

    // 2. Prepare Input
    // We get the Float32List
    var flatBytes = imageToByteListFloat32(resized, 224);
    
    // RESHAPE to 4D [1, 224, 224, 3]
    // Because we baked this shape into the model, we MUST match it here.
    var input = flatBytes.reshape([1, 224, 224, 3]);
    
    // 3. Output
    var output = List.filled(1 * 5, 0.0).reshape([1, 5]);

    // 4. Run
    try {
      _interpreter!.run(input, output);
    } catch (e) {
      print("Run Error: $e");
      return "Error";
    }

    // 5. Result
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
    _interpreter?.close();
    _faceDetector.close();
  }
}