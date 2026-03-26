import 'dart:typed_data';
import 'dart:ui';
import 'dart:async';
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
    options: FaceDetectorOptions(enableClassification: true, performanceMode: FaceDetectorMode.fast),
  );
  final FaceMeshDetector _meshDetector = FaceMeshDetector(option: FaceMeshDetectorOptions.faceMesh);

  final ValueNotifier<bool> faceDetected = ValueNotifier<bool>(false);
  final ValueNotifier<double> distanceCm = ValueNotifier<double>(0.0);
  final ValueNotifier<List<FaceMeshPoint>> meshPoints = ValueNotifier<List<FaceMeshPoint>>([]);

  double? _calibrationConstant;
  double _currentFaceWidth = 0.0;
  bool _eyesClosed = false;
  bool _recovering = false;

  Future<void> _disposeControllerOnly() async {
    try {
      await controller?.dispose();
    } catch (_) {}
    controller = null;
    _initialized = false;
    _isProcessing = false;
    _lastRun = 0;
    _lastMeshRun = 0;
    _lastFrameProcessedAt = 0;
  }

  Future<void> initialize({CameraLensDirection preferred = CameraLensDirection.front}) async {
    if (_initialized) return;
    final permission = await Permission.camera.status;
    if (!permission.isGranted) {
      final requested = await Permission.camera.request();
      if (!requested.isGranted) return;
    }
    final cameras = await availableCameras();
    final cam = cameras.firstWhere((c) => c.lensDirection == preferred, orElse: () => cameras.first);
    controller = CameraController(
      cam,
      ResolutionPreset.medium,
      enableAudio: false,
    );
    await controller!.initialize();
    await controller!.startImageStream(_processCameraImage);
    _initialized = true;
  }

  Future<void> ensureMonitoring({CameraLensDirection preferred = CameraLensDirection.front}) async {
    if (_recovering) return;
    _recovering = true;

    try {
      if (!_initialized || controller == null) {
        _initialized = false;
        await initialize(preferred: preferred);
        return;
      }

      if (!controller!.value.isInitialized) {
        await _disposeControllerOnly();
        await initialize(preferred: preferred);
        return;
      }

      if (!controller!.value.isStreamingImages) {
        try {
          await controller!.startImageStream(_processCameraImage);
        } catch (_) {
          final lens = controller!.description.lensDirection;
          await _disposeControllerOnly();
          await initialize(preferred: lens);
        }
      } else {
        final now = DateTime.now().millisecondsSinceEpoch;
        if (_lastFrameProcessedAt > 0 && now - _lastFrameProcessedAt > 1800) {
          final lens = controller!.description.lensDirection;
          await _disposeControllerOnly();
          await initialize(preferred: lens);
        }
      }
    } finally {
      _recovering = false;
    }
  }

  Future<void> ensureMonitoringWithRetry({
    CameraLensDirection preferred = CameraLensDirection.front,
    int attempts = 4,
    Duration delay = const Duration(milliseconds: 350),
  }) async {
    for (int i = 0; i < attempts; i++) {
      try {
        await ensureMonitoring(preferred: preferred);
        if (controller != null && controller!.value.isInitialized && controller!.value.isStreamingImages) {
          return;
        }
      } catch (_) {}
      if (i < attempts - 1) {
        await Future.delayed(delay);
      }
    }

    await forceRestartMonitoring(preferred: preferred);
  }

  Future<void> forceRestartMonitoring({CameraLensDirection preferred = CameraLensDirection.front}) async {
    if (_recovering) return;
    _recovering = true;
    try {
      await _disposeControllerOnly();
      await initialize(preferred: preferred);
    } finally {
      _recovering = false;
    }
  }

  Future<void> restartMonitoringWithDelay({
    CameraLensDirection preferred = CameraLensDirection.front,
    Duration delay = const Duration(milliseconds: 650),
  }) async {
    await Future.delayed(delay);
    await forceRestartMonitoring(preferred: preferred);
  }

  Future<void> dispose() async {
    await _disposeControllerOnly();
    _faceDetector.close();
    _meshDetector.close();
  }

  void calibrateReferenceCm(double cm) {
    if (_currentFaceWidth == 0) return;
    _calibrationConstant = cm * _currentFaceWidth;
    // mark as calibrated
    MetricsService.instance.setCalibrated(true);
  }

  void calibrateReferenceFromMeasuredWidth(double cm, double measuredFaceWidth) {
    if (measuredFaceWidth <= 0) return;
    _calibrationConstant = cm * measuredFaceWidth;
    _currentFaceWidth = measuredFaceWidth;
    MetricsService.instance.setCalibrated(true);
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
  int _lastMeshRun = 0;
  static const int _detectIntervalMs = 40;
  static const int _meshIntervalMs = 66;
  bool _isProcessing = false;
  int _lastFrameProcessedAt = 0;

  Future<void> _processCameraImage(CameraImage image) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastRun < _detectIntervalMs) return;
    if (_isProcessing) return;
    _isProcessing = true;
    _lastRun = now;
    _lastFrameProcessedAt = now;
    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) return;
      final faces = await _faceDetector.processImage(inputImage);
      if (faces.isNotEmpty) {
        final face = faces.first;
        _currentFaceWidth = face.boundingBox.width;
        faceDetected.value = true;
        // Blink detection (uses ML Kit classification probabilities)
        if (face.leftEyeOpenProbability != null && face.rightEyeOpenProbability != null) {
          final avg = (face.leftEyeOpenProbability! + face.rightEyeOpenProbability!) / 2.0;
          final currentlyClosed = avg < 0.38;
          if (currentlyClosed && !_eyesClosed) {
            _eyesClosed = true;
          } else if (avg > 0.58 && _eyesClosed) {
            _eyesClosed = false;
            MetricsService.instance.registerBlink();
          }
        }
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

      if (now - _lastMeshRun >= _meshIntervalMs) {
        _lastMeshRun = now;
        try {
          final meshes = await _meshDetector.processImage(inputImage);
          if (meshes.isNotEmpty) {
            meshPoints.value = meshes.first.points;
          } else {
            meshPoints.value = [];
          }
        } catch (e) {
          meshPoints.value = [];
        }
      }
    } catch (e) {
      if (kDebugMode) print('DetectionService error: $e');
    } finally {
      _isProcessing = false;
    }
  }
}
