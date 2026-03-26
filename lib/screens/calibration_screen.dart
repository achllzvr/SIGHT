import 'package:flutter/material.dart';
import '../widgets/rounded_card.dart';

class CalibrationScreen extends StatelessWidget {
  const CalibrationScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Calibration')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 24),
              const Text('Calibration', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text(
                'Please position the device at the indicated distance and press Start.',
                style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              RoundedCard(
                borderRadius: 20,
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    const Text('Current Reference: 30 cm', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5)),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7FC86D),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Start Calibration', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? Colors.white54 : Colors.black45, width: 0.8),
                        color: const Color(0xFFEFD9EE),
                      ),
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
                      ),
                    )
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
