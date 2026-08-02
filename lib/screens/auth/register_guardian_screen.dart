import 'package:flutter/material.dart';

import '../../services/active_child_context_service.dart';
import '../../services/auth_account_service.dart';
import '../../services/auth_session_service.dart';
import '../../services/legal_document_service.dart';
import '../../theme/lumi_theme.dart';
import '../../widgets/arcade/arcade.dart';
import '../../widgets/auth_landing_shell.dart';
import 'login_screen.dart';
import 'verify_email_otp_screen.dart';

class RegisterGuardianScreen extends StatefulWidget {
  final List<int> legalDocumentIds;

  const RegisterGuardianScreen({super.key, this.legalDocumentIds = const []});

  @override
  State<RegisterGuardianScreen> createState() => _RegisterGuardianScreenState();
}

class _RegisterGuardianScreenState extends State<RegisterGuardianScreen> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  int _step = 0;
  bool _loading = false;
  String? _error;
  List<int> _legalIds = const [];

  @override
  void initState() {
    super.initState();
    _legalIds = widget.legalDocumentIds;
    if (_legalIds.isEmpty) {
      _loadLegalIds();
    }
  }

  Future<void> _loadLegalIds() async {
    final docs = await LegalDocumentService.instance.fetchLatest();
    if (!mounted) return;
    setState(() {
      _legalIds = docs.map((d) => (d['id'] as num).toInt()).toList();
    });
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _goToLogin() {
    Navigator.of(context).pushReplacement(
      authSlideRoute(const LoginScreen(), reverse: true),
    );
  }

  void _nextFromNames() {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    if (firstName.isEmpty || lastName.isEmpty) {
      setState(() => _error = 'Please enter first and last name.');
      return;
    }
    setState(() {
      _error = null;
      _step = 1;
    });
  }

  void _backToNames() {
    setState(() {
      _error = null;
      _step = 0;
    });
  }

  Future<void> _register() async {
    if (_loading) return;

    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (!_isValidEmail(email)) {
      setState(() => _error = 'Please enter a valid email.');
      return;
    }
    if (password.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }
    if (password != confirm) {
      setState(() => _error = 'Passwords don’t match.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await AuthAccountService.instance.registerGuardian(
      firstName: firstName,
      lastName: lastName,
      email: email,
      password: password,
      documentIds: _legalIds,
    );

    if (!mounted) return;

    if (!result.success) {
      setState(() {
        _loading = false;
        _error = result.message;
      });
      return;
    }

    await ActiveChildContextService.instance.clearActiveChild();
    await AuthSessionService.instance.saveGuardianSession(guardianEmail: email);

    if (!mounted) return;
    FocusManager.instance.primaryFocus?.unfocus();

    Navigator.of(context).pushAndRemoveUntil(
      authSlideRoute(VerifyEmailOtpScreen(email: email)),
      (route) => false,
    );
  }

  Widget _stepTransition(Widget child) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 360),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (widget, animation) {
        final offset = Tween<Offset>(
          begin: Offset(_step == 1 ? 0.12 : -0.12, 0),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: offset, child: widget),
        );
      },
      child: KeyedSubtree(
        key: ValueKey<int>(_step),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthLandingShell(
      footer: _step == 0
          ? AuthFooterPrompt(
              prompt: 'Have An Account?',
              buttonLabel: 'Login',
              onTap: _goToLogin,
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthHeader(
            title: 'Create an Account',
            showBack: _step == 1,
            showUserIcon: _step == 0,
            onBack: _backToNames,
          ),
          const SizedBox(height: LumiSpacing.lg),
          _stepTransition(
            _step == 0 ? _buildNamesStep() : _buildCredentialsStep(),
          ),
        ],
      ),
    );
  }

  Widget _buildNamesStep() {
    return AuthFormCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ArcadeTextField(
            label: 'First Name',
            controller: _firstNameController,
            keyboardType: TextInputType.name,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: LumiSpacing.md),
          ArcadeTextField(
            label: 'Last Name',
            controller: _lastNameController,
            keyboardType: TextInputType.name,
            textInputAction: TextInputAction.done,
          ),
          if (_error != null) ...[
            const SizedBox(height: LumiSpacing.md),
            Text(
              _error!,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: LumiTheme.clanMedium(13, color: LumiColors.redAlert),
            ),
          ],
          const SizedBox(height: LumiSpacing.xl),
          AuthOutlineButton(label: 'Next', onTap: _nextFromNames),
        ],
      ),
    );
  }

  Widget _buildCredentialsStep() {
    return AuthFormCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ArcadeTextField(
            label: 'Email',
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: LumiSpacing.md),
          ArcadeTextField(
            label: 'Password',
            controller: _passwordController,
            obscureText: true,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: LumiSpacing.md),
          ArcadeTextField(
            label: 'Confirm Password',
            controller: _confirmController,
            obscureText: true,
            textInputAction: TextInputAction.done,
          ),
          if (_error != null) ...[
            const SizedBox(height: LumiSpacing.md),
            Text(
              _error!,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: LumiTheme.clanMedium(13, color: LumiColors.redAlert),
            ),
          ],
          const SizedBox(height: LumiSpacing.xl),
          AuthPrimaryButton(
            label: _loading ? 'Please wait…' : 'Register',
            enabled: !_loading,
            onTap: _register,
          ),
        ],
      ),
    );
  }
}
