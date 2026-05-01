import 'package:flutter/material.dart';

import '../blink_test_screen.dart';
import '../services/gamification_service.dart';
import '../services/task_service.dart';
import '../services/task_models.dart';
import '../widgets/rounded_card.dart';


class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

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

  /// Build task list grouped by time period with separators
  List<Widget> _buildGroupedTasks(BuildContext context, List<Task> tasks) {
    final List<Widget> widgets = [];
    
    // Group tasks by time period
    final Map<TimePeriod, List<Task>> groupedTasks = {};
    for (final task in tasks) {
      if (!groupedTasks.containsKey(task.timePeriod)) {
        groupedTasks[task.timePeriod] = [];
      }
      groupedTasks[task.timePeriod]!.add(task);
    }

    // Display groups in order: Morning, Afternoon, Evening
    final periods = [TimePeriod.morning, TimePeriod.afternoon, TimePeriod.evening];
    
    for (final period in periods) {
      final periodTasks = groupedTasks[period];
      if (periodTasks == null || periodTasks.isEmpty) {
        continue; // Skip if no tasks for this period
      }

      // Add separator header
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                period.displayName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF7FC86D),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );

      // Add tasks for this period
      for (final task in periodTasks) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _taskCard(context, task),
        ));
      }
    }

    return widgets;
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
                    if (task.id == 'blink-exercise') {
                      // Launch Blink Exercise with task completion
                      if (!context.mounted) return;
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => BlinkTestScreen(
                            enforceCompletion: false,
                            requiredIntentionalBlinks: 15,
                            taskIdToComplete: task.id,
                          ),
                        ),
                      );
                      if (!context.mounted) return;
                      Navigator.pop(context); // Close task details modal
                    } else {
                      // For other tasks, just mark as complete
                      await TaskService.instance.completeTask(task.id);
                      if (!context.mounted) return;
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7FC86D),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    task.id == 'blink-exercise' ? 'Start Blink Exercise' : 'Mark as Complete',
                    style: const TextStyle(color: Colors.white),
                  ),
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

  Widget _buildStreakDisplay(BuildContext context, int streak, bool isDark) {
    return GestureDetector(
      onTap: () => _showStreakCalendar(context, streak, isDark),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFFF6B6B).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFF6B6B), width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🔥', style: TextStyle(fontSize: 14)),
            const SizedBox(width: 4),
            Text(
              '$streak days',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFFF6B6B)),
            ),
          ],
        ),
      ),
    );
  }

  void _showStreakCalendar(BuildContext context, int streak, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Your Streak',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Center(
              child: Column(
                children: [
                  const Text('🔥', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  Text(
                    '$streak',
                    style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Color(0xFFFF6B6B)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'day${streak == 1 ? '' : 's'} in a row',
                    style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : Colors.black54),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Last 30 Days Activity',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black54),
                  ),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 7,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                    children: List.generate(28, (index) {
                      final daysAgo = 27 - index;
                      final isRecent = daysAgo <= streak;
                      return Container(
                        decoration: BoxDecoration(
                          color: isRecent ? const Color(0xFF7FC86D) : (isDark ? Colors.white10 : Colors.white),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isRecent ? const Color(0xFF7FC86D) : (isDark ? Colors.white24 : Colors.black12),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            isRecent ? '✓' : '',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          ),
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
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "Today's XP: $xp",
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black54),
                                    ),
                                    _buildStreakDisplay(context, streak, isDark),
                                  ],
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
                                      ..._buildGroupedTasks(context, tasks),
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

