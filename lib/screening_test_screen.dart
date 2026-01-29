import 'dart:io';
import 'dart:ui'; // Added for BackdropFilter
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_mesh_detection/google_mlkit_face_mesh_detection.dart';
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
  
  String _leftEyeResult = "---";
  String _rightEyeResult = "---";
  bool _isAnalyzing = false;
  String _debugStatus = "Ready";
  
  // Visualizer State
  bool _showMesh = true; 
  File? _capturedImage;
  List<FaceMeshPoint> _meshPoints = [];
  Size? _imageSize;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    await Permission.camera.request();
    
    try {
      await _aiService.initialize();
    } catch (e) {
      print("DEBUG: CRITICAL AI ERROR: $e");
    }

    final cameras = await availableCameras();
    final frontCamera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _controller = CameraController(frontCamera, ResolutionPreset.high, enableAudio: false);
    await _controller!.initialize();
    if (mounted) setState(() {});
  }

  Future<void> _captureAndAnalyze() async {
    if (_controller == null || _isAnalyzing) return;

    setState(() {
      _isAnalyzing = true;
      _debugStatus = "Capturing...";
      _meshPoints = []; 
    });

    try {
      final XFile image = await _controller!.takePicture();
      final decodedImage = await decodeImageFromList(await image.readAsBytes());
      
      setState(() {
        _capturedImage = File(image.path);
        _imageSize = Size(decodedImage.width.toDouble(), decodedImage.height.toDouble());
        _debugStatus = "Analyzing...";
      });

      final results = await _aiService.analyzePhoto(image.path);

      if (mounted) {
        setState(() {
          if (results.containsKey('Error')) {
             _debugStatus = results['Error'];
          } else {
             _debugStatus = "Analysis Complete";
             _leftEyeResult = results['Left'] ?? "Unknown";
             _rightEyeResult = results['Right'] ?? "Unknown";
             
             if (results.containsKey('Mesh')) {
               _meshPoints = results['Mesh'] as List<FaceMeshPoint>;
             }
          }
        });
      }
    } catch (e) {
      print("DEBUG: UI ERROR: $e");
      setState(() => _debugStatus = "Error: Please try again");
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  void _reset() {
    setState(() {
      _capturedImage = null;
      _meshPoints = [];
      _leftEyeResult = "---";
      _rightEyeResult = "---";
      _debugStatus = "Ready";
    });
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

    final size = MediaQuery.of(context).size;
    // WARP FIX: Calculate Scale to Cover Screen
    var scale = size.aspectRatio * _controller!.value.aspectRatio;
    if (scale < 1) scale = 1 / scale;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Symptom Screening", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        actions: [
          Switch.adaptive(
            value: _showMesh,
            onChanged: (v) => setState(() => _showMesh = v),
            activeColor: Colors.blueAccent,
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Layer: Camera OR Captured Image
          if (_capturedImage != null) 
            Image.file(_capturedImage!, fit: BoxFit.cover)
          else
            Transform.scale(
              scale: scale,
              child: Center(child: CameraPreview(_controller!)),
            ),

          // 2. Layer: Face Mesh Visualizer
          if (_showMesh && _meshPoints.isNotEmpty && _imageSize != null)
             CustomPaint(
               painter: FaceMeshPainter(_meshPoints, _imageSize!, MediaQuery.of(context).size),
             ),

          // 3. Layer: Eye Guide Overlay (Only in live mode)
          if (_capturedImage == null) EyeCameraOverlay(),
          
          // 4. Layer: UI Controls (Frosted Glass)
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  color: Colors.white.withOpacity(0.85),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Status / Results
                      if (_capturedImage != null) ...[
                        Row(
                          children: [
                            Expanded(child: _buildResultTile("Left Eye", _leftEyeResult)),
                            Container(width: 1, height: 40, color: Colors.grey.shade300),
                            Expanded(child: _buildResultTile("Right Eye", _rightEyeResult)),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ] else 
                        Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: Text(
                            _isAnalyzing ? "Processing..." : "Align face within guide",
                            style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                          ),
                        ),

                      // Action Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isAnalyzing ? null : (_capturedImage == null ? _captureAndAnalyze : _reset),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _capturedImage == null ? Colors.blueAccent : Colors.grey.shade800,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          child: _isAnalyzing 
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Text(
                                _capturedImage == null ? "Analyze Face" : "New Scan",
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultTile(String title, String result) {
    // Simple color logic for demo
    bool isHealthy = result.toLowerCase().contains("healthy") || result.toLowerCase().contains("normal");
    Color color = isHealthy ? Colors.green : Colors.orange.shade800;
    
    return Column(
      children: [
        Text(title, style: TextStyle(fontSize: 13, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(
          result,
          textAlign: TextAlign.center,
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ],
    );
  }
}

// Reusing your existing painter logic as it handles file-based coordinates correctly
class FaceMeshPainter extends CustomPainter {
  final List<FaceMeshPoint> points;
  final Size imageSize;
  final Size screenSize;

  FaceMeshPainter(this.points, this.imageSize, this.screenSize);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.greenAccent.withOpacity(0.6)..strokeWidth = 2;
    
    // BoxFit.cover logic to match Image.file and CameraPreview
    final double scaleX = screenSize.width / imageSize.width;
    final double scaleY = screenSize.height / imageSize.height;
    final double scale = scaleX > scaleY ? scaleX : scaleY;
    
    final double offsetX = (screenSize.width - (imageSize.width * scale)) / 2;
    final double offsetY = (screenSize.height - (imageSize.height * scale)) / 2;

    for (var point in points) {
      canvas.drawCircle(
        Offset((point.x * scale) + offsetX, (point.y * scale) + offsetY),
        2, 
        paint
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}