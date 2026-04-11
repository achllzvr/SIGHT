import 'package:flutter/material.dart';

import '../services/gamification_service.dart';
import '../services/task_service.dart';
import '../services/task_models.dart';
import '../widgets/rounded_card.dart';
import 'guardian_access_screen.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({Key? key}) : super(key: key);

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  @override
  void initState() {
    super.initState();
    TaskService.instance.initialize();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Widget _taskCard(BuildContext context, Task task) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        // Show task details or allow completion for manual tasks
        _showTaskDetails(context, task);
      },
      child: RoundedCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: task.isCompleted
                    ? const Color(0xFF7FC86D)
                    : (isDark ? Colors.white12 : const Color(0xFFEAF4E3)),
                border: Border.all(color: isDark ? Colors.white70 : Colors.black54),
              ),
              child: task.isCompleted ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(task.title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(task.description, style: TextStyle(fontSize: 10, color: isDark ? Colors.white60 : Colors.black54)),
                  // Show progress for tasks with targets
                  if (task.targetValue != null && !task.isCompleted)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: task.progress,
                          minHeight: 4,
                          color: const Color(0xFF7FC86D),
                          backgroundColor: isDark ? Colors.white10 : Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: task.isCompleted ? const Color(0xFF7FC86D) : const Color(0xFFEFD9EE),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: task.isCompleted ? const Color(0xFF7FC86D) : (isDark ? Colors.white70 : Colors.black54),
                  width: 0.8,
                ),
              ),
              child: Text(
                task.scoreBadgeText,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  color: task.isCompleted ? Colors.white : Colors.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTaskDetails(BuildContext context, Task task) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  task.title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              task.description,
              style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : Colors.black54),
            ),
            const SizedBox(height: 16),
            if (task.targetValue != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Progress: ${task.currentValue}/${task.targetValue}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: task.progress,
                      minHeight: 8,
                      color: const Color(0xFF7FC86D),
                      backgroundColor: isDark ? Colors.white10 : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            if (!task.isCompleted)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    await TaskService.instance.completeTask(task.id);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7FC86D),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Mark as Complete', style: TextStyle(color: Colors.white)),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF7FC86D),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text('✓ Completed', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: ValueListenableBuilder<List<Task>>(
              valueListenable: TaskService.instance.tasksNotifier,
              builder: (_, tasks, __) => ValueListenableBuilder<int>(
                valueListenable: TaskService.instance.completedCountNotifier,
                builder: (_, completedCount, __) => ValueListenableBuilder<int>(
                  valueListenable: GamificationService.instance.sessionXpNotifier,
                  builder: (_, xp, ___) => ValueListenableBuilder<int>(
                    valueListenable: GamificationService.instance.dailyStreakNotifier,
                    builder: (_, streak, ____) {
                      final progress = tasks.isEmpty ? 0.0 : completedCount / tasks.length;

                      return Column(
                        children: [
                          // Fixed Header
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Column(
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
                                          child: Text('$completedCount/${tasks.length} done',
                                              style: const TextStyle(fontWeight: FontWeight.w600)),
                                        ),
                                      ],
                                    )
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Session XP: $xp • Streak: $streak',
                                  style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
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
                              ],
                            ),
                          ),
                          // Scrollable Task List
                          Expanded(
                            child: SingleChildScrollView(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 20),
                                    if (tasks.isEmpty)
                                      Center(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 40),
                                          child: Text(
                                            'No tasks for today',
                                            style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
                                          ),
                                        ),
                                      )
                                    else
                                      ...tasks.map((task) => Padding(
                                            padding: const EdgeInsets.only(bottom: 12),
                                            child: _taskCard(context, task),
                                          )),
                                    const SizedBox(height: 12),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

