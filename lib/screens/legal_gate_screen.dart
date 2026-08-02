import 'package:flutter/material.dart';

import '../services/legal_document_service.dart';
import '../theme/lumi_theme.dart';
import '../widgets/auth_landing_shell.dart';
import 'auth/register_guardian_screen.dart';

class LegalGateScreen extends StatefulWidget {
  const LegalGateScreen({super.key});

  @override
  State<LegalGateScreen> createState() => _LegalGateScreenState();
}

class _LegalGateScreenState extends State<LegalGateScreen> {
  List<Map<String, dynamic>> _docs = [];
  bool _loading = true;
  bool _accepted = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final docs = await LegalDocumentService.instance.fetchLatest();
      if (!mounted) return;
      setState(() {
        _docs = docs;
        _loading = false;
        if (docs.isEmpty) {
          _error = 'Unable to load Terms & Privacy. Check your connection.';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _docs = List<Map<String, dynamic>>.from(LegalDocumentService.bundledDocuments);
        if (_docs.isEmpty) {
          _error = 'Failed to load legal documents.';
        }
      });
    }
  }

  void _continue() {
    if (!_accepted || _docs.isEmpty) return;
    final ids = _docs.map((d) => (d['id'] as num).toInt()).toList();
    Navigator.of(context).push(
      authSlideRoute(RegisterGuardianScreen(legalDocumentIds: ids)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthLandingShell(
      footer: AuthPrimaryButton(
        label: 'Continue',
        enabled: _accepted && !_loading && _docs.isNotEmpty,
        onTap: _continue,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthHeader(
            title: 'Terms & Privacy',
            showBack: true,
            onBack: () => Navigator.pop(context),
          ),
          const SizedBox(height: LumiSpacing.sm),
          Text(
            'Please review and accept before creating a parent account.',
            style: LumiTheme.clanRegular(13, height: 1.4),
          ),
          const SizedBox(height: LumiSpacing.md),
          AuthFormCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(
                      child: CircularProgressIndicator(color: LumiColors.primaryPurple),
                    ),
                  )
                else if (_error != null && _docs.isEmpty)
                  Column(
                    children: [
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: LumiTheme.clanRegular(14, height: 1.45),
                      ),
                      const SizedBox(height: LumiSpacing.md),
                      AuthOutlineButton(label: 'Retry', onTap: _load),
                    ],
                  )
                else
                  ..._docs.expand((doc) {
                    final type = (doc['document_type'] as String? ?? 'document').toUpperCase();
                    final version = doc['version_number']?.toString() ?? '';
                    return [
                      Text(
                        LumiTheme.caps('$type V$version'),
                        style: LumiTheme.joyful(16, color: LumiColors.textDark),
                      ),
                      const SizedBox(height: LumiSpacing.sm),
                      Text(
                        doc['content_text']?.toString() ?? '',
                        style: LumiTheme.clanRegular(13, height: 1.5),
                      ),
                      const SizedBox(height: LumiSpacing.md),
                    ];
                  }),
                GestureDetector(
                  onTap: _docs.isEmpty ? null : () => setState(() => _accepted = !_accepted),
                  child: AnimatedContainer(
                    duration: LumiMotion.fast,
                    padding: const EdgeInsets.all(LumiSpacing.md),
                    decoration: BoxDecoration(
                      color: _accepted ? LumiColors.secondaryGreen : LumiColors.primaryLight,
                      borderRadius: BorderRadius.circular(LumiRadii.lg),
                      border: Border.all(
                        color: _accepted ? LumiColors.primaryGreen : LumiColors.secondaryLight,
                        width: ArcadeSizes.badgeBorder,
                      ),
                    ),
                    child: Row(
                      children: [
                        AnimatedContainer(
                          duration: LumiMotion.fast,
                          width: 26,
                          height: 26,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _accepted ? LumiColors.primaryGreen : LumiColors.primaryLight,
                            borderRadius: BorderRadius.circular(LumiRadii.sm),
                            border: Border.all(
                              color: _accepted ? LumiColors.primaryGreen : LumiColors.secondaryLight,
                              width: 3,
                            ),
                          ),
                          child: _accepted
                              ? const Icon(Icons.check, size: 16, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: LumiSpacing.md),
                        Expanded(
                          child: Text(
                            'I agree to the Terms & Conditions and Privacy Policy',
                            style: LumiTheme.clanMedium(13, color: LumiColors.textDark, height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
