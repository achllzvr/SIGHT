import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/active_child_context_service.dart';
import '../services/auth_account_service.dart';
import '../services/auth_session_service.dart';
import '../services/cleanup_service.dart';
import 'guardian_child_dashboard_screen.dart';
import 'doctor_connection_modal.dart';

import '../services/guardian_setup_service.dart';
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
        
        // Let the parent know they need internet!
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(e.toString().replaceAll('Exception: ', '')),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        });
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
    
    final messenger = ScaffoldMessenger.of(context); 
    
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();

    try {
      final successMsg = await showDialog<String>(
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

                            if (!dialogContext.mounted) return;

                            if (result.success) {
                              Navigator.of(dialogContext).pop(result.message); // Pass message out
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

      // Show SnackBar safely outside the dialog lifecycle using the pre-captured messenger
      if (successMsg != null) {
        messenger.showSnackBar(SnackBar(content: Text(successMsg)));
      }
    } finally {
      // WAIT FOR EXIT ANIMATION BEFORE DISPOSING
      Future.delayed(const Duration(milliseconds: 400), () {
        currentController.dispose();
        newController.dispose();
        confirmController.dispose();
      });
    }
  }

  // IMPROVEMENT #2: Parent Account Password Reset (Crash Fixed)
  Future<void> _showParentChangePasswordDialog() async {
    // CAPTURE MESSENGER EARLY TO PREVENT CONTEXT CRASHES
    final messenger = ScaffoldMessenger.of(context); 

    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();

    try {
      final successMsg = await showDialog<String>(
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

                            final result = await AuthAccountService.instance.resetParentPassword(
                              _guardianEmail!,
                              currentController.text,
                              newController.text,
                            );

                            if (!dialogContext.mounted) return;

                            if (result.success) {
                               Navigator.of(dialogContext).pop(result.message); // Pass message out
                            } else {
                               setDialogState(() {
                                inProgress = false;
                                error = result.message;
                              });
                            }
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

      // Show SnackBar safely outside the dialog lifecycle using the pre-captured messenger
      if (successMsg != null) {
        messenger.showSnackBar(SnackBar(content: Text(successMsg)));
      }

    } finally {
      // WAIT FOR EXIT ANIMATION BEFORE DISPOSING
      Future.delayed(const Duration(milliseconds: 400), () {
        currentController.dispose();
        newController.dispose();
        confirmController.dispose();
      });
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

    final backgroundGradient = BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? [const Color.fromARGB(255, 208, 174, 245), const Color.fromARGB(255, 163, 138, 214)]
            : [const Color.fromARGB(255, 208, 174, 245), const Color.fromARGB(255, 163, 138, 214)],
      ),
    );

    if (_loading) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F0F11) : const Color(0xFFFAFAFC),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Container(
      decoration: backgroundGradient,
      child: Scaffold(
          backgroundColor: Colors.transparent,        appBar: AppBar(
          title: const Text('Parent Dashboard'),
          elevation: 0,
          backgroundColor: Colors.transparent,
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
                            backgroundColor: const Color(0xFF00ACC1),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), // Sharper corners
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
                                    ? const Color(0xFF00ACC1).withValues(alpha: 0.1) // Subtle cyan tint
                                    : (isDark ? const Color(0xFF2A2A2C) : const Color(0xFFF9F9FB)),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF00ACC1) // Cyan border
                                      : (isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.05)),
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              child: Row(
                                children: [
                                  Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF00ACC1), // Cyan Avatar
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.face, size: 28, color: Colors.white), // Face icon
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
                        onPressed: () async {
                          final res = await AuthAccountService.instance.verifyEmail(_guardianEmail!);
                          if (context.mounted) {
                             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.message)));
                          }
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
              const SizedBox(height: 20),
              // Parent-Clinician Link Placeholder
              RoundedCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Clinician Access', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    const Text(
                      'Search for certified eye-care professionals to safely share your child\'s health metrics.',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () {
                           // Ensure we have a child selected before opening the modal
                           if (_selectedChildId == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please select a child first.')),
                              );
                              return;
                           }
                           showModalBottomSheet(
                             context: context,
                             isScrollControlled: true,
                             backgroundColor: Colors.transparent,
                             builder: (context) => Container(
                               height: MediaQuery.of(context).size.height * 0.85,
                               decoration: BoxDecoration(
                                 color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                                 borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                               ),
                               child: DoctorConnectionModal(childId: _selectedChildId!),
                             ),
                           );
                        },
                        icon: const Icon(Icons.medical_services_outlined),
                        label: const Text('Find a Clinician'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF00ACC1),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12)
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
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
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _birthdateController = TextEditingController();
  final _passwordController = TextEditingController();
  
  DateTime? _selectedBirthdate;
  bool _isLoading = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _birthdateController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    
    try {
      final session = await AuthSessionService.instance.loadUserSession();
      final guardianEmail = session?.guardianEmail ?? '';

      if (guardianEmail.isEmpty) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Guardian session required.')));
        return;
      }

      final result = await AuthAccountService.instance.createChildAccount(
        guardianEmail: guardianEmail,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (result.success) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Account Created!'),
            content: Text('Write down this Login Code:\n\n${result.account?.loginCode}', style: const TextStyle(fontSize: 16)),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // close dialog
                  Navigator.of(context).pop(true); // close modal and trigger refresh
                },
                child: const Text('Done'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
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
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
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
                const Text('Add Child', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(Icons.close, color: isDark ? Colors.white70 : Colors.black54),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _firstNameController,
                    decoration: InputDecoration(
                      hintText: 'First Name', filled: true,
                      fillColor: isDark ? const Color(0xFF2A2A2C) : const Color(0xFFF5F5F7),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _lastNameController,
                    decoration: InputDecoration(
                      hintText: 'Last Name', filled: true,
                      fillColor: isDark ? const Color(0xFF2A2A2C) : const Color(0xFFF5F5F7),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
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
                          _birthdateController.text = '${pickedDate.year}-${pickedDate.month.toString().padLeft(2,'0')}-${pickedDate.day.toString().padLeft(2,'0')}';
                        });
                      }
                    },
                    decoration: InputDecoration(
                      hintText: 'Birthdate (YYYY-MM-DD)', filled: true,
                      fillColor: isDark ? const Color(0xFF2A2A2C) : const Color(0xFFF5F5F7),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      suffixIcon: const Icon(Icons.calendar_today),
                    ),
                    validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: 'Child Password', filled: true,
                      fillColor: isDark ? const Color(0xFF2A2A2C) : const Color(0xFFF5F5F7),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    validator: (value) => value == null || value.length < 4 ? 'Min 4 characters' : null,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity, height: 48,
                    child: FilledButton(
                      onPressed: _isLoading ? null : _submitForm,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF00ACC1),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isLoading
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Save Child', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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