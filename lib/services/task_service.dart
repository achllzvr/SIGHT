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

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    await GamificationService.instance.initialize();
    
    _initialized = true;
    _generateDailyTasks();
    _setupListeners();
    _startTimers();

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

  void _generateDailyTasks() {
    final newTasks = <Task>[];
    final now = DateTime.now();

    // Eye Health Tasks
    newTasks.addAll(_generateEyeHealthTasks(now));

    // Gamification Challenge Tasks
    newTasks.addAll(_generateGamificationTasks(now));

    tasksNotifier.value = newTasks;
    _updateCompletedCount();

    if (kDebugMode) {
      debugPrint('[TaskService] Generated ${newTasks.length} daily tasks');
    }
  }

  List<Task> _generateEyeHealthTasks(DateTime now) {
    return [
      Task(
        id: 'eye-break-morning',
        title: '20-20-20 Morning Break',
        description: 'Complete 1 eye break by looking 20 feet away for 20 seconds',
        type: TaskType.eyeHealth,
        status: TaskStatus.notStarted,
        category: 'eye-exercise',
        rewardXp: 10,
        createdAt: now,
        timePeriod: TimePeriod.morning,
      ),
      Task(
        id: 'blink-exercise',
        title: 'Blink Exercise',
        description: 'Complete 15 consecutive blinks to reset your blink rate',
        type: TaskType.eyeHealth,
        status: TaskStatus.notStarted,
        category: 'eye-exercise',
        rewardXp: 5,
        createdAt: now,
        timePeriod: TimePeriod.morning,
      ),
      Task(
        id: 'eye-break-afternoon',
        title: '20-20-20 Afternoon Break',
        description: 'Complete 1 eye break by looking 20 feet away for 20 seconds',
        type: TaskType.eyeHealth,
        status: TaskStatus.notStarted,
        category: 'eye-exercise',
        rewardXp: 10,
        createdAt: now,
        timePeriod: TimePeriod.afternoon,
      ),
      Task(
        id: 'healthy-distance-session',
        title: 'Maintain Healthy Distance',
        description: 'Keep a safe distance (>30cm) from screen for 10 minutes',
        type: TaskType.eyeHealth,
        status: TaskStatus.notStarted,
        targetValue: 10, // 10 minutes
        currentValue: 0,
        category: 'eye-exercise',
        rewardXp: 15,
        createdAt: now,
        timePeriod: TimePeriod.afternoon,
      ),
    ];
  }

  List<Task> _generateGamificationTasks(DateTime now) {
    final currentCoins = GamificationService.instance.coinsNotifier.value; 
    final currentStreak = GamificationService.instance.dailyStreakNotifier.value;

    return [
      Task(
        id: 'coin-goal-easy',
        title: 'Earn 25 Coins',
        description: 'Maintain good eye health to earn 25 Coins',
        type: TaskType.gamification,
        status: currentCoins >= 25 ? TaskStatus.completed : TaskStatus.inProgress,
        targetValue: 25,
        currentValue: currentCoins,
        category: 'coin-goal',
        rewardXp: 25, 
        createdAt: now,
        completedAt: currentCoins >= 25 ? now : null,
        timePeriod: TimePeriod.morning,
      ),
      
      Task(
        id: 'coin-goal-medium',
        title: 'Earn 50 Coins',
        description: 'Maintain excellent compliance to earn 50 Coins',
        type: TaskType.gamification,
        status: currentCoins >= 50 ? TaskStatus.completed : TaskStatus.inProgress,
        targetValue: 50,
        currentValue: currentCoins,
        category: 'coin-goal',
        rewardXp: 50,
        createdAt: now,
        completedAt: currentCoins >= 50 ? now : null,
        timePeriod: TimePeriod.afternoon,
      ),
      
      Task(
        id: 'streak-goal',
        title: 'Maintain 3-Day Streak',
        description: 'Keep your daily compliance streak going for 3 days',
        type: TaskType.gamification,
        status: currentStreak >= 3 ? TaskStatus.completed : TaskStatus.inProgress,
        targetValue: 3,
        currentValue: currentStreak,
        category: 'streak',
        rewardXp: 30, // Can rename to rewardCoins later
        createdAt: now,
        completedAt: currentStreak >= 3 ? now : null,
        timePeriod: TimePeriod.afternoon,
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
  }

  /// Manually mark a task as completed (for manual tasks or testing)
  Future<void> completeTask(String taskId) async {
    final tasks = tasksNotifier.value;
    final taskIndex = tasks.indexWhere((t) => t.id == taskId);

    if (taskIndex != -1) {
      final task = tasks[taskIndex];
      tasks[taskIndex] = task.copyWith(
        status: TaskStatus.completed,
        currentValue: task.targetValue,
        completedAt: DateTime.now(),
      );

      tasksNotifier.value = List.from(tasks);
      _updateCompletedCount();

      // Provide haptic and audio feedback
      await FeedbackService.instance.taskCompleted();

      if (kDebugMode) {
        debugPrint('[TaskService] Completed task: $taskId');
      }
    }
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
    GamificationService.instance.coinsNotifier.removeListener(_onXpChanged);
    GamificationService.instance.dailyStreakNotifier.removeListener(_onStreakChanged);
  }
}
