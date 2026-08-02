import 'package:flutter/material.dart';

import '../../../services/active_child_context_service.dart';
import '../../../services/auth_account_service.dart';
import '../../../services/auth_session_service.dart';
import '../../../theme/lumi_theme.dart';
import '../../../widgets/arcade/arcade.dart';
import '../../share_telemetry_screen.dart';
import 'shared_widgets.dart';

class ChildDashboardShareTab extends StatefulWidget {
  final int? childId;
  const ChildDashboardShareTab({super.key, this.childId});

  @override
  State<ChildDashboardShareTab> createState() => _ChildDashboardShareTabState();
}

class _ChildDashboardShareTabState extends State<ChildDashboardShareTab> {
  String? _childName;
  int? _childId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadChild();
  }

  Future<void> _loadChild() async {
    try {
      _childId = widget.childId ?? await ActiveChildContextService.instance.getActiveChildId();
      if (_childId != null) {
        final session = await AuthSessionService.instance.loadUserSession();
        if (session?.guardianEmail != null) {
          final accounts = await AuthAccountService.instance.listChildrenForGuardian(session!.guardianEmail!);
          final match = accounts.where((a) => a.childId == _childId).toList();
          if (match.isNotEmpty) _childName = match.first.displayName;
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  void _openShare() {
    if (_childId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No child selected.')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ShareTelemetryScreen(
          childId: _childId!,
          childName: _childName ?? 'Child',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: LumiColors.primaryPurple));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(LumiSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(LumiSpacing.lg),
            decoration: BoxDecoration(
              color: LumiColors.primaryLight,
              borderRadius: BorderRadius.circular(ArcadeSizes.cardRadius),
              border: Border.all(color: LumiColors.primaryPurple, width: ArcadeSizes.cardBorder),
              boxShadow: LumiShadows.card(LumiColors.primaryPurple),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const GuardianSectionTitle('Share Telemetry', size: 20),
                const SizedBox(height: LumiSpacing.md),
                Text(
                  _childName != null
                      ? 'Generate a temporary OTP code so ${_childName!}\'s clinician can view eye-care data.'
                      : 'Generate a temporary OTP code for your clinician to view eye-care data.',
                  style: LumiTheme.clanRegular(14, color: LumiColors.textMuted, height: 1.45),
                ),
                const SizedBox(height: LumiSpacing.lg),
                ArcadeButton(
                  text: 'SHARE WITH CLINICIAN',
                  fontSize: 14,
                  onTap: _openShare,
                ),
                const SizedBox(height: LumiSpacing.md),
                Text(
                  'You can end the clinician session anytime from the share screen.',
                  style: LumiTheme.clanRegular(12, color: LumiColors.textMuted, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
