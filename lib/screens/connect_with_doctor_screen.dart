import 'package:flutter/material.dart';

import '../widgets/lumi_shell.dart';

class ConnectWithDoctorScreen extends StatefulWidget {
  const ConnectWithDoctorScreen({super.key});

  @override
  State<ConnectWithDoctorScreen> createState() => _ConnectWithDoctorScreenState();
}

class _ConnectWithDoctorScreenState extends State<ConnectWithDoctorScreen> {
  final TextEditingController _doctorNameController = TextEditingController();
  final TextEditingController _clinicCodeController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  @override
  void dispose() {
    _doctorNameController.dispose();
    _clinicCodeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submitRequest() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Connection request sent. You will be notified once approved.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LumiShell(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_ios),
                    ),
                    const Expanded(
                      child: Text(
                        'Connect With Doctor',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 40),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 16)],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Share reports with your eye-care provider for follow-up guidance.',
                        style: TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _doctorNameController,
                        decoration: const InputDecoration(
                          labelText: 'Doctor Name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _clinicCodeController,
                        decoration: const InputDecoration(
                          labelText: 'Clinic Code',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _notesController,
                        minLines: 3,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Optional Notes',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _submitRequest,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7EC48C),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Send Request'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
