import 'package:flutter/material.dart';

import '../services/gamification_service.dart';
import '../services/metrics_service.dart';
import '../services/offline_models.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const _TopBadge(),
                  const _TopPill(label: 'Lumi Dress Up'),
                ],
              ),
            ),

            // Mascot area
            Expanded(
              child: Center(
                child: SizedBox(
                  width: 270,
                  height: 340,
                  child: ValueListenableBuilder<int>(
                    valueListenable: MetricsService.instance.blinkRatePerMinNotifier,
                    builder: (_, blinkRate, __) {
                      return ValueListenableBuilder<double>(
                        valueListenable: MetricsService.instance.distanceCmNotifier,
                        builder: (_, distance, __) {
                          return ValueListenableBuilder<bool>(
                            valueListenable: MetricsService.instance.faceDetectedNotifier,
                            builder: (_, faceDetected, __) {
                              final mascotPath = _resolveMascotAsset(
                                blinkRate: blinkRate,
                                distance: distance,
                                faceDetected: faceDetected,
                              );
                              return Image.asset(mascotPath, fit: BoxFit.contain);
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ),

            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('^', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
            ),

            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF5F5F7),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: isDark ? Colors.white54 : Colors.black26, width: 1),
                boxShadow: const [
                  BoxShadow(color: Color(0xFFB9E3A4), offset: Offset(0, -2), blurRadius: 0),
                  BoxShadow(color: Color(0xFFD5C2E8), offset: Offset(0, -1), blurRadius: 0),
                ],
              ),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ValueListenableBuilder<int>(
                        valueListenable: MetricsService.instance.blinkRatePerMinNotifier,
                        builder: (_, value, __) => _MetricChip(label: '${value}/min', caption: 'Blink Rate'),
                      ),
                      ValueListenableBuilder<double>(
                        valueListenable: MetricsService.instance.distanceCmNotifier,
                        builder: (_, value, __) => _MetricChip(label: value > 0 ? '${value.toStringAsFixed(1)} cm' : '--', caption: 'Distance'),
                      ),
                      ValueListenableBuilder<PetMood>(
                        valueListenable: GamificationService.instance.petMoodNotifier,
                        builder: (_, mood, __) => _MetricChip(label: _petMoodLabel(mood), caption: 'Pet Mood'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.grey.withOpacity(0.08),
                      border: Border.all(color: isDark ? Colors.white24 : Colors.black12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('Use the bottom navigation to go to Tracker or Tasks', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String caption;
  const _MetricChip({Key? key, required this.label, required this.caption}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFFDFDFD),
            border: Border.all(color: isDark ? Colors.white70 : Colors.black87, width: 1),
            boxShadow: const [
              BoxShadow(color: Color(0xFFB9E3A4), offset: Offset(2, 2), blurRadius: 0),
              BoxShadow(color: Color(0xFFD5C2E8), offset: Offset(1, 1), blurRadius: 0),
            ],
          ),
          child: Center(child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold))),
        ),
        const SizedBox(height: 5),
        Text(caption, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _TopBadge extends StatelessWidget {
  const _TopBadge();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: 66,
      height: 46,
      child: ValueListenableBuilder<int>(
        valueListenable: GamificationService.instance.sessionXpNotifier,
        builder: (_, xp, __) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFEFD9EE),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: isDark ? Colors.white70 : Colors.black87, width: 1),
              boxShadow: const [
                BoxShadow(color: Color(0xFFD5C2E8), offset: Offset(2, 2), blurRadius: 0),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('$xp', style: const TextStyle(fontWeight: FontWeight.bold, height: 1)),
                const SizedBox(height: 2),
                const Text('XP', style: TextStyle(fontSize: 9.5, height: 1)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TopPill extends StatelessWidget {
  final String label;
  const _TopPill({required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: const BoxConstraints(minWidth: 126),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white70 : Colors.black87, width: 1),
        boxShadow: const [
          BoxShadow(color: Color(0xFFB9E3A4), offset: Offset(2, 2), blurRadius: 0),
          BoxShadow(color: Color(0xFFD5C2E8), offset: Offset(1, 1), blurRadius: 0),
        ],
      ),
      child: Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
    );
  }
}

String _resolveMascotAsset({
  required int blinkRate,
  required double distance,
  required bool faceDetected,
}) {
  if (!faceDetected || distance <= 0) {
    return 'assets/mascot/mascot_head_v1.png';
  }

  final isGreat = distance >= 30.0 && blinkRate >= 12;
  final isGood = distance >= 25.0 && blinkRate >= 8;

  if (isGreat) {
    return blinkRate.isEven ? 'assets/mascot/mascot_great_v1.png' : 'assets/mascot/mascot_good_v2.png';
  }

  if (isGood) {
    return blinkRate.isEven ? 'assets/mascot/mascot_good_v1.png' : 'assets/mascot/mascot_good_v2.png';
  }

  return blinkRate.isEven ? 'assets/mascot/mascot_bad_v1.png' : 'assets/mascot/mascot_bad_v2.png';
}

String _petMoodLabel(PetMood mood) {
  switch (mood) {
    case PetMood.happy:
      return 'Happy';
    case PetMood.sad:
      return 'Sad';
    case PetMood.sleeping:
      return 'Sleep';
  }
}
