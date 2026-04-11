enum TaskType {
  eyeHealth, // 20-20-20 breaks, blink exercises, etc.
  gamification, // XP goals, streak maintenance
}

enum TaskStatus {
  notStarted,
  inProgress,
  completed,
}

enum TimePeriod {
  morning,   // 5:00 - 11:59
  afternoon, // 12:00 - 17:59
  evening,   // 18:00 - 23:59
}

extension TimePeriodX on TimePeriod {
  String get displayName {
    switch (this) {
      case TimePeriod.morning:
        return 'Morning Tasks';
      case TimePeriod.afternoon:
        return 'Afternoon Tasks';
      case TimePeriod.evening:
        return 'Evening Tasks';
    }
  }

  /// Determine current time period
  static TimePeriod getCurrentPeriod() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return TimePeriod.morning;
    } else if (hour < 18) {
      return TimePeriod.afternoon;
    } else {
      return TimePeriod.evening;
    }
  }

  /// Check if a task should show in given period
  static TimePeriod getTaskPeriod(String taskId) {
    if (taskId.contains('morning') || taskId.contains('blink-exercise')) {
      return TimePeriod.morning;
    } else if (taskId.contains('afternoon')) {
      return TimePeriod.afternoon;
    } else if (taskId.contains('evening')) {
      return TimePeriod.evening;
    }
    // Default: show in morning for most tasks
    return TimePeriod.morning;
  }
}

class Task {
  final String id;
  final String title;
  final String description;
  final TaskType type;
  final TaskStatus status;
  final int? targetValue; // For gamification tasks (XP target, streak target, etc.)
  final int? currentValue; // Current progress toward target
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? category; // "eye-exercise", "xp-goal", "streak", etc.
  final int? rewardXp;
  final TimePeriod timePeriod; // Morning, Afternoon, or Evening

  Task({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.status,
    this.targetValue,
    this.currentValue,
    required this.createdAt,
    this.completedAt,
    this.category,
    this.rewardXp,
    this.timePeriod = TimePeriod.morning,
  });

  bool get isCompleted => status == TaskStatus.completed;
  bool get isExpired {
    // Tasks expire at the end of the day
    final now = DateTime.now();
    return createdAt.isBefore(DateTime(now.year, now.month, now.day));
  }

  double get progress {
    if (targetValue == null || currentValue == null) {
      return isCompleted ? 1.0 : 0.0;
    }
    return (currentValue! / targetValue!).clamp(0.0, 1.0);
  }

  String get progressText {
    if (targetValue == null) return isCompleted ? '100%' : '0%';
    return '${((progress * 100).toStringAsFixed(0))}%';
  }

  String get scoreBadgeText {
    return '${rewardXp ?? 0} XP';
  }

  Task copyWith({
    String? id,
    String? title,
    String? description,
    TaskType? type,
    TaskStatus? status,
    int? targetValue,
    int? currentValue,
    DateTime? createdAt,
    DateTime? completedAt,
    String? category,
    int? rewardXp,
    TimePeriod? timePeriod,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      status: status ?? this.status,
      targetValue: targetValue ?? this.targetValue,
      currentValue: currentValue ?? this.currentValue,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      category: category ?? this.category,
      rewardXp: rewardXp ?? this.rewardXp,
      timePeriod: timePeriod ?? this.timePeriod,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'type': type.name,
    'status': status.name,
    'targetValue': targetValue,
    'currentValue': currentValue,
    'createdAt': createdAt.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
    'category': category,
    'rewardXp': rewardXp,
    'timePeriod': timePeriod.name,
  };

  factory Task.fromJson(Map<String, dynamic> json) => Task(
    id: json['id'] as String,
    title: json['title'] as String,
    description: json['description'] as String,
    type: TaskType.values.firstWhere((e) => e.name == (json['type'] as String)),
    status: TaskStatus.values.firstWhere((e) => e.name == (json['status'] as String)),
    targetValue: json['targetValue'] as int?,
    currentValue: json['currentValue'] as int?,
    createdAt: DateTime.parse(json['createdAt'] as String),
    completedAt: json['completedAt'] != null ? DateTime.parse(json['completedAt'] as String) : null,
    category: json['category'] as String?,
    rewardXp: json['rewardXp'] as int?,
    timePeriod: json['timePeriod'] != null 
      ? TimePeriod.values.firstWhere((e) => e.name == (json['timePeriod'] as String), orElse: () => TimePeriod.morning)
      : TimePeriod.morning,
  );
}
