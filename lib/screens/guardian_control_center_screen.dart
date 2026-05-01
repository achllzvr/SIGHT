import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/active_child_context_service.dart';
import '../services/auth_account_service.dart';
import '../services/auth_session_service.dart';
import '../services/guardian_preferences_service.dart';
import '../services/guardian_setup_service.dart';
import '../services/rule_engine_service.dart';
import '../widgets/lumi_shell.dart';
import '../widgets/rounded_card.dart';

class GuardianControlCenterScreen extends StatefulWidget {
  const GuardianControlCenterScreen({super.key});

  @override
  State<GuardianControlCenterScreen> createState() => _GuardianControlCenterScreenState();
}

class _GuardianControlCenterScreenState extends State<GuardianControlCenterScreen> {
  GuardianPreferences _preferences = const GuardianPreferences.defaults();
  String? _guardianEmail;
  List<ChildAccount> _childAccounts = const [];
  bool _loading = true;
  bool _saving = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final loaded = await GuardianPreferencesService.instance.loadPreferences();
    final session = await AuthSessionService.instance.loadUserSession();
    await ActiveChildContextService.instance.initialize();
    final activeChildId = await ActiveChildContextService.instance.getActiveChildId();

    GuardianPreferences resolved = loaded.copyWith(
      selectedChildId: activeChildId,
      clearSelectedChildId: activeChildId == null,
    );

    if (activeChildId != null) {
      final remote = await GuardianPreferencesService.instance.pullSessionLimitsFromServer(activeChildId);
      if (remote.success && remote.data != null) {
        resolved = remote.data!;
      }
    }

    final guardianEmail = session?.guardianEmail;
    List<ChildAccount> childAccounts = const [];
    if (guardianEmail != null && guardianEmail.isNotEmpty) {
      childAccounts = await AuthAccountService.instance.listChildrenForGuardian(guardianEmail);
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _preferences = resolved;
      _guardianEmail = guardianEmail;
      _childAccounts = childAccounts;
      _loading = false;
    });
  }

  Future<void> _savePreferences() async {
    if (_saving) {
      return;
    }

    setState(() {
      _saving = true;
      _statusMessage = null;
    });

    await ActiveChildContextService.instance.setActiveChildId(_preferences.selectedChildId);
    await GuardianPreferencesService.instance.savePreferences(_preferences);
    await RuleEngineService.instance.applyGuardianPreferences(_preferences);
    final remoteSync = await GuardianPreferencesService.instance.pushSessionLimitsToServer(_preferences);

    if (!mounted) {
      return;
    }

    setState(() {
      _saving = false;
      _statusMessage = remoteSync.success
          ? 'Guardian settings saved and synced to server.'
          : 'Saved locally. Server sync pending: ${remoteSync.error ?? 'Unknown error'}';
    });
  }

  Future<void> _showChildIdDialog() async {
    final controller = TextEditingController(text: _preferences.selectedChildId?.toString() ?? '');
    try {
      final result = await showDialog<int?>(
        context: context,
        builder: (dialogContext) {
          String? error;
          return StatefulBuilder(
            builder: (_, setDialogState) {
              return AlertDialog(
                title: const Text('Set Active Child ID'),
                content: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'Child ID from server',
                    border: const OutlineInputBorder(),
                    errorText: error,
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(null),
                    child: const Text('Clear'),
                  ),
                  FilledButton(
                    onPressed: () {
                      final raw = controller.text.trim();
                      if (raw.isEmpty) {
                        Navigator.of(dialogContext).pop(null);
                        return;
                      }

                      final parsed = int.tryParse(raw);
                      if (parsed == null || parsed <= 0) {
                        setDialogState(() {
                          error = 'Enter a valid numeric child ID.';
                        });
                        return;
                      }

                      Navigator.of(dialogContext).pop(parsed);
                    },
                    child: const Text('Set'),
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

      setState(() {
        _preferences = _preferences.copyWith(
          selectedChildId: result,
          clearSelectedChildId: result == null,
        );
      });
    } finally {
      controller.dispose();
    }
  }

  Future<void> _showChangePinDialog() async {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          String? error;
          bool inProgress = false;

          return StatefulBuilder(
            builder: (_, setDialogState) {
              return AlertDialog(
                title: const Text('Change Guardian PIN'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: currentController,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      maxLength: 4,
                      decoration: const InputDecoration(
                        labelText: 'Current PIN',
                        border: OutlineInputBorder(),
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: newController,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      maxLength: 4,
                      decoration: const InputDecoration(
                        labelText: 'New PIN',
                        border: OutlineInputBorder(),
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: confirmController,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      maxLength: 4,
                      decoration: InputDecoration(
                        labelText: 'Confirm New PIN',
                        border: const OutlineInputBorder(),
                        counterText: '',
                        errorText: error,
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: inProgress ? null : () => Navigator.of(dialogContext).pop(),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: inProgress
                        ? null
                        : () async {
                            setDialogState(() {
                              inProgress = true;
                              error = null;
                            });

                            final result = await GuardianSetupService.instance.changeGuardianPin(
                              currentPin: currentController.text.trim(),
                              newPin: newController.text.trim(),
                              confirmNewPin: confirmController.text.trim(),
                            );

                            if (!mounted) {
                              return;
                            }

                            if (result.success) {
                              if (!dialogContext.mounted) {
                                return;
                              }
                              Navigator.of(dialogContext).pop();
                              setState(() {
                                _statusMessage = result.message;
                              });
                              return;
                            }

                            setDialogState(() {
                              inProgress = false;
                              error = result.message;
                            });
                          },
                    child: inProgress
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Update PIN'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      currentController.dispose();
      newController.dispose();
      confirmController.dispose();
    }
  }

  Future<void> _showAddChildDialog() async {
    final guardianEmail = _guardianEmail;
    if (guardianEmail == null || guardianEmail.isEmpty) {
      setState(() {
        _statusMessage = 'Cannot create child account without guardian session.';
      });
      return;
    }

    final nameController = TextEditingController();
    final passwordController = TextEditingController();
    final childIdController = TextEditingController();

    try {
      final createdLoginCode = await showDialog<String?>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          String? error;
          bool inProgress = false;

          return StatefulBuilder(
            builder: (_, setDialogState) {
              return AlertDialog(
                title: const Text('Create Child Account'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Child Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Child Password',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: childIdController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: 'Server Child ID (optional)',
                        border: const OutlineInputBorder(),
                        errorText: error,
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: inProgress ? null : () => Navigator.of(dialogContext).pop(),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: inProgress
                        ? null
                        : () async {
                            setDialogState(() {
                              inProgress = true;
                              error = null;
                            });

                            final childIdRaw = childIdController.text.trim();
                            final parsedChildId = childIdRaw.isEmpty ? null : int.tryParse(childIdRaw);
                            if (childIdRaw.isNotEmpty && parsedChildId == null) {
                              setDialogState(() {
                                inProgress = false;
                                error = 'Child ID must be numeric.';
                              });
                              return;
                            }

                            final result = await AuthAccountService.instance.createChildAccount(
                              guardianEmail: guardianEmail,
                              displayName: nameController.text.trim(),
                              password: passwordController.text,
                              childId: parsedChildId,
                            );

                            if (!mounted) {
                              return;
                            }

                            if (!result.success) {
                              setDialogState(() {
                                inProgress = false;
                                error = result.message;
                              });
                              return;
                            }

                            if (!dialogContext.mounted) {
                              return;
                            }

                            FocusManager.instance.primaryFocus?.unfocus();
                            Navigator.of(dialogContext).pop(result.account?.loginCode);
                          },
                    child: inProgress
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Create'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (!mounted || createdLoginCode == null) {
        return;
      }

      final updated = await AuthAccountService.instance.listChildrenForGuardian(guardianEmail);
      if (!mounted) {
        return;
      }

      setState(() {
        _childAccounts = updated;
        _statusMessage = 'Child account created. Login code: ${createdLoginCode.isEmpty ? '-' : createdLoginCode}';
      });
    } finally {
      nameController.dispose();
      passwordController.dispose();
      childIdController.dispose();
    }
  }

  Future<void> _logout() async {
    await AuthSessionService.instance.clearUserSession();
    await AuthSessionService.instance.clearSession();
    if (!mounted) {
      return;
    }

    Navigator.of(context).pushNamedAndRemoveUntil('/auth', (route) => false);
  }

  Future<void> _openAddChildScreen() async {
    await Navigator.of(context).pushNamed('/add-child');
    await _loadPreferences();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: LumiShell(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Guardian Control Center',
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                          ),
                        ),
                        IconButton(
                          onPressed: _logout,
                          icon: const Icon(Icons.logout),
                          tooltip: 'Logout',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  RoundedCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Child Safety Controls', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _preferences.selectedChildId == null
                                    ? 'Active child: Not set'
                                    : 'Active child: #${_preferences.selectedChildId}',
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                            OutlinedButton(
                              onPressed: _showChildIdDialog,
                              child: const Text('Set Child'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _LabeledSlider(
                          label: 'Daily screen time limit',
                          suffix: '${_preferences.dailyScreenLimitMinutes} min',
                          min: 30,
                          max: 360,
                          divisions: 22,
                          value: _preferences.dailyScreenLimitMinutes.toDouble(),
                          onChanged: (value) {
                            setState(() {
                              _preferences = _preferences.copyWith(dailyScreenLimitMinutes: value.round());
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                        _LabeledSlider(
                          label: 'Distance alert threshold',
                          suffix: '${_preferences.distanceAlertThresholdCm.toStringAsFixed(0)} cm',
                          min: 20,
                          max: 45,
                          divisions: 25,
                          value: _preferences.distanceAlertThresholdCm,
                          onChanged: (value) {
                            setState(() {
                              _preferences = _preferences.copyWith(distanceAlertThresholdCm: value);
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                        _LabeledSlider(
                          label: 'Critical lock threshold',
                          suffix: '${_preferences.criticalDistanceThresholdCm.toStringAsFixed(0)} cm',
                          min: 8,
                          max: 25,
                          divisions: 17,
                          value: _preferences.criticalDistanceThresholdCm,
                          onChanged: (value) {
                            setState(() {
                              _preferences = _preferences.copyWith(criticalDistanceThresholdCm: value);
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                        _LabeledSlider(
                          label: 'Blink alert threshold',
                          suffix: '${_preferences.blinkRateAlertThresholdPerMin} /min',
                          min: 4,
                          max: 20,
                          divisions: 16,
                          value: _preferences.blinkRateAlertThresholdPerMin.toDouble(),
                          onChanged: (value) {
                            setState(() {
                              _preferences = _preferences.copyWith(blinkRateAlertThresholdPerMin: value.round());
                            });
                          },
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: _preferences.monitoringMode,
                          decoration: const InputDecoration(
                            labelText: 'Monitoring mode',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'Relaxed', child: Text('Relaxed')),
                            DropdownMenuItem(value: 'Moderate', child: Text('Moderate')),
                            DropdownMenuItem(value: 'Strict', child: Text('Strict')),
                          ],
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }
                            setState(() {
                              _preferences = _preferences.copyWith(monitoringMode: value);
                            });
                          },
                        ),
                        const SizedBox(height: 6),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Rule enforcement active'),
                          value: _preferences.isActive,
                          onChanged: (value) {
                            setState(() {
                              _preferences = _preferences.copyWith(isActive: value);
                            });
                          },
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Auto-enforce eye breaks'),
                          value: _preferences.autoEnforceBreaks,
                          onChanged: (value) {
                            setState(() {
                              _preferences = _preferences.copyWith(autoEnforceBreaks: value);
                            });
                          },
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Weekend relaxed mode'),
                          value: _preferences.weekendRelaxedMode,
                          onChanged: (value) {
                            setState(() {
                              _preferences = _preferences.copyWith(weekendRelaxedMode: value);
                            });
                          },
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Parent notifications'),
                          value: _preferences.parentNotificationsEnabled,
                          onChanged: (value) {
                            setState(() {
                              _preferences = _preferences.copyWith(parentNotificationsEnabled: value);
                            });
                          },
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _saving ? null : _savePreferences,
                            child: _saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text('Save Safety Settings'),
                          ),
                        ),
                        if (_statusMessage != null) ...[
                          const SizedBox(height: 8),
                          Text(_statusMessage!, style: const TextStyle(fontWeight: FontWeight.w700)),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  RoundedCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text('Child Accounts', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                            ),
                            OutlinedButton.icon(
                              onPressed: _showAddChildDialog,
                              icon: const Icon(Icons.person_add_alt_1),
                              label: const Text('Add Child'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _openAddChildScreen,
                              icon: const Icon(Icons.group_add_outlined),
                              label: const Text('Open Add Child Screen'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => Navigator.of(context).pushNamed('/child-dashboard'),
                              icon: const Icon(Icons.dashboard_outlined),
                              label: const Text('Child Dashboard'),
                            ),
                            
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_childAccounts.isEmpty)
                          const Text(
                            'No child accounts yet. Create one so children can login using code + password.',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          )
                        else
                          ..._childAccounts.map(
                            (account) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? Colors.white10
                                      : Colors.black.withOpacity(0.04),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(account.displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
                                          Text(
                                            account.childId == null ? 'No server child ID' : 'Child ID: ${account.childId}',
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEAF4E3),
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      child: Text('Code: ${account.loginCode}'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  RoundedCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Guardian Security', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 10),
                        const Text(
                          'Update your guardian PIN used for strict lock override and guardian access.',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _showChangePinDialog,
                            icon: const Icon(Icons.password),
                            label: const Text('Change Guardian PIN'),
                          ),
                        ),
                      ],
                    ),
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

class _LabeledSlider extends StatelessWidget {
  final String label;
  final String suffix;
  final double min;
  final double max;
  final int divisions;
  final double value;
  final ValueChanged<double> onChanged;

  const _LabeledSlider({
    required this.label,
    required this.suffix,
    required this.min,
    required this.max,
    required this.divisions,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))),
            Text(suffix, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    );
  }
}