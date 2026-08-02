import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lumi/services/detection_service.dart';
import '../services/auth_session_service.dart';
import '../services/gamification_service.dart';
import '../services/session_lock_service.dart';
import '../services/local_metrics_service.dart';
import '../services/active_child_context_service.dart';
import '../theme/lumi_theme.dart';
import '../widgets/rounded_card.dart';

class DailyReportScreen extends StatefulWidget {
  const DailyReportScreen({super.key});

  @override
  State<DailyReportScreen> createState() => _DailyReportScreenState();
}

class _DailyReportScreenState extends State<DailyReportScreen> {
  Timer? _midnightTimer;
  String _timeUntilMidnight = "";

  @override
  void initState() {
    super.initState();
    _startMidnightCountdown();
    
    // Call the sync function immediately when the screen opens
    _finalizeDayAndSync();
  }

  Future<void> _finalizeDayAndSync() async {
    try {
      final int? childId = await ActiveChildContextService.instance.getActiveChildId();
      if (childId == null) return;
      
      await LocalMetricsService.instance.curateOneMinuteBatch();
      await SessionLockService.lockDeviceForToday(childId);
      await LocalMetricsService.instance.forceSyncNow(childId);
      
      debugPrint('Day finalized: Local saved, Device locked, Cloud synced.');
    } catch (e) {
      debugPrint('Error finalizing day: $e');
    }
  }

  void _startMidnightCountdown() {
    _updateTime();
    _midnightTimer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());
  }

  void _updateTime() {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final diff = tomorrow.difference(now);
    
    if (mounted) {
      setState(() {
        _timeUntilMidnight = "${diff.inHours.toString().padLeft(2, '0')}:${(diff.inMinutes % 60).toString().padLeft(2, '0')}:${(diff.inSeconds % 60).toString().padLeft(2, '0')}";
      });
    }
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return PopScope(
      canPop: false, // Strict Lock
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : LumiColors.scaffoldLight,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(LumiSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.nightlight_round, size: 80, color: LumiColors.purpleMid),
                const SizedBox(height: LumiSpacing.xl),
                const Text(
                  "Great Job Today!",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    height: 40 / 32,
                    letterSpacing: -0.64,
                    fontWeight: FontWeight.w700,
                    color: LumiColors.textDark,
                  ),
                ),
                const SizedBox(height: LumiSpacing.md),
                const Text(
                  "LUMI is resting. Your screen time limit has been reached to protect your eyes.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, height: 24 / 16, color: LumiColors.textMuted),
                ),
                const SizedBox(height: LumiSpacing.xxl),

                RoundedCard(
                  child: Column(
                    children: [
                      const Text("Daily Report", style: TextStyle(fontSize: 20, height: 28 / 20, fontWeight: FontWeight.w600, color: LumiColors.textDark)),
                      const Divider(height: LumiSpacing.xxl, thickness: 1, color: LumiColors.outline),
                      _StatRow(
                        icon: Icons.favorite,
                        color: LumiColors.redAlert,
                        label: "Final Eye Care", 
                        value: "${GamificationService.instance.healthScoreNotifier.value}/100"
                      ),
                      const SizedBox(height: LumiSpacing.lg),
                      _StatRow(
                        icon: Icons.star_rounded,
                        color: LumiColors.accent,
                        label: "Stars Earned", 
                        value: "${GamificationService.instance.coinsNotifier.value}"
                      ),
                      const SizedBox(height: LumiSpacing.lg),
                      _StatRow(
                        icon: Icons.local_fire_department,
                        color: LumiColors.warning,
                        label: "Daily Streak", 
                        value: "${GamificationService.instance.dailyStreakNotifier.value} Days"
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: LumiSpacing.xxl),
                Text(
                  "LUMI wakes up in:",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, height: 20 / 14, color: isDark ? Colors.white60 : LumiColors.textMuted),
                ),
                const SizedBox(height: LumiSpacing.md),
                Text(
                  _timeUntilMidnight,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 32, height: 40 / 32, fontWeight: FontWeight.w700, letterSpacing: 2, color: LumiColors.textDark),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () async {
                    // 1. Explicitly kill the camera and background isolates!
                    await DetectionService.instance.dispose();
                    
                    // 2. Clear the session
                    await AuthSessionService.instance.clearUserSession();
                    
                    if (context.mounted) Navigator.pushReplacementNamed(context, '/welcome');
                  }, 
                  icon: const Icon(Icons.logout, color: LumiColors.textMuted),
                  label: const Text(
                    "Log Out",
                    style: TextStyle(fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w600, color: LumiColors.textMuted),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  
  const _StatRow({required this.icon, required this.color, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: LumiSpacing.md),
            Text(label, style: const TextStyle(fontSize: 16, height: 24 / 16, fontWeight: FontWeight.w500, color: LumiColors.textDark)),
          ],
        ),
        Text(value, style: const TextStyle(fontSize: 18, height: 24 / 18, fontWeight: FontWeight.w600, color: LumiColors.textDark)),
      ],
    );
  }
}