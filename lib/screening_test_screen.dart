import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_mesh_detection/google_mlkit_face_mesh_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/ai_service.dart';
import '../widgets/camera_overlay.dart';
import '../widgets/rounded_card.dart';

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
  String _errorMessage = ""; // Holds actual errors
  
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
    try { await _aiService.initialize(); } catch (e) {}

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
      _errorMessage = ""; // Clear errors
      _meshPoints = []; 
    });

    try {
      final XFile image = await _controller!.takePicture();
      final decodedImage = await decodeImageFromList(await image.readAsBytes());
      
      setState(() {
        _capturedImage = File(image.path);
        _imageSize = Size(decodedImage.width.toDouble(), decodedImage.height.toDouble());
      });

      final results = await _aiService.analyzePhoto(image.path);

      if (mounted) {
        setState(() {
          if (results.containsKey('Error')) {
             _errorMessage = results['Error']; // Show this!
             _leftEyeResult = "---";
             _rightEyeResult = "---";
          } else {
             _leftEyeResult = results['Left'] ?? "Unknown";
             _rightEyeResult = results['Right'] ?? "Unknown";
             // Optional: Add mesh logic if needed later
          }
        });
      }
    } catch (e) {
      setState(() => _errorMessage = "System Error: ${e.toString()}");
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
      _errorMessage = "";
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
      return const Scaffold(
        backgroundColor: Color(0xFF121212), 
        body: Center(child: CircularProgressIndicator(color: Colors.white))
      );
    }

    final size = MediaQuery.of(context).size;
    var scale = size.aspectRatio * _controller!.value.aspectRatio;
    if (scale < 1) scale = 1 / scale;

    return Scaffold(
      backgroundColor: const Color(0xFF121212), // Dark Gray Base
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFFE5E5E7)), // Off-white
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Symptom Screening", style: TextStyle(color: Color(0xFFE5E5E7), fontWeight: FontWeight.w600)),
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
          // 1. Camera / Image Layer
          if (_capturedImage != null) 
            Image.file(_capturedImage!, fit: BoxFit.cover)
          else
            Transform.scale(
              scale: scale,
              child: Center(child: CameraPreview(_controller!)),
            ),

          // 2. Mesh Layer
          if (_showMesh && _meshPoints.isNotEmpty && _imageSize != null)
             CustomPaint(
               painter: FaceMeshPainter(_meshPoints, _imageSize!, MediaQuery.of(context).size),
             ),

          // 3. Eye Guide (Live only)
          if (_capturedImage == null) EyeCameraOverlay(),
          
          // 4. UI Layer
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: RoundedCard(
              borderRadius: 22,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              backgroundColor: const Color(0xFF1F1F22),
              borderColor: Colors.white70,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_errorMessage.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFD9EE),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white70),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Color(0xFFA35E5A)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _errorMessage,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_capturedImage != null && _errorMessage.isEmpty) ...[
                    Row(
                      children: [
                        Expanded(child: _buildResultTile("Left Eye", _leftEyeResult)),
                        Container(width: 1, height: 50, color: Colors.white24),
                        Expanded(child: _buildResultTile("Right Eye", _rightEyeResult)),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ] else if (_errorMessage.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Text(
                        "Position face within the guide",
                        style: TextStyle(color: Color(0xFFD0D0D4), fontWeight: FontWeight.w500),
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isAnalyzing ? null : (_capturedImage == null ? _captureAndAnalyze : _reset),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _capturedImage == null ? const Color(0xFF7FC86D) : const Color(0xFFA68AC0),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: _isAnalyzing
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(
                              _capturedImage == null ? "Analyze Face" : "New Scan",
                              style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultTile(String title, String result) {
    bool isHealthy = result.toLowerCase().contains("healthy") || result.toLowerCase().contains("normal");
    Color color = isHealthy ? const Color(0xFF9DE18A) : const Color(0xFFE9C37F);
    
    return Column(
      children: [
        Text(
          title.toUpperCase(), 
          style: const TextStyle(fontSize: 11, color: Color(0xFF8E8E93), fontWeight: FontWeight.w600, letterSpacing: 0.8)
        ),
        const SizedBox(height: 6),
        Text(
          result,
          textAlign: TextAlign.center,
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 17, height: 1.2),
        ),
      ],
    );
  }
}

// Reused Painter (Unchanged)
class FaceMeshPainter extends CustomPainter {
  final List<FaceMeshPoint> points;
  final Size imageSize;
  final Size screenSize;

  FaceMeshPainter(this.points, this.imageSize, this.screenSize);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.greenAccent.withOpacity(0.6)..strokeWidth = 2;
    final double scaleX = screenSize.width / imageSize.width;
    final double scaleY = screenSize.height / imageSize.height;
    final double scale = scaleX > scaleY ? scaleX : scaleY;
    final double offsetX = (screenSize.width - (imageSize.width * scale)) / 2;
    final double offsetY = (screenSize.height - (imageSize.height * scale)) / 2;

    for (var point in points) {
      canvas.drawCircle(Offset((point.x * scale) + offsetX, (point.y * scale) + offsetY), 2, paint);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}