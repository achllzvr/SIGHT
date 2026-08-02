import 'dart:ui';
import 'dart:async';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'local_metrics_service.dart';
import 'metrics_service.dart';
import 'offline_database_service.dart';
import 'watch_tracking_session.dart';

/// Isolate-safe YUV→NV21 conversion (T4). Args must be SendPort-safe (Map + typed lists).
Uint8List _yuv420ToNv21Isolate(Map<String, dynamic> args) {
  final width = args['width'] as int;
  final height = args['height'] as int;
  final yBuffer = args['y'] as Uint8List;
  final uBuffer = args['u'] as Uint8List;
  final vBuffer = args['v'] as Uint8List;
  final yRowStride = args['yRow'] as int;
  final uRowStride = args['uRow'] as int;
  final vRowStride = args['vRow'] as int;
  final uPixelStride = args['uPix'] as int;
  final vPixelStride = args['vPix'] as int;

  final numPixels = (width * height * 1.5).toInt();
  final nv21 = Uint8List(numPixels);
  var idY = 0;
  for (var i = 0; i < height; i++) {
    final srcPos = i * yRowStride;
    for (var j = 0; j < width; j++) {
      nv21[idY++] = yBuffer[srcPos + j];
    }
  }
  var idUV = width * height;
  final uvHeight = height ~/ 2;
  final uvWidth = width ~/ 2;
  for (var i = 0; i < uvHeight; i++) {
    for (var j = 0; j < uvWidth; j++) {
      final uIndex = i * uRowStride + j * uPixelStride;
      final vIndex = i * vRowStride + j * vPixelStride;
      nv21[idUV++] = vBuffer[vIndex];
      nv21[idUV++] = uBuffer[uIndex];
    }
  }
  return nv21;
}

class DetectionService {
  DetectionService._private();
  static final DetectionService instance = DetectionService._private();

  CameraController? controller;
  bool _initialized = false;
  ResolutionPreset _resolutionPreset = ResolutionPreset.medium;

  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(enableClassification: true, performanceMode: FaceDetectorMode.fast),
  );
  // Face mesh dual-pipeline intentionally omitted (T1) — too expensive on mid-range devices.
  final ValueNotifier<bool> faceDetected = ValueNotifier<bool>(false);
  final ValueNotifier<double> distanceCm = ValueNotifier<double>(0.0);

  double? _calibrationConstant;
  double _currentFaceWidth = 0.0;
  bool _eyesClosed = false;
  bool _recovering = false;
  bool _wakelockActive = false;
  int _monitorConsumers = 0;

  Future<void> _disposeControllerOnly() async {
    try {
      await controller?.dispose();
    } catch (_) {}
    controller = null;
    _initialized = false;
    _isProcessing = false;
    _lastRun = 0;
    _lastFrameProcessedAt = 0;
    // Clear stale flags so break/UI don't think a face is still present
    faceDetected.value = false;
    distanceCm.value = 0.0;
  }

  /// Request monitoring for a screen that needs camera. Pair with [releaseMonitoring].
  Future<void> acquireMonitoring({
    CameraLensDirection preferred = CameraLensDirection.front,
    ResolutionPreset resolution = ResolutionPreset.medium,
  }) async {
    _monitorConsumers++;
    await ensureMonitoringWithRetry(preferred: preferred, resolution: resolution);
  }

  /// Release a consumer; stops camera when nobody needs it.
  Future<void> releaseMonitoring() async {
    if (_monitorConsumers > 0) {
      _monitorConsumers--;
    }
    if (_monitorConsumers <= 0) {
      _monitorConsumers = 0;
      await stopMonitoring();
    }
  }

  Future<void> stopMonitoring() async {
    // Keep camera alive while BlinkTest / other screens still hold consumers.
    if (_monitorConsumers > 0) {
      return;
    }
    await disableWakelock();
    await _disposeControllerOnly();
  }

  Future<void> initialize({
    CameraLensDirection preferred = CameraLensDirection.front,
    ResolutionPreset resolution = ResolutionPreset.medium,
  }) async {
    if (_initialized) return;
    await OfflineDatabaseService.instance.initialize();
    _calibrationConstant ??= await OfflineDatabaseService.instance.loadCalibrationConstant();
    final permission = await Permission.camera.status;
    if (!permission.isGranted) {
      final requested = await Permission.camera.request();
      if (!requested.isGranted) return;
    }
    _resolutionPreset = resolution;
    final cameras = await availableCameras();
    final cam = cameras.firstWhere((c) => c.lensDirection == preferred, orElse: () => cameras.first);
    controller = CameraController(
      cam,
      _resolutionPreset,
      enableAudio: false,
    );
    await controller!.initialize();
    await controller!.startImageStream(_processCameraImage);
    _initialized = true;
  }

  Future<void> ensureMonitoring({
    CameraLensDirection preferred = CameraLensDirection.front,
    ResolutionPreset resolution = ResolutionPreset.medium,
  }) async {
    if (_recovering) return;
    _recovering = true;

    try {
      final needsResolutionSwitch =
          _initialized && controller != null && _resolutionPreset != resolution;

      if (!_initialized || controller == null || needsResolutionSwitch) {
        if (needsResolutionSwitch) {
          await _disposeControllerOnly();
        }
        _initialized = false;
        await initialize(preferred: preferred, resolution: resolution);
        return;
      }

      if (!controller!.value.isInitialized) {
        await _disposeControllerOnly();
        await initialize(preferred: preferred, resolution: resolution);
        return;
      }

      if (!controller!.value.isStreamingImages) {
        try {
          await controller!.startImageStream(_processCameraImage);
        } catch (_) {
          final lens = controller!.description.lensDirection;
          await _disposeControllerOnly();
          await initialize(preferred: lens, resolution: resolution);
        }
      } else {
        final now = DateTime.now().millisecondsSinceEpoch;
        if (_lastFrameProcessedAt > 0 && now - _lastFrameProcessedAt > 1800) {
          final lens = controller!.description.lensDirection;
          await _disposeControllerOnly();
          await initialize(preferred: lens, resolution: resolution);
        }
      }
    } finally {
      _recovering = false;
    }
  }

  Future<void> ensureMonitoringWithRetry({
    CameraLensDirection preferred = CameraLensDirection.front,
    ResolutionPreset resolution = ResolutionPreset.medium,
    int attempts = 4,
    Duration delay = const Duration(milliseconds: 350),
  }) async {
    for (int i = 0; i < attempts; i++) {
      try {
        await ensureMonitoring(preferred: preferred, resolution: resolution);
        if (controller != null && controller!.value.isInitialized && controller!.value.isStreamingImages) {
          return;
        }
      } catch (_) {}
      if (i < attempts - 1) {
        await Future.delayed(delay);
      }
    }

    await forceRestartMonitoring(preferred: preferred, resolution: resolution);
  }

  Future<void> forceRestartMonitoring({
    CameraLensDirection preferred = CameraLensDirection.front,
    ResolutionPreset resolution = ResolutionPreset.medium,
  }) async {
    if (_recovering) return;
    _recovering = true;
    try {
      await _disposeControllerOnly();
      await initialize(preferred: preferred, resolution: resolution);
    } finally {
      _recovering = false;
    }
  }

  Future<void> restartMonitoringWithDelay({
    CameraLensDirection preferred = CameraLensDirection.front,
    ResolutionPreset resolution = ResolutionPreset.medium,
    Duration delay = const Duration(milliseconds: 650),
  }) async {
    await Future.delayed(delay);
    await forceRestartMonitoring(preferred: preferred, resolution: resolution);
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

  Future<void> forceHardRestart({
    CameraLensDirection preferred = CameraLensDirection.front,
    ResolutionPreset resolution = ResolutionPreset.medium,
  }) async {
    if (_recovering) return;
    _recovering = true;
    try {
      _lastFrameProcessedAt = 0;
      await _disposeControllerOnly();
      await Future.delayed(const Duration(milliseconds: 200));
      await initialize(preferred: preferred, resolution: resolution);
      if (kDebugMode) print('Force hard restart completed');
    } catch (e) {
      if (kDebugMode) print('Force hard restart failed: $e');
    } finally {
      _recovering = false;
    }
  }

  /// Ensures continuous monitoring with background-aware recovery.
  Future<void> ensureContinuousMonitoring({
    CameraLensDirection preferred = CameraLensDirection.front,
    ResolutionPreset resolution = ResolutionPreset.low,
  }) async {
    try {
      await ensureMonitoringWithRetry(preferred: preferred, resolution: resolution, attempts: 3);
      await enableWakelockForMonitoring();

      if (kDebugMode) {
        print('[DetectionService] Continuous monitoring ensured: '
            'streaming=${controller?.value.isStreamingImages}, '
            'fresh_frames=$hasFreshFrames, '
            'wakelock=$_wakelockActive');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[DetectionService] Error in ensureContinuousMonitoring: $e');
      }
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
    // Softened absolute thresholds for eye-open probability (not true EAR).
    const closedThreshold = 0.50;
    const openThreshold = 0.60;

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
  }

  void calibrateReferenceCm(double cm) {
    if (_currentFaceWidth == 0) return;
    _calibrationConstant = cm * _currentFaceWidth;
    unawaited(OfflineDatabaseService.instance.saveCalibrationConstant(_calibrationConstant!));
    MetricsService.instance.setCalibrated(true);
  }

  void calibrateReferenceFromMeasuredWidth(double cm, double measuredFaceWidth) {
    if (measuredFaceWidth <= 0) return;
    _calibrationConstant = cm * measuredFaceWidth;
    _currentFaceWidth = measuredFaceWidth;
    unawaited(OfflineDatabaseService.instance.saveCalibrationConstant(_calibrationConstant!));
    MetricsService.instance.setCalibrated(true);
  }

  Future<InputImage?> _inputImageFromCameraImage(CameraImage image) async {
    final camera = controller!.description;
    final rotation = InputImageRotationValue.fromRawValue(camera.sensorOrientation) ?? InputImageRotation.rotation270deg;
    if (image.format.group == ImageFormatGroup.yuv420) {
      final bytes = await _yuv420ToNv21Async(image);
      return InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: image.width,
        ),
      );
    } else if (image.format.group == ImageFormatGroup.bgra8888) {
      return InputImage.fromBytes(
        bytes: image.planes[0].bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.bgra8888,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );
    }
    return null;
  }

  /// T4: NV21 conversion on a background isolate to keep the UI thread responsive.
  Future<Uint8List> _yuv420ToNv21Async(CameraImage image) {
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];
    final args = <String, dynamic>{
      'width': image.width,
      'height': image.height,
      'y': Uint8List.fromList(yPlane.bytes),
      'u': Uint8List.fromList(uPlane.bytes),
      'v': Uint8List.fromList(vPlane.bytes),
      'yRow': yPlane.bytesPerRow,
      'uRow': uPlane.bytesPerRow,
      'vRow': vPlane.bytesPerRow,
      'uPix': uPlane.bytesPerPixel ?? 1,
      'vPix': vPlane.bytesPerPixel ?? 1,
    };
    return compute(_yuv420ToNv21Isolate, args);
  }

  int _lastRun = 0;
  // T2: base 80ms; under sustained Watch Area load use 120ms to reduce thermal pressure
  static const int _detectIntervalMs = 80;
  static const int _detectIntervalWatchMs = 120;
  bool _isProcessing = false;
  int _lastFrameProcessedAt = 0;
  static const int _freshFrameThresholdMs = 6000;

  int get _effectiveDetectIntervalMs =>
      WatchTrackingSession.instance.active.value ? _detectIntervalWatchMs : _detectIntervalMs;

  int get millisSinceLastFrame {
    if (_lastFrameProcessedAt == 0) return 1 << 30;
    return DateTime.now().millisecondsSinceEpoch - _lastFrameProcessedAt;
  }

  bool get hasReceivedAnyFrame => _lastFrameProcessedAt > 0;

  bool get hasFreshFrames => millisSinceLastFrame < _freshFrameThresholdMs;

  Future<void> _processCameraImage(CameraImage image) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastRun < _effectiveDetectIntervalMs) return;
    if (_isProcessing) return;
    _isProcessing = true;
    _lastRun = now;
    _lastFrameProcessedAt = now;
    try {
      final inputImage = await _inputImageFromCameraImage(image);
      if (inputImage == null) return;
      final faces = await _faceDetector.processImage(inputImage);
      if (faces.isNotEmpty) {
        final face = faces.first;
        _currentFaceWidth = face.boundingBox.width;
        faceDetected.value = true;
        if (face.leftEyeOpenProbability != null || face.rightEyeOpenProbability != null) {
          final scores = <double>[
            if (face.leftEyeOpenProbability != null) face.leftEyeOpenProbability!,
            if (face.rightEyeOpenProbability != null) face.rightEyeOpenProbability!,
          ];
          final score = scores.reduce((a, b) => a < b ? a : b);
          if (detectBlink(currentEAR: score, baselineEAR: 0.52)) {
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
    } catch (e) {
      if (kDebugMode) print('DetectionService error: $e');
    } finally {
      _isProcessing = false;
    }
  }
}
