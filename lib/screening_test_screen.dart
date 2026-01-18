import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img; // The helper to resize images

class ScreeningTestScreen extends StatefulWidget {
  const ScreeningTestScreen({super.key});

  @override
  State<ScreeningTestScreen> createState() => _ScreeningTestScreenState();
}

class _ScreeningTestScreenState extends State<ScreeningTestScreen> {
  // The AI Interpreter
  Interpreter? _interpreter;
  
  File? _selectedImage;
  String _result = "Select an image to analyze";
  bool _isAnalyzing = false;

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  // 1. Load the "Brain" (TFLite Model)
  Future<void> _loadModel() async {
    try {
      // Ensure you put 'model.tflite' in your assets folder!
      _interpreter = await Interpreter.fromAsset('assets/model.tflite');
      setState(() {
        _result = "AI Model Loaded Ready.";
      });
    } catch (e) {
      setState(() {
        _result = "Error loading model: $e";
      });
    }
  }

  // 2. Pick Image from Gallery
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
        _result = "Analyzing...";
        _isAnalyzing = true;
      });
      
      // Give UI a moment to update before freezing for calculation
      await Future.delayed(const Duration(milliseconds: 100)); 
      await _runInference(_selectedImage!);
    }
  }

  // 3. The Heavy Lifting: Run the AI
  Future<void> _runInference(File imageFile) async {
    if (_interpreter == null) return;

    try {
      // A. Read image bytes
      final imageData = await imageFile.readAsBytes();
      
      // B. Decode and Resize to 224x224 (Standard for MobileNet)
      final img.Image? originalImage = img.decodeImage(imageData);
      if (originalImage == null) return;

      final img.Image resizedImage = img.copyResize(originalImage, width: 224, height: 224);

      // C. Convert to Matrix (The "Tensor")
      // FIX: Use integers (0) because the model is Quantized (uint8)
      var input = List.generate(1, (i) => List.generate(224, (j) => List.generate(224, (k) => List.generate(3, (l) => 0))));
      
      for (int y = 0; y < 224; y++) {
        for (int x = 0; x < 224; x++) {
          final pixel = resizedImage.getPixel(x, y);
          // FIX: Convert to int
          input[0][y][x][0] = pixel.r.toInt(); // Red
          input[0][y][x][1] = pixel.g.toInt(); // Green
          input[0][y][x][2] = pixel.b.toInt(); // Blue
        }
      }

      // D. Prepare Output Container
      // FIX: Use 'Uint8List' (integers) for the output buffer because the model is Quantized.
      // The output is [1, 1001], so we need 1001 bytes.
      var output = List.filled(1 * 1001, 0).reshape([1, 1001]);

      // E. RUN!
      _interpreter!.run(input, output);

      // F. Interpret Results
      // The output is now integers (0-255). We need to find the highest one.
      // 255 = 100% confidence.
      List<int> probabilities = List<int>.from(output[0]); // Read as INT
      int maxScore = 0;
      int maxIndex = 0;

      for (int i = 0; i < probabilities.length; i++) {
        if (probabilities[i] > maxScore) {
          maxScore = probabilities[i];
          maxIndex = i;
        }
      }
      
      // Convert 0-255 scale to 0-100% for display
      double confidencePercent = (maxScore / 255.0);

      setState(() {
        _isAnalyzing = false;
        _result = "Analysis Complete.\nDetected Object ID: $maxIndex\nConfidence: ${(confidencePercent * 100).toStringAsFixed(1)}%";
      });

    } catch (e) {
      setState(() {
        _isAnalyzing = false;
        _result = "Inference Error: $e";
      });
    }
  }

  @override
  void dispose() {
    _interpreter?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Module C: AI Lab")),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Image Preview
            Container(
              height: 300,
              width: 300,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(12),
              ),
              child: _selectedImage == null
                  ? const Center(child: Icon(Icons.image, size: 50, color: Colors.grey))
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(_selectedImage!, fit: BoxFit.cover),
                    ),
            ),
            const SizedBox(height: 20),
            
            // Result Text
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _result,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 30),

            // Action Button
            ElevatedButton.icon(
              onPressed: _isAnalyzing ? null : _pickImage,
              icon: _isAnalyzing 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                : const Icon(Icons.camera_alt),
              label: Text(_isAnalyzing ? "Processing..." : "Select Photo from Gallery"),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}