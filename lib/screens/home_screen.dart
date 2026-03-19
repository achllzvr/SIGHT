import 'package:flutter/material.dart';
import '../widgets/stat_card.dart';
import '../widgets/bottom_pill_nav.dart';
import '../services/metrics_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const LinearGradient(
        colors: [Color(0xFFF7FFF7), Color(0xFFEFFAF0)],
      ).createShader(const Rect.fromLTWH(0, 0, 400, 800)) == null
          ? Colors.white
          : null,
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
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.black87, width: 1.2),
                    ),
                    child: const Text('Lumi Dress Up'),
                  )
                ],
              ),
            ),
            const Expanded(
              child: Center(
                child: Text('Mascot Placeholder', style: TextStyle(fontSize: 24)),
              ),
            ),
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                        builder: (_, value, __) => _MetricChip(label: value > 0 ? '${value.toStringAsFixed(1)}cm' : '--', caption: 'Distance'),
                      ),
                      const _MetricChip(label: 'Happy', caption: 'Pet Mood'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const BottomPillNav(),
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
            color: Colors.white,
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
