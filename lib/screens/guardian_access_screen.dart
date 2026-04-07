import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/guardian_auth_service.dart';
import '../services/guardian_setup_service.dart';
import '../widgets/rounded_card.dart';
import 'guardian_control_center_screen.dart';
import 'guardian_setup_screen.dart';

class GuardianAccessScreen extends StatefulWidget {
  const GuardianAccessScreen({super.key});

  @override
  State<GuardianAccessScreen> createState() => _GuardianAccessScreenState();
}

class _GuardianAccessScreenState extends State<GuardianAccessScreen> {
  bool _isAuthenticating = false;
  String? _error;

  void _openControlCenter() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const GuardianControlCenterScreen()),
    );
  }

  Future<void> _authenticateBiometric() async {
    if (_isAuthenticating) {
      return;
    }

    final hasPin = await GuardianSetupService.instance.hasGuardianPin();
    if (!mounted) {
      return;
    }

    if (!hasPin) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const GuardianSetupScreen()),
      );
      return;
    }

    setState(() {
      _isAuthenticating = true;
      _error = null;
    });

    final success = await GuardianAuthService.instance.authenticateWithBiometrics();

    if (!mounted) {
      return;
    }

    setState(() {
      _isAuthenticating = false;
    });

    if (success) {
      _openControlCenter();
      return;
    }

    setState(() {
      _error = 'Biometric authentication failed. Use PIN instead.';
    });
  }

  Future<void> _showPinDialog() async {
    final controller = TextEditingController();
    try {
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          String? error;

          return StatefulBuilder(
            builder: (_, setDialogState) {
              return AlertDialog(
                title: const Text('Guardian PIN'),
                content: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 4,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Enter 4-digit PIN',
                    border: const OutlineInputBorder(),
                    counterText: '',
                    errorText: error,
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () async {
                      final verify = await GuardianSetupService.instance.verifyPinAccess(controller.text.trim());
                      if (!dialogContext.mounted) {
                        return;
                      }

                      if (verify.success) {
                        Navigator.of(dialogContext).pop(true);
                        return;
                      }

                      setDialogState(() {
                        error = verify.message;
                      });
                    },
                    child: const Text('Unlock'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (!mounted) {
        return;
      }

      if (result == true) {
        _openControlCenter();
      }
    } finally {
      controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Guardian Access')),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: RoundedCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Guardian Only', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    const Text(
                      'Authenticate as guardian to manage children, rules, and intervention controls.',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Text(_error!, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700)),
                    ],
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _isAuthenticating ? null : _authenticateBiometric,
                      icon: const Icon(Icons.fingerprint),
                      label: _isAuthenticating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Authenticate with Biometrics'),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _showPinDialog,
                      icon: const Icon(Icons.pin_outlined),
                      label: const Text('Use Guardian PIN'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}