import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_mesh_detection/google_mlkit_face_mesh_detection.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class EyeDiagnosisService {
  Interpreter? _interpreter;
  FaceMeshDetector? _meshDetector;
  List<String> _labels = [];

  Future<void> initialize() async {
    try {
      final options = InterpreterOptions();
      
      // Select Model
      String modelPath = Platform.isIOS 
          ? 'assets/sight_model_ios.tflite' 
          : 'assets/sight_model_android.tflite';
      
      if (Platform.isAndroid) options.useNnApiForAndroid = true;

      _interpreter = await Interpreter.fromAsset(modelPath, options: options);
      
      // Load Labels
      final labelData = await rootBundle.loadString('assets/labels.txt');
      _labels = labelData.split('\n');

      // Initialize Face Mesh (More robust than standard detector)
      _meshDetector = FaceMeshDetector(option: FaceMeshDetectorOptions.faceMesh);
      
      print("SIGHT AI Service: Ready (Face Mesh Mode).");
    } catch (e) {
      print("Error initializing AI Service: $e");
    }
  }

  Future<Map<String, dynamic>> analyzePhoto(String filePath) async {
    if (_interpreter == null || _meshDetector == null) {
      return {'Error': 'AI not ready'};
    }

    try {
      final File imageFile = File(filePath);
      final img.Image? fullImage = img.decodeImage(imageFile.readAsBytesSync());

      if (fullImage == null) return {'Error': 'Image decode failed'};

      // Detect Mesh
      final inputImage = InputImage.fromFilePath(filePath);
      final meshes = await _meshDetector!.processImage(inputImage);

      if (meshes.isNotEmpty) {
        final mesh = meshes.first;
        
        // Return results AND the mesh points for visualization
        return {
          'Left': _predictEye(fullImage, mesh, isLeftEye: true),
          'Right': _predictEye(fullImage, mesh, isLeftEye: false),
          'Mesh': mesh.points, // Return points to draw on screen
        };
      } else {
        return {'Error': 'No Face Detected (Try better lighting)'};
      }
    } catch (e) {
      return {'Error': e.toString()};
    }
  }

  String _predictEye(img.Image fullImage, FaceMesh mesh, {required bool isLeftEye}) {
    // Face Mesh Indices for Eye Centers
    // Left Eye: 33 (Inner), 133 (Outer) -> Center approx
    // Right Eye: 362 (Inner), 263 (Outer) -> Center approx
    
    // Get center point of the eye based on mesh landmarks
    final int inner = isLeftEye ? 33 : 362;
    final int outer = isLeftEye ? 133 : 263;
    
    // Safety check for bounds
    if (inner >= mesh.points.length || outer >= mesh.points.length) return "Mesh Error";

    final p1 = mesh.points[inner];
    final p2 = mesh.points[outer];

    // Calculate center
    final int centerX = ((p1.x + p2.x) / 2).toInt();
    final int centerY = ((p1.y + p2.y) / 2).toInt();

    // Crop Logic
    int size = 120;
    int x = centerX - (size ~/ 2);
    int y = centerY - (size ~/ 2);
    
    // Clamp to image bounds
    if (x < 0) x = 0;
    if (y < 0) y = 0;
    if (x + size > fullImage.width) size = fullImage.width - x;
    if (y + size > fullImage.height) size = fullImage.height - y;

    img.Image eyeCrop = img.copyCrop(fullImage, x: x, y: y, width: size, height: size);
    img.Image resized = img.copyResize(eyeCrop, width: 224, height: 224);

    // Prepare Input (1D -> 4D Reshape)
    var inputFlat = _imageToByteListFloat32(resized, 224);
    var input = inputFlat.reshape([1, 224, 224, 3]); 
    
    // Prepare Output
    var output = List.filled(1 * 5, 0.0).reshape([1, 5]);

    try {
      // Use standard run
      _interpreter!.run(input, output); 
    } catch (e) {
      return "Err: ${e.toString().substring(0, 20)}"; // Return short error to UI
    }

    // Process Result
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

  Float32List _imageToByteListFloat32(img.Image image, int inputSize) {
    var convertedBytes = Float32List(1 * inputSize * inputSize * 3);
    var buffer = Float32List.view(convertedBytes.buffer);
    int pixelIndex = 0;

    for (var i = 0; i < inputSize; i++) {
      for (var j = 0; j < inputSize; j++) {
        var pixel = image.getPixel(j, i);
        buffer[pixelIndex++] = pixel.r.toDouble() / 255.0;
        buffer[pixelIndex++] = pixel.g.toDouble() / 255.0;
        buffer[pixelIndex++] = pixel.b.toDouble() / 255.0;
      }
    }
    return convertedBytes;
  }

  void dispose() {
    _interpreter?.close();
    _meshDetector?.close();
  }
}