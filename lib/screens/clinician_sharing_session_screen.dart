import 'dart:async';

import 'package:flutter/material.dart';

import '../services/temporary_access_service.dart';
import '../theme/lumi_theme.dart';
import '../widgets/arcade/arcade.dart';

class ClinicianSharingSessionScreen extends StatefulWidget {
  final int childId;
  final String childName;
  final Map<String, dynamic> session;

  const ClinicianSharingSessionScreen({
    super.key,
    required this.childId,
    required this.childName,
    required this.session,
  });

  @override
  State<ClinicianSharingSessionScreen> createState() => _ClinicianSharingSessionScreenState();
}

class _ClinicianSharingSessionScreenState extends State<ClinicianSharingSessionScreen> {
  bool _ending = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(const Duration(seconds: 4), (_) => _checkStillActive());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  int? get _sessionId {
    final id = widget.session['session_id'];
    if (id is num) return id.toInt();
    return int.tryParse(id?.toString() ?? '');
  }

  String get _clinicianName {
    final c = widget.session['clinician'];
    if (c is Map && c['name'] != null) return c['name'].toString();
    return 'Doctor';
  }

  Future<void> _checkStillActive() async {
    final data = await TemporaryAccessService.instance.getActiveSession(widget.childId);
    if (!mounted) return;
    if (data == null || data['active'] != true) {
      _poll?.cancel();
      Navigator.of(context).pop();
    }
  }

  Future<void> _end() async {
    final id = _sessionId;
    if (id == null || _ending) return;
    setState(() => _ending = true);
    await TemporaryAccessService.instance.endSession(id);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: LumiColors.scaffoldMint,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(LumiSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                ArcadeCard(
                  padding: const EdgeInsets.all(LumiSpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 96,
                          height: 96,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: LumiColors.secondaryGreen,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: LumiColors.primaryGreen,
                              width: ArcadeSizes.cardBorder,
                            ),
                            boxShadow: LumiShadows.card(LumiColors.primaryGreen),
                          ),
                          child: const Icon(Icons.visibility, color: LumiColors.primaryGreen, size: 48),
                        ),
                      ),
                      const SizedBox(height: LumiSpacing.lg),
                      Text(
                        LumiTheme.caps('Data is being viewed'),
                        textAlign: TextAlign.center,
                        style: LumiTheme.joyful(24, color: LumiColors.primaryPurple, height: 1.2),
                      ),
                      const SizedBox(height: LumiSpacing.md),
                      Text(
                        '$_clinicianName is currently viewing ${widget.childName}\'s eye-care data on the clinic web portal.',
                        textAlign: TextAlign.center,
                        style: LumiTheme.clanRegular(15, color: LumiColors.textMuted, height: 1.5),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (_ending)
                  const Center(
                    child: SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: LumiColors.primaryPurple),
                    ),
                  )
                else
                  ArcadeButton(text: 'END VIEWING SESSION', onTap: _end),
                const SizedBox(height: LumiSpacing.md),
                Text(
                  'Ending this session immediately locks doctor access on the web app.',
                  textAlign: TextAlign.center,
                  style: LumiTheme.clanRegular(12, color: LumiColors.textMuted, height: 1.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
