import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_account_service.dart';
import '../services/auth_session_service.dart';
import '../widgets/lumi_shell.dart';

class AddChildrenScreen extends StatefulWidget {
  const AddChildrenScreen({super.key});

  @override
  State<AddChildrenScreen> createState() => _AddChildrenScreenState();
}

class _AddChildrenScreenState extends State<AddChildrenScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _childIdController = TextEditingController();

  bool _saving = false;
  String? _error;
  String? _resultCode;

  @override
  void dispose() {
    _nameController.dispose();
    _passwordController.dispose();
    _childIdController.dispose();
    super.dispose();
  }

  Future<void> _createChild() async {
    if (_saving) return;

    setState(() {
      _saving = true;
      _error = null;
      _resultCode = null;
    });

    final session = await AuthSessionService.instance.loadUserSession();
    final guardianEmail = session?.guardianEmail;
    if (guardianEmail == null || guardianEmail.isEmpty) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Guardian session required.';
      });
      return;
    }

    final childIdRaw = _childIdController.text.trim();
    final childId = childIdRaw.isEmpty ? null : int.tryParse(childIdRaw);
    if (childIdRaw.isNotEmpty && childId == null) {
      setState(() {
        _saving = false;
        _error = 'Child ID must be numeric.';
      });
      return;
    }

    final result = await AuthAccountService.instance.createChildAccount(
      guardianEmail: guardianEmail,
      displayName: _nameController.text.trim(),
      password: _passwordController.text,
      childId: childId,
    );

    if (!mounted) return;

    setState(() {
      _saving = false;
      if (result.success) {
        _resultCode = result.account?.loginCode;
        _nameController.clear();
        _passwordController.clear();
        _childIdController.clear();
      } else {
        _error = result.message;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LumiShell(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_ios),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 18)],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Add Child Account', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Child Name', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Child Password', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _childIdController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(labelText: 'Server Child ID (optional)', border: OutlineInputBorder()),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(_error!, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700)),
                    ],
                    if (_resultCode != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Child created. Login code: $_resultCode',
                        style: const TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.w800),
                      ),
                    ],
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _saving ? null : _createChild,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7EC48C),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _saving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Create Child Account'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
