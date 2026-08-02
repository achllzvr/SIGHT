import 'package:flutter/material.dart';

import '../blink_test_screen.dart';
import '../services/gamification_service.dart';
import '../services/task_service.dart';
import '../services/task_models.dart';
import '../theme/lumi_theme.dart';
import '../widgets/arcade/arcade.dart';
import 'guardian/child_dashboard/shared_widgets.dart';

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

  Widget _taskCard(BuildContext context, Task task, {required bool isLast}) {
    final scoreLabel = task.scoreBadgeText;

    return ArcadeCard(
      margin: EdgeInsets.only(
        // Leave room for the hard card shadow so neighbors don't look stacked.
        bottom: isLast ? ArcadeSizes.cardShadowY : LumiSpacing.md + ArcadeSizes.cardShadowY,
      ),
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

  Widget _buildStreakDisplay(BuildContext context, int streak) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showStreakCalendar(context, streak),
        borderRadius: BorderRadius.circular(LumiRadii.pill),
        child: Ink(
          decoration: BoxDecoration(
            color: LumiColors.tipYellow,
            borderRadius: BorderRadius.circular(LumiRadii.pill),
            border: Border.all(color: LumiColors.badgeAmber, width: 2),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.local_fire_department_rounded, size: 16, color: LumiColors.badgeAmber),
                const SizedBox(width: 4),
                Text(
                  '$streak day${streak == 1 ? '' : 's'}',
                  style: LumiTheme.clanMedium(11, color: LumiColors.textDark),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showStreakCalendar(BuildContext context, int streak) {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Container(
          margin: const EdgeInsets.all(LumiSpacing.lg),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          decoration: BoxDecoration(
            color: LumiColors.primaryLight,
            borderRadius: BorderRadius.circular(ArcadeSizes.cardRadius),
            border: Border.all(color: LumiColors.secondaryLight, width: ArcadeSizes.cardBorder),
            boxShadow: LumiShadows.modal(),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        LumiTheme.caps('Your Streak'),
                        style: LumiTheme.joyful(22, color: LumiColors.primaryPurple),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close_rounded, color: LumiColors.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: LumiSpacing.lg),
                Column(
                  children: [
                    const Icon(
                      Icons.local_fire_department_rounded,
                      size: 48,
                      color: LumiColors.badgeAmber,
                    ),
                    const SizedBox(height: LumiSpacing.sm),
                    Text(
                      '$streak',
                      style: LumiTheme.joyful(40, color: LumiColors.badgeAmber),
                    ),
                    Text(
                      'day${streak == 1 ? '' : 's'} in a row',
                      style: LumiTheme.clanRegular(14, color: LumiColors.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: LumiSpacing.xl),
                ArcadeCard(
                  padding: const EdgeInsets.all(LumiSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        LumiTheme.caps('Last 28 Days'),
                        style: LumiTheme.clanMedium(12, color: LumiColors.textMuted),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Filled days are part of your current streak.',
                        style: LumiTheme.clanRegular(12, color: LumiColors.textMuted),
                      ),
                      const SizedBox(height: LumiSpacing.md),
                      GridView.count(
                        crossAxisCount: 7,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 6,
                        crossAxisSpacing: 6,
                        children: List.generate(28, (index) {
                          final daysAgo = 27 - index;
                          final day = todayOnly.subtract(Duration(days: daysAgo));
                          final isStreakDay = streak > 0 && daysAgo < streak;
                          final isToday = daysAgo == 0;

                          return Tooltip(
                            message: formatReadableDate(day),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isStreakDay
                                    ? LumiColors.primaryGreen
                                    : LumiColors.scaffoldMint,
                                borderRadius: BorderRadius.circular(LumiRadii.sm),
                                border: Border.all(
                                  color: isToday
                                      ? LumiColors.primaryPurple
                                      : (isStreakDay
                                          ? LumiColors.primaryGreen
                                          : LumiColors.outline),
                                  width: isToday ? 2.5 : 1.5,
                                ),
                              ),
                              child: Center(
                                child: isStreakDay
                                    ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                                    : Text(
                                        '${day.day}',
                                        style: LumiTheme.clanMedium(
                                          10,
                                          color: LumiColors.textMuted,
                                        ),
                                      ),
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: LumiSpacing.md),
                      Row(
                        children: [
                          _LegendDot(color: LumiColors.primaryGreen, label: 'Streak day'),
                          const SizedBox(width: LumiSpacing.md),
                          _LegendDot(color: LumiColors.scaffoldMint, label: 'Other day', outlined: true),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: LumiSpacing.lg),
                ArcadeButton(
                  text: 'CLOSE',
                  onTap: () => Navigator.pop(sheetContext),
                  variant: ArcadeButtonVariant.outline,
                ),
              ],
            ),
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
                builder: (_, completedCount, __) => ValueListenableBuilder<int>(
                  valueListenable: GamificationService.instance.dailyStreakNotifier,
                  builder: (_, streak, ___) {
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
                            const SizedBox(height: LumiSpacing.sm),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Tap your streak to view the calendar',
                                    style: LumiTheme.clanRegular(12, color: LumiColors.textMuted),
                                  ),
                                ),
                                _buildStreakDisplay(context, streak),
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
                              ...tasks.asMap().entries.map(
                                    (entry) => _taskCard(
                                      context,
                                      entry.value,
                                      isLast: entry.key == tasks.length - 1,
                                    ),
                                  ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  final bool outlined;

  const _LegendDot({
    required this.color,
    required this.label,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: outlined ? LumiColors.outline : color,
              width: 1.5,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: LumiTheme.clanRegular(11, color: LumiColors.textMuted)),
      ],
    );
  }
}
