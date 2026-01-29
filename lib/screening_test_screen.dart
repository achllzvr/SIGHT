import 'dart:io';
import 'dart:ui'; 
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
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  // Dark Gray Frosted Card
                  color: const Color(0xFF2C2C2E).withOpacity(0.90), 
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      
                      // ERROR MESSAGE (Crucial Fix)
                      if (_errorMessage.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.withOpacity(0.5))
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Colors.redAccent),
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

                      // RESULT TILES
                      if (_capturedImage != null && _errorMessage.isEmpty) ...[
                        Row(
                          children: [
                            Expanded(child: _buildResultTile("Left Eye", _leftEyeResult)),
                            Container(width: 1, height: 50, color: Colors.grey.withOpacity(0.3)),
                            Expanded(child: _buildResultTile("Right Eye", _rightEyeResult)),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ] else if (_errorMessage.isEmpty) 
                        const Padding(
                          padding: EdgeInsets.only(bottom: 24),
                          child: Text(
                            "Position face within the guide",
                            style: TextStyle(color: Color(0xFF98989D), fontWeight: FontWeight.w500),
                          ),
                        ),

                      // BUTTON
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isAnalyzing ? null : (_capturedImage == null ? _captureAndAnalyze : _reset),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _capturedImage == null ? Colors.blueAccent : const Color(0xFF3A3A3C),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 18),
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
    bool isHealthy = result.toLowerCase().contains("healthy") || result.toLowerCase().contains("normal");
    Color color = isHealthy ? Colors.greenAccent : Colors.orangeAccent;
    
    return Column(
      children: [
        Text(
          title.toUpperCase(), 
          style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E93), fontWeight: FontWeight.w600, letterSpacing: 0.5)
        ),
        const SizedBox(height: 8),
        Text(
          result,
          textAlign: TextAlign.center,
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18, height: 1.2),
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