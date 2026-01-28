import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/ai_service.dart';
import '../widgets/camera_overlay.dart';

class ScreeningTestScreen extends StatefulWidget {
  const ScreeningTestScreen({super.key});

  @override
  State<ScreeningTestScreen> createState() => _ScreeningTestScreenState();
}

class _ScreeningTestScreenState extends State<ScreeningTestScreen> {
  CameraController? _controller;
  final EyeDiagnosisService _aiService = EyeDiagnosisService();
  
  // Results State
  String _leftEyeResult = "Align Left Eye";
  String _rightEyeResult = "Align Right Eye";
  bool _isServiceInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    // 1. Request Permissions
    await Permission.camera.request();

    // 2. Initialize AI
    await _aiService.initialize();
    setState(() => _isServiceInitialized = true);

    // 3. Setup Camera
    final cameras = await availableCameras();
    // Use Front Camera for Self-Check
    final frontCamera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _controller = CameraController(
      frontCamera,
      ResolutionPreset.medium, // Medium is faster for AI processing
      enableAudio: false,
    );

    await _controller!.initialize();

    // Get the sensor orientation (e.g., 270 for front camera)
    int sensorRotation = _controller!.description.sensorOrientation;

    if (mounted) {
      setState(() {});
      _controller!.startImageStream((image) async {
        if (_isServiceInitialized) {
          // PASS sensorRotation HERE
          final results = await _aiService.analyzeFrame(image, sensorRotation);
          
          if (mounted && results.isNotEmpty) {
            setState(() {
              _leftEyeResult = results['Left'] ?? "Scanning...";
              _rightEyeResult = results['Right'] ?? "Scanning...";
            });
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _aiService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Camera Feed
          CameraPreview(_controller!),

          // 2. The Green "Safe Area" Overlay
          EyeCameraOverlay(),

          // 3. Results Display (Bottom Sheet)
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildResultColumn("Left Eye", _leftEyeResult),
                  Container(width: 1, height: 50, color: Colors.grey),
                  _buildResultColumn("Right Eye", _rightEyeResult),
                ],
              ),
            ),
          ),
          
          // 4. Back Button
          Positioned(
            top: 50,
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultColumn(String title, String result) {
    // Color coding based on result
    Color statusColor = Colors.black;
    if (result.contains("Healthy")) statusColor = Colors.green;
    if (result.contains("Uveitis") || result.contains("Cataract")) statusColor = Colors.red;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 5),
        Text(
          result,
          style: TextStyle(
            color: statusColor,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}