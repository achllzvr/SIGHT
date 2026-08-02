import 'package:flutter/material.dart';

import '../distance_test_screen.dart';
import '../theme/lumi_theme.dart';
import '../widgets/rounded_card.dart';

class CalibrationScreen extends StatelessWidget {
  const CalibrationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Distance Calibration')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(LumiSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: LumiSpacing.md),
              const Text(
                'Flexible Calibration',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: LumiSpacing.md),
              Text(
                'Choose an exact 30 cm measurement or an average arm\'s length preset if measuring is difficult.',
                style: TextStyle(color: isDark ? Colors.white70 : LumiColors.textMuted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: LumiSpacing.lg),
              RoundedCard(
                borderRadius: LumiRadii.xl,
                child: Column(
                  children: [
                    const Text(
                      'Options',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5),
                    ),
                    const SizedBox(height: LumiSpacing.md),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const DistanceTestScreen(initialReferenceCm: 30),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: LumiColors.greenMid,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: LumiSpacing.lg),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(LumiRadii.lg)),
                        ),
                        child: const Text('Calibrate at Exact 30 cm', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(height: LumiSpacing.md),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const DistanceTestScreen(initialReferenceCm: 65),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: LumiSpacing.lg),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(LumiRadii.lg)),
                        ),
                        child: const Text(
                          'Use Average Arm\'s Length (~65 cm)',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(height: LumiSpacing.md),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
