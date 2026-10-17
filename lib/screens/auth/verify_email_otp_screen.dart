import 'package:flutter/material.dart';

import '../../services/auth_account_service.dart';
import '../../services/auth_session_service.dart';
import '../../services/guardian_setup_service.dart';
import '../../theme/lumi_theme.dart';
import '../../widgets/arcade/arcade.dart';
import '../../widgets/auth_landing_shell.dart';
import 'login_screen.dart';

/// Guardian email verification via Gmail SMTP OTP (A4 / S2).
class VerifyEmailOtpScreen extends StatefulWidget {
  final String email;

  /// Kept in memory from register/login so we can obtain a Sanctum token after OTP.
  final String? password;

  /// When true (e.g. redirected from unverified login), request a fresh code on open.
  final bool autoResendOnOpen;

  const VerifyEmailOtpScreen({
    super.key,
    required this.email,
    this.password,
    this.autoResendOnOpen = false,
  });

  @override
  State<VerifyEmailOtpScreen> createState() => _VerifyEmailOtpScreenState();
}

class _VerifyEmailOtpScreenState extends State<VerifyEmailOtpScreen> {
  final _otpController = TextEditingController();
  bool _loading = false;
  bool _resending = false;
  String? _error;
  String? _info;

  @override
  void initState() {
    super.initState();
    if (widget.autoResendOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _resend();
      });
    }
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final otp = _otpController.text.trim();
    if (otp.length < 6) {
      setState(() => _error = 'Enter the 6-digit code from your email.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await AuthAccountService.instance.verifyEmailOtp(
      email: widget.email,
      otp: otp,
    );

    if (!mounted) return;
    if (!result.success) {
      setState(() {
        _loading = false;
        _error = result.message;
      });
      return;
    }

    // Session only after OTP — matches server email_verified_at.
    await AuthSessionService.instance.saveGuardianSession(
      guardianEmail: widget.email,
    );

    // Prefer token from verify response; fall back to login for older servers.
    var token = await AuthSessionService.instance.loadAccessToken();
    if (token == null || token.isEmpty) {
      final password = widget.password;
      if (password != null && password.isNotEmpty) {
        final login = await AuthAccountService.instance.authenticateGuardian(
          email: widget.email,
          password: password,
        );
        if (!mounted) return;
        if (!login.success) {
          setState(() {
            _loading = false;
            _error =
                '${login.message} Sign in once to finish setting up your session.';
          });
          Navigator.of(context).pushAndRemoveUntil(
            authSlideRoute(const LoginScreen()),
            (route) => false,
          );
          return;
        }
        token = await AuthSessionService.instance.loadAccessToken();
      }
    }

    if (token == null || token.isEmpty) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not start a secure session. Please sign in.';
      });
      Navigator.of(context).pushAndRemoveUntil(
        authSlideRoute(const LoginScreen()),
        (route) => false,
      );
      return;
    }

    final hasPin = await GuardianSetupService.instance.hasGuardianPin();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      hasPin ? '/parent-onboarding' : '/guardian-setup',
      (route) => false,
    );
  }

  Future<void> _resend() async {
    setState(() {
      _resending = true;
      _error = null;
      _info = null;
    });
    final result = await AuthAccountService.instance.resendVerificationOtp(widget.email);
    if (!mounted) return;
    setState(() {
      _resending = false;
      if (result.success) {
        _info = result.message;
      } else {
        _error = result.message;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AuthLandingShell(
      child: AuthStagger(
        children: [
          const AuthHeader(title: 'Verify Email', showUserIcon: true),
          const SizedBox(height: LumiSpacing.lg),
          AuthFormCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'We sent a 6-digit code to\n${widget.email}',
                  textAlign: TextAlign.center,
                  style: LumiTheme.clanMedium(14, color: LumiColors.textMuted, height: 1.45),
                ),
                const SizedBox(height: LumiSpacing.lg),
                ArcadeCodeField(
                  label: 'Verification Code',
                  controller: _otpController,
                ),
                if (_error != null) ...[
                  const SizedBox(height: LumiSpacing.md),
                  Text(_error!, style: LumiTheme.clanMedium(13, color: LumiColors.redAlert)),
                ],
                if (_info != null) ...[
                  const SizedBox(height: LumiSpacing.md),
                  Text(_info!, style: LumiTheme.clanMedium(13, color: LumiColors.primaryGreen)),
                ],
                const SizedBox(height: LumiSpacing.xl),
                AuthPrimaryButton(
                  label: _loading ? 'Verifying…' : 'Verify',
                  enabled: !_loading,
                  onTap: _verify,
                ),
                const SizedBox(height: LumiSpacing.md),
                AuthOutlineButton(
                  label: _resending ? 'Sending…' : 'Resend Code',
                  onTap: _resending ? null : _resend,
                ),
                const SizedBox(height: LumiSpacing.md),
                Text(
                  'Needs internet. Check spam if you don’t see the email.',
                  textAlign: TextAlign.center,
                  style: LumiTheme.clanRegular(12, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
