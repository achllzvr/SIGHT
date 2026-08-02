import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'services/detection_service.dart';
import 'services/metrics_service.dart';
import 'theme/lumi_theme.dart';
import 'widgets/rounded_card.dart';

class DistanceTestScreen extends StatefulWidget {
  final double initialReferenceCm;

  const DistanceTestScreen({super.key, this.initialReferenceCm = 30});

  @override
  State<DistanceTestScreen> createState() => _DistanceTestScreenState();
}

class _DistanceTestScreenState extends State<DistanceTestScreen> {
  late double _referenceCm;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _referenceCm = widget.initialReferenceCm;
    unawaited(_startCamera());
  }

  Future<void> _startCamera() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final permission = await Permission.camera.status;
    if (!permission.isGranted) {
      final requested = await Permission.camera.request();
      if (!requested.isGranted) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'Camera is off. Turn it on in Settings so LUMI can set distance.';
        });
        return;
      }
    }

    try {
      await DetectionService.instance.acquireMonitoring(resolution: ResolutionPreset.medium);
      // Give the controller a moment if still initializing
      for (var i = 0; i < 10; i++) {
        final c = DetectionService.instance.controller;
        if (c != null && c.value.isInitialized) break;
        await Future.delayed(const Duration(milliseconds: 200));
      }
      final c = DetectionService.instance.controller;
      if (!mounted) return;
      if (c == null || !c.value.isInitialized) {
        setState(() {
          _loading = false;
          _error = 'Could not start the camera. Try again.';
        });
        return;
      }
      setState(() {
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Camera error. Try again.';
      });
    }
  }

  @override
  void dispose() {
    unawaited(DetectionService.instance.releaseMonitoring());
    super.dispose();
  }

  void _calibrate([double? cm]) {
    final target = cm ?? _referenceCm;
    DetectionService.instance.calibrateReferenceCm(target);
    final calibrated = MetricsService.instance.calibratedNotifier.value;
    if (calibrated) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Distance set at ${target.toStringAsFixed(0)} cm.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No face found. Keep your face in the box and try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: LumiColors.scaffoldLight,
        body: Center(child: CircularProgressIndicator(color: LumiColors.greenMid)),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: LumiColors.scaffoldLight,
        appBar: AppBar(
          title: const Text('Phone Distance'),
          backgroundColor: Colors.transparent,
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: RoundedCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(_error!, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: _startCamera, child: const Text('Try again')),
                TextButton(onPressed: openAppSettings, child: const Text('Open Settings')),
              ],
            ),
          ),
        ),
      );
    }

    final controller = DetectionService.instance.controller!;
    final size = MediaQuery.of(context).size;
    var scale = size.aspectRatio * controller.value.aspectRatio;
    if (scale < 1) scale = 1 / scale;

    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Phone Distance', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Transform.scale(scale: scale, child: Center(child: CameraPreview(controller))),
          IgnorePointer(
            child: Center(
              child: Container(
                width: size.width * 0.55,
                height: size.width * 0.7,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white70, width: 2),
                ),
              ),
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: DetectionService.instance.faceDetected,
            builder: (_, detected, __) {
              if (!detected) {
                return Container(
                  color: Colors.red.withValues(alpha: 0.35),
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.white, size: 80),
                      SizedBox(height: 20),
                      Text(
                        'No face found. Keep your face in the box.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: RoundedCard(
              borderRadius: 22,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              backgroundColor: const Color(0xFF1F1F22),
              borderColor: Colors.white70,
              child: ValueListenableBuilder<bool>(
                valueListenable: MetricsService.instance.calibratedNotifier,
                builder: (_, calibrated, __) {
                  return ValueListenableBuilder<double>(
                    valueListenable: DetectionService.instance.distanceCm,
                    builder: (_, distance, __) {
                      if (!calibrated || distance <= 0) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Distance Setup', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                            const SizedBox(height: 8),
                            Text(
                              'Hold the phone about ${_referenceCm.toStringAsFixed(0)} cm from your face and put it in the box.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 14, color: Colors.white70),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => setState(() => _referenceCm = 30),
                                    style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                                    child: const Text('30 cm'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => setState(() => _referenceCm = 65),
                                    style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                                    child: const Text('Arm\'s length'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () => _calibrate(_referenceCm),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF7FC86D),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 13),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                child: Text(
                                  'Save ${_referenceCm.toStringAsFixed(0)} cm',
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        );
                      }

                      final safe = distance >= 30.0;
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Distance', style: TextStyle(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.w500)),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${distance.toStringAsFixed(1)} cm',
                                    style: TextStyle(
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold,
                                      color: safe ? const Color(0xFF9DE18A) : const Color(0xFFE9C37F),
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: safe ? const Color(0xFFEAF4E3) : const Color(0xFFEFD9EE),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white70, width: 0.8),
                                ),
                                child: Text(
                                  safe ? 'SAFE' : 'CLOSE',
                                  style: TextStyle(
                                    color: safe ? const Color(0xFF4A8D3B) : const Color(0xFF8F5A88),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            ],
                          ),
                          TextButton(
                            onPressed: _calibrate,
                            child: const Text('Set again', style: TextStyle(fontSize: 12.5, color: Color(0xFFA68AC0))),
                          )
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
