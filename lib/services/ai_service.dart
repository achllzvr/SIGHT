import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart'; // Add this to your pubspec if missing, or use Directory.systemTemp

class EyeDiagnosisService {
  Interpreter? _interpreter;
  FaceDetector? _faceDetector;
  List<String> _labels = [];

  Future<void> initialize() async {
    try {
      final options = InterpreterOptions();
      if (Platform.isAndroid) options.useNnApiForAndroid = true;
      
      String modelPath = Platform.isIOS 
          ? 'assets/sight_model_ios.tflite' 
          : 'assets/sight_model_android.tflite';

      _interpreter = await Interpreter.fromAsset(modelPath, options: options);
      
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
      print("SIGHT AI Init Error: $e");
    }
  }

  Future<Map<String, dynamic>> analyzePhoto(String filePath) async {
    if (_interpreter == null || _faceDetector == null) {
      return {'Error': 'AI Engine not ready. Please restart.'};
    }

    try {
      // 1. Decode the Raw File
      final File originalFile = File(filePath);
      final Uint8List rawBytes = await originalFile.readAsBytes();
      img.Image? originalImage = img.decodeImage(rawBytes);

      if (originalImage == null) return {'Error': 'Could not decode image.'};

      // 2. FORCE UPRIGHT (Critical Fix)
      // This rotates the pixels so (0,0) is visually top-left.
      // This ensures our crop coordinates match what the detector sees.
      img.Image uprightImage = img.bakeOrientation(originalImage);

      // 3. Save Upright Image to Temp File
      // We pass THIS file to ML Kit, so ML Kit sees an upright face.
      final Directory tempDir = await getTemporaryDirectory();
      final String tempPath = '${tempDir.path}/sight_analysis_temp.jpg';
      final File tempFile = File(tempPath);
      await tempFile.writeAsBytes(img.encodeJpg(uprightImage));

      // 4. Detect Face on the UPRIGHT image
      final inputImage = InputImage.fromFilePath(tempPath);
      final faces = await _faceDetector!.processImage(inputImage);

      // Clean up temp file
      // await tempFile.delete(); 

      if (faces.isEmpty) {
        return {'Error': 'No face detected. Ensure good lighting and face camera directly.'};
      }

      final face = faces.first;

      // 5. Crop & Predict (Now using synchronized coordinates)
      return {
        'Left': _predictEye(uprightImage, face, isLeftEye: true),
        'Right': _predictEye(uprightImage, face, isLeftEye: false),
      };

    } catch (e) {
      print("Analysis Exception: $e");
      return {'Error': 'Analysis failed: $e'};
    }
  }

  String _predictEye(img.Image fullImage, Face face, {required bool isLeftEye}) {
    // 1. Get Landmark
    // Note: ML Kit's "LeftEye" is the person's left eye (viewer's right).
    final landmark = face.landmarks[isLeftEye ? FaceLandmarkType.leftEye : FaceLandmarkType.rightEye];
    
    if (landmark == null) return "Not Found";

    // 2. Coordinates
    final int centerX = landmark.position.x;
    final int centerY = landmark.position.y;

    // 3. Crop
    int size = 140; // Crop size (pixels)
    int x = centerX - (size ~/ 2);
    int y = centerY - (size ~/ 2);
    
    // Bounds Check
    if (x < 0) x = 0;
    if (y < 0) y = 0;
    if (x + size > fullImage.width) size = fullImage.width - x;
    if (y + size > fullImage.height) size = fullImage.height - y;

    // 4. Process for Model
    img.Image eyeCrop = img.copyCrop(fullImage, x: x, y: y, width: size, height: size);
    img.Image resized = img.copyResize(eyeCrop, width: 224, height: 224);

    // 5. Inference
    var inputFlat = _imageToByteListFloat32(resized, 224);
    var input = inputFlat.reshape([1, 224, 224, 3]); 
    var output = List.filled(5, 0.0).reshape([1, 5]);

    try {
      _interpreter!.run(input, output);
    } catch (e) {
      return "AI Err";
    }

    // 6. Interpret Results
    List<dynamic> probs = output[0];
    int maxIndex = 0;
    double maxVal = 0.0;

    for (int i = 0; i < probs.length; i++) {
      if (probs[i] > maxVal) {
        maxVal = probs[i];
        maxIndex = i;
      }
    }

    String label = _labels.length > maxIndex ? _labels[maxIndex] : "Unknown";
    // Clean label (remove numbers/IDs)
    label = label.replaceAll(RegExp(r'^\d+\s*'), '').trim();
    int confidence = (maxVal * 100).toInt();

    // Only return disease name if confidence is reasonable, else "Uncertain"
    if (confidence < 40) return "Uncertain";

    return "$label\n$confidence%";
  }

  Float32List _imageToByteListFloat32(img.Image image, int inputSize) {
    var convertedBytes = Float32List(1 * inputSize * inputSize * 3);
    var buffer = Float32List.view(convertedBytes.buffer);
    int pixelIndex = 0;

    for (var i = 0; i < inputSize; i++) {
      for (var j = 0; j < inputSize; j++) {
        var pixel = image.getPixel(j, i);
        // Normalize 0..1
        buffer[pixelIndex++] = pixel.r / 255.0;
        buffer[pixelIndex++] = pixel.g / 255.0;
        buffer[pixelIndex++] = pixel.b / 255.0;
      }
    }
    return convertedBytes;
  }

  void dispose() {
    _interpreter?.close();
    _faceDetector?.close();
  }
}