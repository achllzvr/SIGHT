import 'package:flutter/material.dart';
import '../widgets/rounded_card.dart';

class CalibrationScreen extends StatelessWidget {
  const CalibrationScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Calibration')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              const Text('Calibration', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              const Text('Please position the device at the indicated distance and press Start.'),
              const SizedBox(height: 20),
              RoundedCard(
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    const Text('Current Reference: 30 cm', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    ElevatedButton(onPressed: () {}, child: const Text('Start Calibration')),
                    const SizedBox(height: 8),
                    TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel'))
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
