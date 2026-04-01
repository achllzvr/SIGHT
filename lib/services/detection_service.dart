import 'dart:typed_data';
import 'dart:ui';
import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_face_mesh_detection/google_mlkit_face_mesh_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'background_notification_service.dart';
import 'local_metrics_service.dart';
import 'metrics_service.dart';
import 'offline_database_service.dart';
import 'offline_models.dart';

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
  bool _wakelockActive = false;

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
    await OfflineDatabaseService.instance.initialize();
    _calibrationConstant ??= await OfflineDatabaseService.instance.loadCalibrationConstant();
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

  Future<void> enableWakelockForMonitoring() async {
    if (_wakelockActive) return;
    try {
      await WakelockPlus.enable();
      _wakelockActive = true;
      if (kDebugMode) print('Wakelock enabled for continuous monitoring');
    } catch (e) {
      if (kDebugMode) print('Failed to enable wakelock: $e');
    }
  }

  Future<void> disableWakelock() async {
    if (!_wakelockActive) return;
    try {
      await WakelockPlus.disable();
      _wakelockActive = false;
      if (kDebugMode) print('Wakelock disabled');
    } catch (e) {
      if (kDebugMode) print('Failed to disable wakelock: $e');
    }
  }

  Future<void> forceHardRestart({CameraLensDirection preferred = CameraLensDirection.front}) async {
    if (_recovering) return;
    _recovering = true;
    try {
      _lastFrameProcessedAt = 0; // Reset frame timestamp
      await _disposeControllerOnly();
      await Future.delayed(const Duration(milliseconds: 200));
      await initialize(preferred: preferred);
      if (kDebugMode) print('Force hard restart completed');
    } catch (e) {
      if (kDebugMode) print('Force hard restart failed: $e');
    } finally {
      _recovering = false;
    }
  }

  Future<void> processCameraFrame(CameraImage image) => _processCameraImage(image);

  double calculateDistance({required double faceWidthPixels, required double calibrationData}) {
    if (faceWidthPixels <= 0) {
      return 0.0;
    }
    return calibrationData / faceWidthPixels;
  }

  double calculateEAR(List<Offset> eyeLandmarks) {
    if (eyeLandmarks.length < 6) {
      return 0.0;
    }

    final vertical1 = (eyeLandmarks[1] - eyeLandmarks[5]).distance;
    final vertical2 = (eyeLandmarks[2] - eyeLandmarks[4]).distance;
    final horizontal = (eyeLandmarks[0] - eyeLandmarks[3]).distance;
    if (horizontal == 0) {
      return 0.0;
    }

    return (vertical1 + vertical2) / (2.0 * horizontal);
  }

  bool detectBlink({required double currentEAR, required double baselineEAR}) {
    final closedThreshold = baselineEAR * 0.75;
    final openThreshold = baselineEAR * 0.95;

    if (currentEAR <= closedThreshold) {
      _eyesClosed = true;
      return false;
    }

    if (currentEAR >= openThreshold && _eyesClosed) {
      _eyesClosed = false;
      return true;
    }

    return false;
  }

  Future<void> dispose() async {
    await disableWakelock();
    await _disposeControllerOnly();
    _faceDetector.close();
    _meshDetector.close();
  }

  void calibrateReferenceCm(double cm) {
    if (_currentFaceWidth == 0) return;
    _calibrationConstant = cm * _currentFaceWidth;
    unawaited(OfflineDatabaseService.instance.saveCalibrationConstant(_calibrationConstant!));
    MetricsService.instance.setCalibrated(true);
    BackgroundNotificationService.instance.start();
    BackgroundNotificationService.instance.refreshNow().then((ok) {
      if (!ok && kDebugMode) {
        debugPrint('Background notification refresh failed: ${BackgroundNotificationService.instance.lastError}');
      }
    });
  }

  void calibrateReferenceFromMeasuredWidth(double cm, double measuredFaceWidth) {
    if (measuredFaceWidth <= 0) return;
    _calibrationConstant = cm * measuredFaceWidth;
    _currentFaceWidth = measuredFaceWidth;
    unawaited(OfflineDatabaseService.instance.saveCalibrationConstant(_calibrationConstant!));
    MetricsService.instance.setCalibrated(true);
    BackgroundNotificationService.instance.start();
    BackgroundNotificationService.instance.refreshNow().then((ok) {
      if (!ok && kDebugMode) {
        debugPrint('Background notification refresh failed: ${BackgroundNotificationService.instance.lastError}');
      }
    });
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

  int get millisSinceLastFrame {
    if (_lastFrameProcessedAt == 0) return 1 << 30;
    return DateTime.now().millisecondsSinceEpoch - _lastFrameProcessedAt;
  }

  bool get hasReceivedAnyFrame => _lastFrameProcessedAt > 0;

  bool get hasFreshFrames => millisSinceLastFrame < 2000;

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
          if (detectBlink(currentEAR: avg, baselineEAR: 0.52)) {
            MetricsService.instance.registerBlink();
            unawaited(
              LocalMetricsService.instance.logRawEvent(
                'blinkRate',
                MetricsService.instance.blinkRatePerMinNotifier.value.toDouble(),
                DateTime.now(),
              ),
            );
          }
        }
        if (_calibrationConstant != null && _currentFaceWidth > 0) {
          final cm = calculateDistance(faceWidthPixels: _currentFaceWidth, calibrationData: _calibrationConstant!);
          distanceCm.value = cm;
          MetricsService.instance.setDistance(cm);
          MetricsService.instance.setFaceDetected(true);
          unawaited(LocalMetricsService.instance.logRawEvent('distanceCm', cm, DateTime.now()));
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
