import 'package:flutter/material.dart';

import '../widgets/lumi_shell.dart';
import '../services/gamification_service.dart';
import '../theme/lumi_theme.dart';

class ChildDashboardScreen extends StatelessWidget {
  const ChildDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final actions = <_ChildActionItem>[
      const _ChildActionItem(title: 'Start Focus Session', subtitle: 'Enable calmer mode for study time', icon: Icons.timer_outlined),
      const _ChildActionItem(title: 'Eye Exercise', subtitle: 'Take a short blink and distance break', icon: Icons.visibility_outlined),
      const _ChildActionItem(title: 'Daily Streak', subtitle: 'Check your wellness progress today', icon: Icons.local_fire_department_outlined),
      const _ChildActionItem(title: 'Ask Guardian', subtitle: 'Send a message for guidance', icon: Icons.chat_bubble_outline),
    ];

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
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_ios, color: LumiColors.textDark),
                    ),
                    const Expanded(
                      child: Text(
                        'Child Dashboard',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          height: 32 / 24,
                          letterSpacing: -0.24,
                          fontWeight: FontWeight.w600,
                          color: LumiColors.textDark,
                        ),
                      ),
                    ),
                    const SizedBox(width: 40),
                  ],
                ),
                const SizedBox(height: LumiSpacing.md),
                Container(
                  padding: const EdgeInsets.all(LumiSpacing.lg),
                  decoration: BoxDecoration(
                    color: LumiColors.cardWhite,
                    borderRadius: BorderRadius.circular(LumiRadii.lg),
                    border: Border.all(color: LumiColors.outline, width: 1),
                    boxShadow: LumiShadows.card(),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('LUMI Status', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18, height: 24 / 18, color: LumiColors.textDark)),
                      const SizedBox(height: LumiSpacing.lg),
                      ValueListenableBuilder<int>(
                        valueListenable: GamificationService.instance.healthScoreNotifier,
                        builder: (context, hp, _) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Eye Care', style: TextStyle(fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w600, color: LumiColors.textMuted)),
                                  Text('$hp/100', style: TextStyle(fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w600, color: hp > 50 ? LumiColors.success : LumiColors.redAlert)),
                                ],
                              ),
                              const SizedBox(height: LumiSpacing.md),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(LumiRadii.pill),
                                child: LinearProgressIndicator(
                                  value: hp / 100,
                                  minHeight: 12,
                                  backgroundColor: LumiColors.outline,
                                  color: hp > 50 ? LumiColors.success : LumiColors.redAlert,
                                ),
                              ),
                            ],
                          );
                        }
                      ),
                      const SizedBox(height: LumiSpacing.lg),
                      ValueListenableBuilder<int>(
                        valueListenable: GamificationService.instance.coinsNotifier,
                        builder: (context, coins, _) {
                          return Row(
                            children: [
                              const Icon(Icons.star_rounded, color: LumiColors.accent),
                              const SizedBox(width: LumiSpacing.md),
                              Text('$coins Stars', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, height: 24 / 16, color: LumiColors.textDark)),
                            ],
                          );
                        }
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: LumiSpacing.md),
                Expanded(
                  child: ListView.separated(
                    itemBuilder: (context, index) {
                      final item = actions[index];
                      return _ActionCard(item: item);
                    },
                    separatorBuilder: (_, __) => const SizedBox(height: LumiSpacing.md),
                    itemCount: actions.length,
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

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.item});

  final _ChildActionItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: LumiColors.cardWhite,
        borderRadius: BorderRadius.circular(LumiRadii.lg),
        border: Border.all(color: LumiColors.outline, width: 1),
        boxShadow: LumiShadows.card(),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(LumiRadii.lg)),
        contentPadding: const EdgeInsets.symmetric(horizontal: LumiSpacing.lg, vertical: LumiSpacing.sm),
        leading: CircleAvatar(
          backgroundColor: LumiColors.greenSoft,
          child: Icon(item.icon, color: LumiColors.safeText),
        ),
        title: Text(item.title, style: const TextStyle(fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w600, color: LumiColors.textDark)),
        subtitle: Text(item.subtitle, style: const TextStyle(fontSize: 12, height: 16 / 12, color: LumiColors.textMuted)),
        trailing: const Icon(Icons.chevron_right, color: LumiColors.textMuted),
      ),
    );
  }
}

class _ChildActionItem {
  const _ChildActionItem({required this.title, required this.subtitle, required this.icon});

  final String title;
  final String subtitle;
  final IconData icon;
}
