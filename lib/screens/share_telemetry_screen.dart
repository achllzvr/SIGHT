import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/temporary_access_service.dart';
import '../theme/lumi_theme.dart';
import '../widgets/arcade/arcade.dart';
import '../widgets/lumi_shell.dart';
import 'clinician_sharing_session_screen.dart';

class ShareTelemetryScreen extends StatefulWidget {
  final int childId;
  final String childName;

  const ShareTelemetryScreen({
    super.key,
    required this.childId,
    required this.childName,
  });

  @override
  State<ShareTelemetryScreen> createState() => _ShareTelemetryScreenState();
}

class _ShareTelemetryScreenState extends State<ShareTelemetryScreen> {
  Map<String, dynamic>? _token;
  String? _error;
  bool _loading = true;
  Timer? _countdown;
  Timer? _poll;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  @override
  void dispose() {
    _countdown?.cancel();
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await TemporaryAccessService.instance.generateToken(widget.childId);
    if (!mounted) return;
    if (!result.success || result.data == null) {
      setState(() {
        _loading = false;
        _error = result.message ?? 'Could not generate access code. Try again.';
      });
      return;
    }
    final token = result.data!;
    setState(() {
      _token = token;
      _loading = false;
      final expires = DateTime.tryParse(token['expires_at']?.toString() ?? '');
      _remaining = expires?.difference(DateTime.now()) ?? const Duration(minutes: 15);
      if (_remaining.isNegative) _remaining = Duration.zero;
    });
    _countdown?.cancel();
    _countdown = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _remaining -= const Duration(seconds: 1);
        if (_remaining.isNegative) _remaining = Duration.zero;
      });
    });
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 3), (_) => _checkSession());
  }

  Future<void> _checkSession() async {
    final data = await TemporaryAccessService.instance.getActiveSession(widget.childId);
    if (!mounted || data == null) return;
    if (data['active'] == true && data['session'] is Map) {
      _poll?.cancel();
      _countdown?.cancel();
      final session = Map<String, dynamic>.from(data['session'] as Map);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ClinicianSharingSessionScreen(
            childId: widget.childId,
            childName: widget.childName,
            session: session,
          ),
        ),
      );
    }
  }

  String get _timerLabel {
    final m = _remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = _remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final code = _token?['token_code']?.toString() ?? '------';
    final payload = _token?['qr_payload']?.toString() ?? '';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LumiShell(
        // Expanded layout below — must not wrap in SingleChildScrollView.
        scrollable: false,
        child: Padding(
          padding: const EdgeInsets.all(LumiSpacing.lg),
          child: ArcadeCard(
            padding: const EdgeInsets.all(LumiSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: LumiColors.primaryPurple),
                    ),
                    Expanded(
                      child: Text(
                        LumiTheme.caps('Share with Doctor'),
                        textAlign: TextAlign.center,
                        style: LumiTheme.joyful(22, color: LumiColors.primaryPurple),
                      ),
                    ),
                    const SizedBox(width: LumiSpacing.xxl),
                  ],
                ),
                Text(
                  'Show this code to the doctor for ${widget.childName}. Expires in 15 minutes.',
                  textAlign: TextAlign.center,
                  style: LumiTheme.clanRegular(14, color: LumiColors.textMuted, height: 1.45),
                ),
                const SizedBox(height: LumiSpacing.md),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: ArcadeSizes.badgePadH,
                      vertical: ArcadeSizes.badgePadV,
                    ),
                    decoration: BoxDecoration(
                      color: LumiColors.primaryLight,
                      borderRadius: BorderRadius.circular(LumiRadii.pill),
                      border: Border.all(
                        color: _remaining.inSeconds <= 60 ? LumiColors.redAlert : LumiColors.primaryGreen,
                        width: ArcadeSizes.badgeBorder,
                      ),
                      boxShadow: LumiShadows.badge(
                        _remaining.inSeconds <= 60 ? LumiColors.redAlert : LumiColors.primaryGreen,
                      ),
                    ),
                    child: Text(
                      LumiTheme.caps('Expires in $_timerLabel'),
                      style: LumiTheme.clanMedium(
                        13,
                        color: _remaining.inSeconds <= 60 ? LumiColors.redAlert : LumiColors.primaryGreen,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: LumiSpacing.lg),
                if (_loading)
                  const Expanded(
                    child: Center(child: CircularProgressIndicator(color: LumiColors.primaryPurple)),
                  )
                else if (_error != null)
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: LumiTheme.clanRegular(14, color: LumiColors.redAlert, height: 1.45),
                        ),
                        const SizedBox(height: LumiSpacing.md),
                        ArcadeButton(text: 'RETRY', expand: false, onTap: _generate),
                      ],
                    ),
                  )
                else
                  Expanded(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: LumiSpacing.lg,
                            vertical: LumiSpacing.sm,
                          ),
                          decoration: BoxDecoration(
                            color: LumiColors.secondaryPurple,
                            borderRadius: BorderRadius.circular(LumiRadii.md),
                            border: Border.all(color: LumiColors.primaryPurple, width: ArcadeSizes.cardBorder),
                            boxShadow: LumiShadows.card(LumiColors.primaryPurple),
                          ),
                          child: Text(
                            code,
                            style: LumiTheme.joyful(38, color: LumiColors.primaryPurple, letterSpacing: 6),
                          ),
                        ),
                        const SizedBox(height: LumiSpacing.lg),
                        if (payload.isNotEmpty)
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.all(LumiSpacing.md),
                              decoration: BoxDecoration(
                                color: LumiColors.cardWhite,
                                borderRadius: BorderRadius.circular(LumiRadii.lg),
                                border: Border.all(
                                  color: LumiColors.secondaryLight,
                                  width: ArcadeSizes.cardBorder,
                                ),
                                boxShadow: LumiShadows.card(),
                              ),
                              child: QrImageView(
                                data: payload,
                                version: QrVersions.auto,
                                size: 200,
                              ),
                            ),
                          ),
                        const Spacer(),
                        Text(
                          'Waiting for doctor to scan…',
                          style: LumiTheme.clanRegular(14, color: LumiColors.textMuted),
                        ),
                        const SizedBox(height: LumiSpacing.md),
                        ArcadeButton(
                          text: 'GENERATE NEW CODE',
                          fontSize: 14,
                          variant: ArcadeButtonVariant.outline,
                          onTap: _generate,
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
