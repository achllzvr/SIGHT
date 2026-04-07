import 'package:flutter/material.dart';

import '../services/gamification_service.dart';
import '../widgets/rounded_card.dart';
import 'guardian_access_screen.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({Key? key}) : super(key: key);

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final List<_TaskItem> _tasks = [
    _TaskItem('20-20-20 Break', 'Complete 1 eye break', false),
    _TaskItem('20-20-20 Break', 'Complete 1 eye break', false),
    _TaskItem('20-20-20 Break', 'Complete 1 eye break', false),
    _TaskItem('20-20-20 Break', 'Complete 1 eye break', false),
  ];

  @override
  void initState() {
    super.initState();
    GamificationService.instance.sessionXpNotifier.addListener(_onProgressChanged);
    GamificationService.instance.dailyStreakNotifier.addListener(_onProgressChanged);
  }

  @override
  void dispose() {
    GamificationService.instance.sessionXpNotifier.removeListener(_onProgressChanged);
    GamificationService.instance.dailyStreakNotifier.removeListener(_onProgressChanged);
    super.dispose();
  }

  void _onProgressChanged() {
    final xp = GamificationService.instance.sessionXpNotifier.value;
    final streak = GamificationService.instance.dailyStreakNotifier.value;

    if (xp >= 5 || streak > 0) {
      setState(() {
        for (int i = 0; i < _tasks.length && i < 2; i++) {
          _tasks[i].done = true;
        }
      });
    }

    if (xp >= 10 || streak >= 2) {
      setState(() {
        for (int i = 2; i < _tasks.length; i++) {
          _tasks[i].done = true;
        }
      });
    }
  }

  Widget _taskCard(BuildContext context, _TaskItem task) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RoundedCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: task.done ? const Color(0xFF7FC86D) : (isDark ? Colors.white12 : const Color(0xFFEAF4E3)),
              border: Border.all(color: isDark ? Colors.white70 : Colors.black54),
            ),
            child: task.done ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(task.title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(task.subtitle, style: TextStyle(fontSize: 10, color: isDark ? Colors.white60 : Colors.black54)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFEFD9EE),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? Colors.white70 : Colors.black54, width: 0.8),
            ),
            child: const Text('20/20 Score', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final doneCount = _tasks.where((t) => t.done).length;
    final progress = _tasks.isEmpty ? 0.0 : doneCount / _tasks.length;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Today's Tasks", style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          IconButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const GuardianAccessScreen()),
                              );
                            },
                            icon: const Icon(Icons.shield_outlined),
                            tooltip: 'Guardian Access',
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEAF4E3),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: isDark ? Colors.white70 : Colors.black54, width: 0.8),
                            ),
                            child: Text('$doneCount/${_tasks.length} done', style: const TextStyle(fontWeight: FontWeight.w600)),
                          ),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 6),
                  ValueListenableBuilder<int>(
                    valueListenable: GamificationService.instance.sessionXpNotifier,
                    builder: (_, xp, __) => ValueListenableBuilder<int>(
                      valueListenable: GamificationService.instance.dailyStreakNotifier,
                      builder: (_, streak, __) => Text(
                        'Session XP: $xp • Streak: $streak',
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 12,
                      color: const Color(0xFF7FC86D),
                      backgroundColor: isDark ? Colors.white10 : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ..._tasks.map((task) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _taskCard(context, task),
                      )),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TaskItem {
  final String title;
  final String subtitle;
  bool done;
  _TaskItem(this.title, this.subtitle, this.done);
}

