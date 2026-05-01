import 'package:flutter/material.dart';

import '../widgets/lumi_shell.dart';

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
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_ios),
                    ),
                    const Expanded(
                      child: Text(
                        'Child Dashboard',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 40),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16)],
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Today\'s Status', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      SizedBox(height: 8),
                      Text('You are doing great. Keep your screen at safe distance and take breaks every 20 minutes.'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    itemBuilder: (context, index) {
                      final item = actions[index];
                      return _ActionCard(item: item);
                    },
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12)],
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFDDF2E2),
          child: Icon(item.icon, color: const Color(0xFF2F6D47)),
        ),
        title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(item.subtitle),
        trailing: const Icon(Icons.chevron_right),
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
