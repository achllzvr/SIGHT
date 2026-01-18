import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

// Import your screens
import 'distance_test_screen.dart';
import 'blink_test_screen.dart';
import 'screening_test_screen.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    cameras = await availableCameras();
  } catch (e) {
    debugPrint("Error fetching cameras: $e");
  }
  runApp(const SightFeasibilityApp());
}

class SightFeasibilityApp extends StatelessWidget {
  const SightFeasibilityApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SIGHT Feasibility Lab',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const LabHubScreen(),
    );
  }
}

class LabHubScreen extends StatelessWidget {
  const LabHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SIGHT Feasibility Hub'),
        centerTitle: true,
        backgroundColor: Colors.teal.shade100,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Hardware Capability Test\nSamsung Galaxy A26',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black54),
            ),
            const SizedBox(height: 30),

            // MODULE A
            _buildModuleCard(
              context,
              title: 'Module A: Distance Monitor',
              subtitle: 'Test "Triangle Similarity" distance estimation.',
              icon: Icons.face,
              color: Colors.blue.shade100,
              onTap: () async {
                await _navigateToModule(context, const DistanceTestScreen());
              },
            ),
            
            const SizedBox(height: 15),

            // MODULE B
            _buildModuleCard(
              context,
              title: 'Module B: Blink Counter',
              subtitle: 'Test "Eye Aspect Ratio" blink detection.',
              icon: Icons.visibility,
              color: Colors.green.shade100,
              onTap: () async {
                await _navigateToModule(context, const BlinkTestScreen());
              },
            ),

            // MODULE C
            _buildModuleCard(
              context,
              title: 'Module C: AI Screening',
              subtitle: 'Test TFLite Pipeline (Static Image).',
              icon: Icons.health_and_safety,
              color: Colors.orange.shade100,
              onTap: () {
                 Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ScreeningTestScreen()),
                );
              },
            ),

          ],
        ),
      ),
    );
  }

  Future<void> _navigateToModule(BuildContext context, Widget screen) async {
    var status = await Permission.camera.request();
    if (status.isGranted) {
      if (context.mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Camera permission required!')),
        );
      }
    }
  }

  Widget _buildModuleCard(BuildContext context,
      {required String title, required String subtitle, required IconData icon, required Color color, required VoidCallback onTap}) {
    return Card(
      elevation: 4,
      color: color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        leading: Icon(icon, size: 32, color: Colors.black87),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}