import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/critical_overlay_service.dart';
import '../services/guardian_auth_service.dart';

class GuardianOverrideScreen extends StatefulWidget {
  const GuardianOverrideScreen({super.key});

  @override
  State<GuardianOverrideScreen> createState() => _GuardianOverrideScreenState();
}

class _GuardianOverrideScreenState extends State<GuardianOverrideScreen> {
  bool _isAuthenticating = false;
  bool _overlayPermissionGranted = true;

  @override
  void initState() {
    super.initState();
    _refreshOverlayPermissionStatus();
  }

  Future<void> _refreshOverlayPermissionStatus() async {
    final hasPermission = await CriticalOverlayService.instance.hasPermission();
    if (!mounted) {
      return;
    }

    setState(() {
      _overlayPermissionGranted = hasPermission;
    });
  }

  Future<void> _authenticateWithBiometrics() async {
    if (_isAuthenticating) {
      return;
    }

    setState(() {
      _isAuthenticating = true;
    });

    final bool unlocked = await GuardianAuthService.instance.authenticateWithBiometrics();

    if (!mounted) {
      return;
    }

    setState(() {
      _isAuthenticating = false;
    });

    if (unlocked) {
      await CriticalOverlayService.instance.hideCriticalOverlay();
      Navigator.of(context).pop();
    }
  }

  Future<void> _showPinDialog() async {
    final controller = TextEditingController();

    try {
      final bool? unlocked = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          String? errorText;

          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              return AlertDialog(
                title: const Text('Enter Guardian PIN'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Enter the 4-digit guardian PIN to unlock SIGHT.'),
                    const SizedBox(height: 16),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      maxLength: 4,
                      obscureText: true,
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        counterText: '',
                        border: const OutlineInputBorder(),
                        errorText: errorText,
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () async {
                      final storedPin = await GuardianAuthService.instance.loadFallbackPin();
                      final enteredPin = controller.text.trim();

                      if (storedPin != null && GuardianAuthService.instance.verifyFallbackPin(enteredPin, storedPin)) {
                        Navigator.of(dialogContext).pop(true);
                        return;
                      }

                      setDialogState(() {
                        errorText = 'Invalid guardian PIN.';
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

      if (unlocked == true) {
        await CriticalOverlayService.instance.hideCriticalOverlay();
        Navigator.of(context).pop();
      }
    } finally {
      controller.dispose();
    }
  }

  Future<void> _openOverlaySettings() async {
    await CriticalOverlayService.instance.openOverlaySettings();
    await _refreshOverlayPermissionStatus();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.red.withOpacity(0.95),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock, size: 96, color: Colors.white),
                  const SizedBox(height: 24),
                  const Text(
                    'Critical Limit Reached. Device Locked.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'A guardian must unlock SIGHT to continue.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isAuthenticating ? null : _authenticateWithBiometrics,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.red.shade900,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isAuthenticating
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(
                              'Guardian Unlock',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _showPinDialog,
                    style: TextButton.styleFrom(foregroundColor: Colors.white),
                    child: const Text(
                      'Use PIN',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (!_overlayPermissionGranted)
                    TextButton(
                      onPressed: _openOverlaySettings,
                      style: TextButton.styleFrom(foregroundColor: Colors.white),
                      child: const Text(
                        'Enable Overlay Permission',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}