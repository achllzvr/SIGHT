import 'package:flutter/material.dart';
import '../widgets/bottom_pill_nav.dart';
import '../services/metrics_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.pink[50],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Column(
                      children: const [
                        Text('0', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('XP', style: TextStyle(fontSize: 10)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.black12, width: 1.0),
                    ),
                    child: const Text('Lumi Dress Up'),
                  )
                ],
              ),
            ),

            // Mascot area
            Expanded(
              child: Center(
                child: SizedBox(
                  width: 260,
                  height: 320,
                  child: CustomPaint(
                    painter: MascotPainter(),
                  ),
                ),
              ),
            ),

            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
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
                      const _MetricChip(label: 'Happy', caption: 'Pet Mood'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Navigation handled by root app; show a small hint instead
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: Colors.grey.withOpacity(0.06), borderRadius: BorderRadius.circular(12)),
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
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Theme.of(context).scaffoldBackgroundColor,
            border: Border.all(color: Colors.black12),
          ),
          child: Center(child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold))),
        ),
        const SizedBox(height: 6),
        Text(caption, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class MascotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 - 20);
    final faceRadius = size.width * 0.35;

    final facePaint = Paint()..color = const Color(0xFFFFE082);
    canvas.drawCircle(center, faceRadius, facePaint);

    final eyePaint = Paint()..color = Colors.black;
    final leftEye = Offset(center.dx - faceRadius * 0.45, center.dy - faceRadius * 0.15);
    final rightEye = Offset(center.dx + faceRadius * 0.45, center.dy - faceRadius * 0.15);
    canvas.drawCircle(leftEye, faceRadius * 0.12, eyePaint);
    canvas.drawCircle(rightEye, faceRadius * 0.12, eyePaint);

    final smilePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = Colors.black87
      ..strokeCap = StrokeCap.round;
    final smileRect = Rect.fromCenter(center: Offset(center.dx, center.dy + faceRadius * 0.15), width: faceRadius * 1.0, height: faceRadius * 0.6);
    canvas.drawArc(smileRect, 0.2 * 3.14, 0.8 * 3.14, false, smilePaint);

    final blushPaint = Paint()..color = Colors.pinkAccent.withOpacity(0.25);
    canvas.drawCircle(Offset(center.dx - faceRadius * 0.6, center.dy + faceRadius * 0.1), faceRadius * 0.2, blushPaint);
    canvas.drawCircle(Offset(center.dx + faceRadius * 0.6, center.dy + faceRadius * 0.1), faceRadius * 0.2, blushPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
