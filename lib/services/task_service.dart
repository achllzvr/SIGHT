import 'dart:async';
import 'package:flutter/foundation.dart';
import 'task_models.dart';
import 'gamification_service.dart';
import 'feedback_service.dart';

class TaskService {
  TaskService._private();
  static final TaskService instance = TaskService._private();

  final ValueNotifier<List<Task>> tasksNotifier = ValueNotifier<List<Task>>([]);
  final ValueNotifier<int> completedCountNotifier = ValueNotifier<int>(0);

  bool _initialized = false;
  Timer? _dailyResetTimer;
  Timer? _periodicUpdateTimer;

  static const _blinkTaskId = 'blink-exercise';
  static const _eyeBreakTaskId = 'eye-break-afternoon';
  static const _healthyDistanceTaskId = 'healthy-distance-session';

  /// Core daily eye-health goals — completing all three advances the streak.
  static const coreDailyGoalIds = [
    _blinkTaskId,
    _eyeBreakTaskId,
    _healthyDistanceTaskId,
  ];

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    await GamificationService.instance.initialize();

    _initialized = true;
    await _generateDailyTasks();
    _setupListeners();
    _startTimers();

    // Credit safe-distance minutes from the gamification minute flush.
    GamificationService.instance.onSafeViewingMinute = recordSafeViewingMinute;

    if (kDebugMode) {
      debugPrint('[TaskService] Initialized with ${tasksNotifier.value.length} daily tasks');
    }
  }

  void _setupListeners() {
    // Listen to gamification changes to update task progress
    GamificationService.instance.coinsNotifier.addListener(_onXpChanged);
    GamificationService.instance.dailyStreakNotifier.addListener(_onStreakChanged);
  }

  void _startTimers() {
    // Reset tasks daily at midnight
    _setupDailyResetTimer();

    // Update task progress every 2 seconds
    _periodicUpdateTimer?.cancel();
    _periodicUpdateTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _updateTaskProgress();
    });
  }

  void _setupDailyResetTimer() {
    _dailyResetTimer?.cancel();
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final durationUntilMidnight = tomorrow.difference(now);

    _dailyResetTimer = Timer(durationUntilMidnight, () {
      _generateDailyTasks();
      _setupDailyResetTimer(); // Reschedule for next day
    });
  }

  Future<void> _generateDailyTasks() async {
    final newTasks = <Task>[];
    final now = DateTime.now();

    // Daily goals: eye health + gamification (prescriptions removed — use clinician share)
    newTasks.addAll(_generateEyeHealthTasks(now));
    newTasks.addAll(_generateGamificationTasks(now));

    tasksNotifier.value = newTasks;
    _updateCompletedCount();
  }

  List<Task> _generateEyeHealthTasks(DateTime now) {
    return [
      Task(
        id: _blinkTaskId,
        title: 'Blink with Lumi',
        description: 'Blink 15 times to help your eyes.',
        type: TaskType.eyeHealth,
        status: TaskStatus.notStarted,
        category: 'eye-exercise',
        rewardHealth: 10,
        createdAt: now,
        timePeriod: TimePeriod.daily,
      ),
      Task(
        id: _eyeBreakTaskId,
        title: 'Eye Rest Break',
        description: 'Look far away for 20 seconds for a short break.',
        type: TaskType.eyeHealth,
        status: TaskStatus.notStarted,
        category: 'eye-exercise',
        rewardHealth: 10,
        createdAt: now,
        timePeriod: TimePeriod.daily,
      ),
      Task(
        id: _healthyDistanceTaskId,
        title: 'Keep a Safe Distance',
        description: 'Stay farther than 30 cm from the screen for 10 minutes.',
        type: TaskType.eyeHealth,
        status: TaskStatus.notStarted,
        targetValue: 10, // 10 minutes
        currentValue: 0,
        category: 'eye-exercise',
        rewardHealth: 15,
        createdAt: now,
        timePeriod: TimePeriod.daily,
      ),
    ];
  }

  List<Task> _generateGamificationTasks(DateTime now) {
    final currentCoins = GamificationService.instance.coinsNotifier.value;
    final currentStreak = GamificationService.instance.dailyStreakNotifier.value;

    return [
      Task(
        id: 'coin-goal-easy',
        title: 'Earn 25 Stars',
        description: 'Keep it up with good eye habits to earn 25 Stars',
        type: TaskType.gamification,
        status: currentCoins >= 25 ? TaskStatus.completed : TaskStatus.inProgress,
        targetValue: 25,
        currentValue: currentCoins,
        category: 'coin-goal',
        rewardCoins: 25,
        createdAt: now,
        completedAt: currentCoins >= 25 ? now : null,
        timePeriod: TimePeriod.daily,
      ),
      Task(
        id: 'coin-goal-medium',
        title: 'Earn 50 Stars',
        description: 'Keep up good habits to earn 50 Stars',
        type: TaskType.gamification,
        status: currentCoins >= 50 ? TaskStatus.completed : TaskStatus.inProgress,
        targetValue: 50,
        currentValue: currentCoins,
        category: 'coin-goal',
        rewardCoins: 50,
        createdAt: now,
        completedAt: currentCoins >= 50 ? now : null,
        timePeriod: TimePeriod.daily,
      ),
      Task(
        id: 'streak-goal',
        title: 'Keep a 3-Day Streak',
        description: 'Keep your good habits going for 3 days',
        type: TaskType.gamification,
        status: currentStreak >= 3 ? TaskStatus.completed : TaskStatus.inProgress,
        targetValue: 3,
        currentValue: currentStreak,
        category: 'streak',
        rewardCoins: 30,
        createdAt: now,
        completedAt: currentStreak >= 3 ? now : null,
        timePeriod: TimePeriod.daily,
      ),
    ];
  }

  void _onXpChanged() {
    _updateTaskProgress();
  }

  void _onStreakChanged() {
    _updateTaskProgress();
  }

  void _updateTaskProgress() {
    final currentXp = GamificationService.instance.coinsNotifier.value;
    final currentStreak = GamificationService.instance.dailyStreakNotifier.value;

    final updatedTasks = tasksNotifier.value.map((task) {
      if (task.isCompleted) return task;

      // Update XP goal tasks
      if (task.category == 'coin-goal') {
        final isNowCompleted = currentXp >= (task.targetValue ?? 0);
        if (isNowCompleted && task.status != TaskStatus.completed) {
          FeedbackService.instance.taskCompleted();
          return task.copyWith(
            status: TaskStatus.completed,
            currentValue: currentXp,
            completedAt: DateTime.now(),
          );
        }
        return task.copyWith(currentValue: currentXp);
      }

      // Update streak goal tasks
      if (task.category == 'streak') {
        final isNowCompleted = currentStreak >= (task.targetValue ?? 0);
        if (isNowCompleted && task.status != TaskStatus.completed) {
          FeedbackService.instance.taskCompleted();
          return task.copyWith(
            status: TaskStatus.completed,
            currentValue: currentStreak,
            completedAt: DateTime.now(),
          );
        }
        return task.copyWith(currentValue: currentStreak);
      }

      return task;
    }).toList();

    tasksNotifier.value = updatedTasks;
    _updateCompletedCount();
  }

  void _updateCompletedCount() {
    final completed = tasksNotifier.value.where((t) => t.isCompleted).length;
    completedCountNotifier.value = completed;
    _evaluateDailyGoalStreak();
  }

  void _evaluateDailyGoalStreak() {
    final coreTasks =
        tasksNotifier.value.where((t) => coreDailyGoalIds.contains(t.id)).toList();
    if (coreTasks.length < GamificationService.dailyGoalCountForStreak) return;
    final allCoreDone = coreTasks.every((t) => t.isCompleted);
    unawaited(GamificationService.instance.evaluateDailyStreak(dailyGoalMet: allCoreDone));
  }

  /// Mark blink / eye-break / other tasks done. When [grantRewards] is false,
  /// HP/Stars were already applied by the activity (avoids double-counting).
  Future<void> completeTask(String taskId, {bool grantRewards = true}) async {
    await initialize();

    final tasks = List<Task>.from(tasksNotifier.value);
    final taskIndex = tasks.indexWhere((t) => t.id == taskId);
    if (taskIndex == -1) return;

    final task = tasks[taskIndex];
    if (task.isCompleted) return;

    if (grantRewards) {
      if (task.rewardHealth != null && task.rewardHealth! > 0) {
        await GamificationService.instance.applyHealthDelta(task.rewardHealth!);
      }
      if (task.rewardCoins != null && task.rewardCoins! > 0) {
        await GamificationService.instance.applyCoinsDelta(task.rewardCoins!);
      }
    }

    tasks[taskIndex] = task.copyWith(
      status: TaskStatus.completed,
      currentValue: task.targetValue ?? task.currentValue,
      completedAt: DateTime.now(),
    );
    tasksNotifier.value = tasks;
    _updateCompletedCount();
    await FeedbackService.instance.taskCompleted();
  }

  /// Called after blink game success — restores HP and marks the blink task done.
  Future<void> onBlinkExerciseFinished() async {
    await initialize();
    await GamificationService.instance.recordBlinkExerciseCompleted();
    await completeTask(_blinkTaskId, grantRewards: false);
  }

  /// Called after 20-20-20 success — restores HP and marks the eye-rest task done.
  Future<void> onEyeBreakFinished() async {
    await initialize();
    await GamificationService.instance.recordBreakCompleted202020();
    await completeTask(_eyeBreakTaskId, grantRewards: false);
  }

  /// One safe Watch-Area minute (≥30 cm). Completes after 10 minutes with +15 HP.
  Future<void> recordSafeViewingMinute() async {
    await initialize();

    final tasks = List<Task>.from(tasksNotifier.value);
    final taskIndex = tasks.indexWhere((t) => t.id == _healthyDistanceTaskId);
    if (taskIndex == -1) return;

    final task = tasks[taskIndex];
    if (task.isCompleted) return;

    final target = task.targetValue ?? 10;
    final next = (task.currentValue ?? 0) + 1;

    if (next >= target) {
      if (task.rewardHealth != null && task.rewardHealth! > 0) {
        await GamificationService.instance.applyHealthDelta(task.rewardHealth!);
      }
      tasks[taskIndex] = task.copyWith(
        status: TaskStatus.completed,
        currentValue: target,
        completedAt: DateTime.now(),
      );
      tasksNotifier.value = tasks;
      _updateCompletedCount();
      await FeedbackService.instance.taskCompleted();
      return;
    }

    tasks[taskIndex] = task.copyWith(
      status: TaskStatus.inProgress,
      currentValue: next,
    );
    tasksNotifier.value = tasks;
  }

  /// Get tasks for the current day
  List<Task> getDailyTasks() {
    return tasksNotifier.value;
  }

  /// Get completed tasks count
  int getCompletedCount() {
    return completedCountNotifier.value;
  }

  /// Get total tasks count
  int getTotalCount() {
    return tasksNotifier.value.length;
  }

  /// Get tasks by type
  List<Task> getTasksByType(TaskType type) {
    return tasksNotifier.value.where((t) => t.type == type).toList();
  }

  /// Get tasks by category
  List<Task> getTasksByCategory(String category) {
    return tasksNotifier.value.where((t) => t.category == category).toList();
  }

  void dispose() {
    _dailyResetTimer?.cancel();
    _periodicUpdateTimer?.cancel();
    if (GamificationService.instance.onSafeViewingMinute == recordSafeViewingMinute) {
      GamificationService.instance.onSafeViewingMinute = null;
    }
    GamificationService.instance.coinsNotifier.removeListener(_onXpChanged);
    GamificationService.instance.dailyStreakNotifier.removeListener(_onStreakChanged);
    _initialized = false;
  }
}
