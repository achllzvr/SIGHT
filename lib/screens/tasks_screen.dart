import 'package:flutter/material.dart';

import '../blink_test_screen.dart';
import '../services/task_service.dart';
import '../services/task_models.dart';
import '../theme/lumi_theme.dart';
import '../widgets/arcade/arcade.dart';

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

  Widget _taskCard(BuildContext context, Task task) {
    final scoreLabel = task.scoreBadgeText;

    return Padding(
      padding: const EdgeInsets.only(bottom: LumiSpacing.sm),
      child: ArcadeCard(
        padding: const EdgeInsets.symmetric(horizontal: LumiSpacing.md, vertical: 12),
        onTap: () => _showTaskDetails(context, task),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: task.isCompleted ? LumiColors.primaryGreen : const Color(0xFFE8F6DE),
                border: Border.all(
                  color: task.isCompleted ? LumiColors.primaryGreen : LumiColors.secondaryLight,
                  width: 2,
                ),
              ),
              child: task.isCompleted
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : null,
            ),
            const SizedBox(width: LumiSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: LumiTheme.clanMedium(15, color: LumiColors.textDark),
                  ),
                  if (task.description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      task.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: LumiTheme.clanRegular(12),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: LumiSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: task.isCompleted ? LumiColors.secondaryGreen : LumiColors.secondaryPurple,
                borderRadius: BorderRadius.circular(LumiRadii.pill),
                border: Border.all(
                  color: task.isCompleted ? LumiColors.primaryGreen : LumiColors.primaryPurple,
                  width: 2,
                ),
              ),
              child: Text(
                scoreLabel,
                style: LumiTheme.clanMedium(
                  11,
                  color: task.isCompleted ? LumiColors.primaryGreen : LumiColors.primaryPurple,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTaskDetails(BuildContext context, Task task) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          margin: const EdgeInsets.all(LumiSpacing.lg),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          decoration: BoxDecoration(
            color: LumiColors.primaryLight,
            borderRadius: BorderRadius.circular(ArcadeSizes.cardRadius),
            border: Border.all(color: LumiColors.secondaryLight, width: ArcadeSizes.cardBorder),
            boxShadow: LumiShadows.modal(),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(LumiTheme.caps(task.title), style: LumiTheme.joyful(22, color: LumiColors.textDark)),
              const SizedBox(height: LumiSpacing.sm),
              Text(task.description, style: LumiTheme.clanRegular(14)),
              const SizedBox(height: LumiSpacing.lg),
              if (task.id == 'blink-exercise' || task.title.toLowerCase().contains('blink')) ...[
                ArcadeButton(
                  text: 'START BLINK GAME',
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const BlinkTestScreen()),
                    );
                  },
                ),
                const SizedBox(height: LumiSpacing.sm),
              ],
              ArcadeButton(
                text: 'CLOSE',
                onTap: () => Navigator.pop(ctx),
                variant: ArcadeButtonVariant.outline,
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return ValueListenableBuilder<List<Task>>(
              valueListenable: TaskService.instance.tasksNotifier,
              builder: (_, tasks, __) => ValueListenableBuilder<int>(
                valueListenable: TaskService.instance.completedCountNotifier,
                builder: (_, completedCount, __) {
                  final progress = tasks.isEmpty ? 0.0 : completedCount / tasks.length;

                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      LumiSpacing.lg,
                      LumiSpacing.md,
                      LumiSpacing.lg,
                      LumiSpacing.lg,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - LumiSpacing.md - LumiSpacing.lg,
                        maxWidth: 430,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  LumiTheme.caps("Today's Tasks"),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: LumiTheme.joyful(26, color: LumiColors.textDark),
                                ),
                              ),
                              const SizedBox(width: LumiSpacing.sm),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                decoration: BoxDecoration(
                                  color: LumiColors.primaryLight,
                                  borderRadius: BorderRadius.circular(LumiRadii.pill),
                                  border: Border.all(
                                    color: LumiColors.secondaryLight,
                                    width: ArcadeSizes.badgeBorder,
                                  ),
                                ),
                                child: Text(
                                  '$completedCount/${tasks.length} done',
                                  style: LumiTheme.clanMedium(12, color: LumiColors.textDark),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: LumiSpacing.md),
                          Container(
                            height: 16,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF0EE),
                              borderRadius: BorderRadius.circular(LumiRadii.pill),
                              border: Border.all(
                                color: LumiColors.secondaryLight,
                                width: ArcadeSizes.badgeBorder,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 14,
                              color: LumiColors.primaryGreen,
                              backgroundColor: Colors.transparent,
                            ),
                          ),
                          const SizedBox(height: LumiSpacing.lg),
                          if (tasks.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: LumiSpacing.xl),
                              child: Text(
                                'No tasks for today',
                                textAlign: TextAlign.center,
                                style: LumiTheme.clanRegular(14),
                              ),
                            )
                          else
                            ...tasks.map((task) => _taskCard(context, task)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
