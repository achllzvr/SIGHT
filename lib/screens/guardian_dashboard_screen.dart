import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/active_child_context_service.dart';
import '../services/auth_account_service.dart';
import '../services/auth_session_service.dart';
import '../services/cleanup_service.dart';
import '../services/guardian_setup_service.dart'; 
import 'guardian_child_dashboard_screen.dart';
import '../widgets/rounded_card.dart';

/// Model for child with basic info and login code
class ChildInfo {
  final int childId;
  final String displayName;
  final int ageYears;
  final String loginCode;
  final DateTime? birthdate;

  ChildInfo({
    required this.childId,
    required this.displayName,
    required this.ageYears,
    required this.loginCode,
    this.birthdate,
  });
}

class GuardianDashboardScreen extends StatefulWidget {
  const GuardianDashboardScreen({super.key});

  @override
  State<GuardianDashboardScreen> createState() => _GuardianDashboardScreenState();
}

class _GuardianDashboardScreenState extends State<GuardianDashboardScreen> {
  List<ChildInfo> _children = [];
  int? _selectedChildId;
  bool _loading = true;
  String? _guardianEmail;

  @override
  void initState() {
    super.initState();
    _loadChildren();
  }

  Future<void> _loadChildren() async {
    try {
      final session = await AuthSessionService.instance.loadUserSession();
      _guardianEmail = session?.guardianEmail;

      if (_guardianEmail != null) {
        final childAccounts = await AuthAccountService.instance.listChildrenForGuardian(_guardianEmail!);

        final children = childAccounts.map((child) {
          int age = 0;
          if (child.birthdate != null) {
            age = _calculateAge(child.birthdate!);
          }
          
          return ChildInfo(
            childId: child.childId ?? 0,
            displayName: child.displayName,
            ageYears: age,
            loginCode: child.loginCode,
            birthdate: child.birthdate,
          );
        }).toList();

        await ActiveChildContextService.instance.initialize();
        final activeChildId = await ActiveChildContextService.instance.getActiveChildId();

        if (mounted) {
          setState(() {
            _children = children;
            _selectedChildId = activeChildId ?? (children.isNotEmpty ? children[0].childId : null);
            _loading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() => _loading = false);
        }
      }
    } catch (e) {
      debugPrint('Error loading children: $e');
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  int _calculateAge(DateTime birthDate) {
    final today = DateTime.now();
    int age = today.year - birthDate.year;
    if (today.month < birthDate.month || (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  void _selectChild(int childId) {
    setState(() => _selectedChildId = childId);
    ActiveChildContextService.instance.setActiveChildId(childId);
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GuardianChildDashboardScreen(childId: childId),
      ),
    );
  }

  Future<void> _addChild() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const AddChildModal(),
    );

    if (result == true) {
      _loadChildren();
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

                            if (!mounted) return;

                            if (result.success) {
                              if (!dialogContext.mounted) return;
                              Navigator.of(dialogContext).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(result.message)),
                              );
                              return;
                            }

                            setDialogState(() {
                              inProgress = false;
                              error = result.message;
                            });
                          },
                    child: inProgress
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
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

  // IMPROVEMENT #2: Parent Account Password Reset
  Future<void> _showParentChangePasswordDialog() async {
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
                title: const Text('Change Account Password'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: currentController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Current Password',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: newController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'New Password',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: confirmController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Confirm New Password',
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

                            if (newController.text != confirmController.text) {
                              setDialogState(() {
                                inProgress = false;
                                error = 'New passwords do not match.';
                              });
                              return;
                            }

                            // 1. Verify current password
                            final isValid = await AuthAccountService.instance.authenticateGuardian(
                              email: _guardianEmail!, 
                              password: currentController.text
                            );

                            if (!isValid) {
                              setDialogState(() {
                                inProgress = false;
                                error = 'Current password is incorrect.';
                              });
                              return;
                            }

                            // 2. TODO: Implement actual database password change here in the future
                            await Future.delayed(const Duration(milliseconds: 800)); // Simulate network

                            if (!dialogContext.mounted) return;
                            Navigator.of(dialogContext).pop();
                            // ignore: use_build_context_synchronously
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Parent password updated successfully. (TODO: Link to Backend)')),
                            );
                          },
                    child: inProgress
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Update Password'),
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

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout? All tracking will stop.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await CleanupService.instance.performCompleteCleanup();
        await AuthSessionService.instance.clearUserSession();
        await ActiveChildContextService.instance.clearActiveChild();

        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/welcome', (route) => false);
        }
      } catch (e) {
        debugPrint('Error during logout: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Logout error: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_loading) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F0F11) : const Color(0xFFFAFAFC),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F11) : const Color(0xFFFAFAFC),
      appBar: AppBar(
        title: const Text('Parent Dashboard'),
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF5F5F7),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Select Child Section
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Select Child',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: _addChild,
                        icon: const Icon(Icons.add, size: 20),
                        label: const Text('Add Child'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFD5C2E8),
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (_children.isEmpty)
                    Center(
                      child: Text(
                        'Add a child to get started',
                        style: TextStyle(
                          fontSize: 16,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _children.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final child = _children[index];
                        final isSelected = child.childId == _selectedChildId;

                        return GestureDetector(
                          onTap: () => _selectChild(child.childId),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFFD5C2E8).withValues(alpha: 0.3)
                                  : (isDark ? const Color(0xFF2A2A2C) : const Color(0xFFF9F9FB)),
                            borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFFD5C2E8)
                                    : (isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.05)),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFD5C2E8),
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: const Icon(
                                    Icons.pets,
                                    size: 28,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        child.displayName,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? Colors.white : Colors.black87,
                                        ),
                                      ),
                                      Text(
                                        '${child.ageYears} years old',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: isDark ? Colors.white60 : Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(
                                    Icons.check_circle,
                                    color: Color(0xFFD5C2E8),
                                    size: 24,
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // Guardian Security Card
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
                      icon: const Icon(Icons.pin),
                      label: const Text('Change Guardian PIN'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // IMPROVEMENT #2: Parent Account Management
            RoundedCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Parent Account Management', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.email_outlined, size: 20, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _guardianEmail ?? 'Loading...',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Verification email sent to your inbox. (TODO)')),
                        );
                      },
                      icon: const Icon(Icons.mark_email_read_outlined),
                      label: const Text('Verify Email Address'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _showParentChangePasswordDialog,
                      icon: const Icon(Icons.password),
                      label: const Text('Reset Parent Password'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class AddChildModal extends StatefulWidget {
  const AddChildModal({super.key});

  @override
  State<AddChildModal> createState() => _AddChildModalState();
}

class _AddChildModalState extends State<AddChildModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _birthdateController = TextEditingController();
  final _passwordController = TextEditingController();
  final _childIdController = TextEditingController(); 
  DateTime? _selectedBirthdate;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _birthdateController.dispose();
    _passwordController.dispose();
    _childIdController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    
    try {
      final session = await AuthSessionService.instance.loadUserSession();
      final guardianEmail = session?.guardianEmail ?? '';

      final childIdRaw = _childIdController.text.trim();
      final parsedChildId = childIdRaw.isEmpty ? null : int.tryParse(childIdRaw);
      
      if (childIdRaw.isNotEmpty && parsedChildId == null) {
        setState(() => _isLoading = false);
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Server Child ID must be numeric.')));
        return;
      }

      final result = await AuthAccountService.instance.createChildAccount(
        guardianEmail: guardianEmail,
        displayName: _nameController.text.trim(),
        password: _passwordController.text,
        childId: parsedChildId, 
      );

      if (mounted) {
        setState(() => _isLoading = false);
        if (result.success) {
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Account Created!'),
              content: Text('Login Code: ${result.account?.loginCode}'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pop(true); 
                  },
                  child: const Text('Done'),
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.message)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Add Child',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(
                    Icons.close,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      hintText: 'Name',
                      filled: true,
                      fillColor: isDark ? const Color(0xFF2A2A2C) : const Color(0xFFF5F5F7),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Name is required';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _birthdateController,
                    readOnly: true,
                    onTap: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: _selectedBirthdate ?? DateTime.now().subtract(const Duration(days: 365 * 10)),
                        firstDate: DateTime(1990),
                        lastDate: DateTime.now(),
                      );
                      if (pickedDate != null) {
                        setState(() {
                          _selectedBirthdate = pickedDate;
                          _birthdateController.text = '${pickedDate.day}/${pickedDate.month}/${pickedDate.year}';
                        });
                      }
                    },
                    decoration: InputDecoration(
                      hintText: 'Birthdate (DD/MM/YYYY)',
                      filled: true,
                      fillColor: isDark ? const Color(0xFF2A2A2C) : const Color(0xFFF5F5F7),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      suffixIcon: const Icon(Icons.calendar_today),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Birthdate is required';
                      if (_selectedBirthdate == null) return 'Please select a valid birthdate';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: 'Password',
                      filled: true,
                      fillColor: isDark ? const Color(0xFF2A2A2C) : const Color(0xFFF5F5F7),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Password is required';
                      if (value.length < 6) return 'Password must be at least 6 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _childIdController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      hintText: 'Server Child ID (Optional)',
                      filled: true,
                      fillColor: isDark ? const Color(0xFF2A2A2C) : const Color(0xFFF5F5F7),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: _isLoading ? null : _submitForm,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFD5C2E8),
                        foregroundColor: Colors.black87,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        disabledBackgroundColor: const Color(0xFFD5C2E8).withValues(alpha: 0.5),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator()
                          : const Text(
                              'Save Child',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}