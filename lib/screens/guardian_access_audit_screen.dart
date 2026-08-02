import 'package:flutter/material.dart';

import '../services/temporary_access_service.dart';
import '../theme/lumi_theme.dart';
import '../widgets/arcade/arcade.dart';
import '../widgets/lumi_shell.dart';

class GuardianAccessAuditScreen extends StatefulWidget {
  final int childId;
  final String childName;

  const GuardianAccessAuditScreen({
    super.key,
    required this.childId,
    required this.childName,
  });

  @override
  State<GuardianAccessAuditScreen> createState() => _GuardianAccessAuditScreenState();
}

class _GuardianAccessAuditScreenState extends State<GuardianAccessAuditScreen> {
  bool _loading = true;
  List<dynamic> _logs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final logs = await TemporaryAccessService.instance.getAccessLogs(widget.childId);
    if (!mounted) return;
    setState(() {
      _logs = logs;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LumiShell(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(LumiSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: LumiColors.primaryPurple),
                    ),
                    Expanded(
                      child: Text(
                        LumiTheme.caps('Access History'),
                        textAlign: TextAlign.center,
                        style: LumiTheme.joyful(20, color: LumiColors.primaryPurple),
                      ),
                    ),
                    IconButton(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh, color: LumiColors.primaryPurple),
                    ),
                  ],
                ),
                Text(
                  'Doctors who viewed ${widget.childName}\'s data with a temporary share code.',
                  textAlign: TextAlign.center,
                  style: LumiTheme.clanRegular(14, color: LumiColors.textMuted, height: 1.45),
                ),
                const SizedBox(height: LumiSpacing.lg),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator(color: LumiColors.primaryPurple))
                      : _logs.isEmpty
                          ? Center(
                              child: Text(
                                'No doctor access events yet.',
                                style: LumiTheme.clanRegular(14, color: LumiColors.textMuted),
                              ),
                            )
                          : ListView.separated(
                              itemCount: _logs.length,
                              separatorBuilder: (_, __) => const SizedBox(height: LumiSpacing.md),
                              itemBuilder: (_, i) {
                                final log = _logs[i] as Map;
                                return ArcadeCard(
                                  padding: const EdgeInsets.all(LumiSpacing.lg),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        LumiTheme.caps(log['clinician_name']?.toString() ?? 'Doctor'),
                                        style: LumiTheme.joyful(17, color: LumiColors.textDark),
                                      ),
                                      const SizedBox(height: LumiSpacing.sm),
                                      Text(
                                        'Accessed: ${log['accessed_at'] ?? '—'}',
                                        style: LumiTheme.clanRegular(13, color: LumiColors.textMuted, height: 1.5),
                                      ),
                                      Text(
                                        'Ended: ${log['ended_at'] ?? '—'}',
                                        style: LumiTheme.clanRegular(13, color: LumiColors.textMuted, height: 1.5),
                                      ),
                                      Text(
                                        'Status: ${log['status'] ?? '—'} · Ended by: ${log['ended_by'] ?? '—'}',
                                        style: LumiTheme.clanRegular(13, color: LumiColors.textMuted, height: 1.5),
                                      ),
                                    ],
                                  ),
                                );
                              },
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
