import 'package:flutter/material.dart';
import '../widgets/lumi_shell.dart';
import '../services/auth_session_service.dart';
import '../services/auth_account_service.dart';

class ConnectWithDoctorScreen extends StatefulWidget {
  const ConnectWithDoctorScreen({super.key});

  @override
  State<ConnectWithDoctorScreen> createState() => _ConnectWithDoctorScreenState();
}

class _ConnectWithDoctorScreenState extends State<ConnectWithDoctorScreen> {
  final TextEditingController _doctorNameController = TextEditingController();
  final TextEditingController _clinicCodeController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  
  bool _isVerified = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkVerificationStatus();
  }

  Future<void> _checkVerificationStatus() async {
    final session = await AuthSessionService.instance.loadUserSession();
    if (session != null && session.guardianEmail != null) {
      final account = await AuthAccountService.instance.getGuardianAccount(session.guardianEmail!);
      if (mounted) {
        setState(() {
          _isVerified = account?.isEmailVerified ?? false;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LumiShell(
        child: SafeArea(
          child: _isLoading 
            ? const Center(child: CircularProgressIndicator()) 
            : SingleChildScrollView(
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
                
                if (!_isVerified)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.mark_email_unread_outlined, size: 64, color: Colors.orange),
                        SizedBox(height: 16),
                        Text(
                          'Email Verification Required',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'For privacy and security, you must verify your guardian email address from the Dashboard Account Settings before sharing metrics with a clinician.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16)],
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