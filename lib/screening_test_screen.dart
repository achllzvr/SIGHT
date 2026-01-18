import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class ScreeningTestScreen extends StatefulWidget {
  const ScreeningTestScreen({super.key});

  @override
  State<ScreeningTestScreen> createState() => _ScreeningTestScreenState();
}

class _ScreeningTestScreenState extends State<ScreeningTestScreen> {
  Interpreter? _interpreter;
  List<String> _labels = [];
  File? _selectedImage;
  String _resultLabel = "Ready to Analyze";
  String _confidence = "";
  bool _isAnalyzing = false;

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  Future<void> _loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/model.tflite');
      
      // Load Labels
      final labelData = await DefaultAssetBundle.of(context).loadString('assets/labels.txt');
      _labels = labelData.split('\n'); // Split by new line

    } catch (e) {
      setState(() => _resultLabel = "Model Error: $e");
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
        _isAnalyzing = true;
      });
      // Small delay to allow UI to show loader
      await Future.delayed(const Duration(milliseconds: 100));
      await _runInference(_selectedImage!);
    }
  }

  Future<void> _runInference(File imageFile) async {
    if (_interpreter == null) return;

    try {
      final imageData = await imageFile.readAsBytes();
      final img.Image? originalImage = img.decodeImage(imageData);
      if (originalImage == null) return;

      final img.Image resizedImage = img.copyResize(originalImage, width: 224, height: 224);

      // Quantized Input (0-255 Integers)
      var input = List.generate(1, (i) => List.generate(224, (j) => List.generate(224, (k) => List.generate(3, (l) => 0))));
      
      for (int y = 0; y < 224; y++) {
        for (int x = 0; x < 224; x++) {
          final pixel = resizedImage.getPixel(x, y);
          input[0][y][x][0] = pixel.r.toInt();
          input[0][y][x][1] = pixel.g.toInt();
          input[0][y][x][2] = pixel.b.toInt();
        }
      }

      var output = List.filled(1 * 1001, 0).reshape([1, 1001]);
      _interpreter!.run(input, output);

      List<int> probabilities = List<int>.from(output[0]);
      int maxScore = 0;
      int maxIndex = 0;

      for (int i = 0; i < probabilities.length; i++) {
        if (probabilities[i] > maxScore) {
          maxScore = probabilities[i];
          maxIndex = i;
        }
      }

      setState(() {
        _isAnalyzing = false;
        
        // Get the label, or fallback to ID if list is empty
        String labelName = _labels.isNotEmpty && maxIndex < _labels.length 
            ? _labels[maxIndex] 
            : "ID: $maxIndex";

        _resultLabel = labelName; // Now shows "Sports Car" instead of 818
        
        _confidence = "${(maxScore / 255.0 * 100).toStringAsFixed(1)}%";
      });
    } catch (e) {
      setState(() {
        _isAnalyzing = false;
        _resultLabel = "Error";
        _confidence = e.toString();
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
      appBar: AppBar(title: const Text("Symptom Screening")),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Image Picker Area
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 300,
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color ?? Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.withOpacity(0.3), width: 2),
                  ),
                  child: _selectedImage == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_rounded, size: 60, color: Colors.grey.shade400),
                            const SizedBox(height: 10),
                            Text("Tap to Select Photo", style: TextStyle(color: Colors.grey.shade600)),
                          ],
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.file(_selectedImage!, fit: BoxFit.cover),
                              if (_isAnalyzing)
                                Container(
                                  color: Colors.black45,
                                  child: const Center(child: CircularProgressIndicator(color: Colors.white)),
                                ),
                            ],
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 30),

              // 2. Result Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      const Text("ANALYSIS REPORT", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 10),
                      Text(
                        _resultLabel,
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      if (_confidence.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            "Confidence: $_confidence",
                            style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ]
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              const Center(
                child: Text(
                  "Uses quantization-aware MobileNet V1.\nInput: 224x224 (RGB) | Output: Uint8 Probability",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}