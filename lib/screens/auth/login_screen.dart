import 'package:flutter/material.dart';

import '../../services/active_child_context_service.dart';
import '../../services/auth_account_service.dart';
import '../../services/auth_session_service.dart';
import '../../services/guardian_setup_service.dart';
import '../../widgets/lumi_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isGuardian = true;
  bool _loading = false;
  String? _error;

  final TextEditingController _guardianEmailController = TextEditingController();
  final TextEditingController _guardianPasswordController = TextEditingController();
  final TextEditingController _childCodeController = TextEditingController();
  final TextEditingController _childPasswordController = TextEditingController();

  @override
  void dispose() {
    _guardianEmailController.dispose();
    _guardianPasswordController.dispose();
    _childCodeController.dispose();
    _childPasswordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_loading) {
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    if (_isGuardian) {
      final email = _guardianEmailController.text.trim();
      final password = _guardianPasswordController.text;
      final success = await AuthAccountService.instance.authenticateGuardian(email: email, password: password);

      if (!mounted) {
        return;
      }

      if (!success) {
        setState(() {
          _loading = false;
          _error = 'Invalid guardian email or password.';
        });
        return;
      }

      await AuthSessionService.instance.saveGuardianSession(guardianEmail: email);
      final hasPin = await GuardianSetupService.instance.hasGuardianPin();
      if (!mounted) {
        return;
      }

      Navigator.of(context).pushNamedAndRemoveUntil(
        hasPin ? '/guardian' : '/guardian-setup',
        (route) => false,
      );
      return;
    }

    final code = _childCodeController.text.trim();
    final password = _childPasswordController.text;
    final child = await AuthAccountService.instance.authenticateChild(loginCode: code, password: password);

    if (!mounted) {
      return;
    }

    if (child == null) {
      setState(() {
        _loading = false;
        _error = 'Invalid child login code or password.';
      });
      return;
    }

    await AuthSessionService.instance.saveChildSession(
      childLoginCode: child.loginCode,
      childId: child.childId,
    );
    await ActiveChildContextService.instance.setActiveChildId(child.childId);

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushNamedAndRemoveUntil('/child', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LumiShell(
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 18)],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Login',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 12),
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment<bool>(value: true, label: Text('Guardian')),
                          ButtonSegment<bool>(value: false, label: Text('Child')),
                        ],
                        selected: {_isGuardian},
                        onSelectionChanged: (value) {
                          setState(() {
                            _isGuardian = value.first;
                            _error = null;
                          });
                        },
                      ),
                      const SizedBox(height: 14),
                      if (_isGuardian) ...[
                        TextField(
                          controller: _guardianEmailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Guardian Email',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _guardianPasswordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ] else ...[
                        TextField(
                          controller: _childCodeController,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: 'Child Login Code',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _childPasswordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Child Password',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          _error!,
                          style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700),
                        ),
                      ],
                      const SizedBox(height: 14),
                      ElevatedButton(
                        onPressed: _loading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7EC48C),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Continue'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
