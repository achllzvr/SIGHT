import 'dart:typed_data';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_face_mesh_detection/google_mlkit_face_mesh_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'metrics_service.dart';

class DetectionService {
  DetectionService._private();
  static final DetectionService instance = DetectionService._private();

  CameraController? controller;
  bool _initialized = false;

  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(enableLandmarks: true, performanceMode: FaceDetectorMode.accurate),
  );
  final FaceMeshDetector _meshDetector = FaceMeshDetector(option: FaceMeshDetectorOptions.faceMesh);

  final ValueNotifier<bool> faceDetected = ValueNotifier<bool>(false);
  final ValueNotifier<double> distanceCm = ValueNotifier<double>(0.0);
  final ValueNotifier<List<FaceMeshPoint>> meshPoints = ValueNotifier<List<FaceMeshPoint>>([]);

  double? _calibrationConstant;
  double _currentFaceWidth = 0.0;

  Future<void> initialize({CameraLensDirection preferred = CameraLensDirection.front}) async {
    if (_initialized) return;
    await Permission.camera.request();
    final cameras = await availableCameras();
    final cam = cameras.firstWhere((c) => c.lensDirection == preferred, orElse: () => cameras.first);
    controller = CameraController(cam, ResolutionPreset.medium, enableAudio: false);
    await controller!.initialize();
    _initialized = true;
    controller!.startImageStream(_processCameraImage);
  }

  Future<void> dispose() async {
    try {
      await controller?.dispose();
    } catch (_) {}
    _faceDetector.close();
    _meshDetector.close();
  }

  void calibrateReferenceCm(double cm) {
    if (_currentFaceWidth == 0) return;
    _calibrationConstant = cm * _currentFaceWidth;
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    final camera = controller!.description;
    final rotation = InputImageRotationValue.fromRawValue(camera.sensorOrientation) ?? InputImageRotation.rotation270deg;
    if (image.format.group == ImageFormatGroup.yuv420) {
      return InputImage.fromBytes(bytes: _yuv420ToNv21(image), metadata: InputImageMetadata(size: Size(image.width.toDouble(), image.height.toDouble()), rotation: rotation, format: InputImageFormat.nv21, bytesPerRow: image.width));
    } else if (image.format.group == ImageFormatGroup.bgra8888) {
      return InputImage.fromBytes(bytes: image.planes[0].bytes, metadata: InputImageMetadata(size: Size(image.width.toDouble(), image.height.toDouble()), rotation: rotation, format: InputImageFormat.bgra8888, bytesPerRow: image.planes[0].bytesPerRow));
    }
    return null;
  }

  Uint8List _yuv420ToNv21(CameraImage image) {
    final int width = image.width; final int height = image.height; final Plane yPlane = image.planes[0]; final Plane uPlane = image.planes[1]; final Plane vPlane = image.planes[2]; final Uint8List yBuffer = yPlane.bytes; final Uint8List uBuffer = uPlane.bytes; final Uint8List vBuffer = vPlane.bytes; final int numPixels = (width * height * 1.5).toInt(); final Uint8List nv21 = Uint8List(numPixels); int idY = 0; for (int i = 0; i < height; i++) { int srcPos = i * yPlane.bytesPerRow; for (int j = 0; j < width; j++) { nv21[idY++] = yBuffer[srcPos + j]; } } int idUV = width * height; final int uvHeight = height ~/ 2; final int uvWidth = width ~/ 2; final int uPixelStride = uPlane.bytesPerPixel ?? 1; final int uRowStride = uPlane.bytesPerRow; final int vPixelStride = vPlane.bytesPerPixel ?? 1; final int vRowStride = vPlane.bytesPerRow; for (int i = 0; i < uvHeight; i++) { for (int j = 0; j < uvWidth; j++) { int uIndex = i * uRowStride + j * uPixelStride; int vIndex = i * vRowStride + j * vPixelStride; nv21[idUV++] = vBuffer[vIndex]; nv21[idUV++] = uBuffer[uIndex]; } } return nv21;
  }

  int _lastRun = 0;
  bool _isProcessing = false;

  Future<void> _processCameraImage(CameraImage image) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastRun < 100) return;
    if (_isProcessing) return;
    _isProcessing = true;
    _lastRun = now;
    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) return;
      final faces = await _faceDetector.processImage(inputImage);
      if (faces.isNotEmpty) {
        final face = faces.first;
        _currentFaceWidth = face.boundingBox.width;
        faceDetected.value = true;
        if (_calibrationConstant != null && _currentFaceWidth > 0) {
          final cm = _calibrationConstant! / _currentFaceWidth;
          distanceCm.value = cm;
          MetricsService.instance.setDistance(cm);
          MetricsService.instance.setFaceDetected(true);
        }
      } else {
        faceDetected.value = false;
        distanceCm.value = 0.0;
        MetricsService.instance.setFaceDetected(false);
        MetricsService.instance.setDistance(0.0);
      }

      try {
        final meshes = await _meshDetector.processImage(inputImage);
        if (meshes.isNotEmpty) meshPoints.value = meshes.first.points;
        else meshPoints.value = [];
      } catch (e) {
        meshPoints.value = [];
      }
    } catch (e) {
      if (kDebugMode) print('DetectionService error: $e');
    } finally {
      _isProcessing = false;
    }
  }
}
