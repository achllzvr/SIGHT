import 'package:flutter/material.dart';
import '../widgets/rounded_card.dart';
import '../services/metrics_service.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({Key? key}) : super(key: key);

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  // Example tasks (for now simple 4 tasks where first two are 20-20-20 breaks)
  final List<_TaskItem> _tasks = [
    _TaskItem('20-20-20 Break', 'Complete 1 eye break', false),
    _TaskItem('20-20-20 Break', 'Complete 1 eye break', false),
    _TaskItem('20-20-20 Break', 'Complete 1 eye break', false),
    _TaskItem('20-20-20 Break', 'Complete 1 eye break', false),
  ];

  @override
  void initState() {
    super.initState();
    // Listen to metrics and mark tasks as done when conditions are met
    MetricsService.instance.blinkRatePerMinNotifier.addListener(_onBlinkRateChanged);
    MetricsService.instance.distanceCmNotifier.addListener(_onDistanceChanged);
  }

  @override
  void dispose() {
    MetricsService.instance.blinkRatePerMinNotifier.removeListener(_onBlinkRateChanged);
    MetricsService.instance.distanceCmNotifier.removeListener(_onDistanceChanged);
    super.dispose();
  }

  void _onBlinkRateChanged() {
    final rate = MetricsService.instance.blinkRatePerMinNotifier.value;
    // if blink rate is healthy (>10) mark first two breaks as done as an example
    if (rate >= 10) {
      setState(() {
        for (int i = 0; i < _tasks.length && i < 2; i++) _tasks[i].done = true;
      });
    }
  }

  void _onDistanceChanged() {
    final d = MetricsService.instance.distanceCmNotifier.value;
    // If distance is safe (>30cm) mark next two tasks done (simple example)
    if (d >= 30.0) {
      setState(() {
        for (int i = 2; i < _tasks.length; i++) _tasks[i].done = true;
      });
    }
  }

  Widget _taskCard(BuildContext context, _TaskItem task) {
    return RoundedCard(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: task.done ? Colors.green : Colors.grey[200],
          child: task.done ? const Icon(Icons.check, color: Colors.white) : null,
        ),
        title: Text(task.title),
        subtitle: Text(task.subtitle),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.pink[50],
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text('20/20 Score'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final doneCount = _tasks.where((t) => t.done).length;
    final progress = _tasks.isEmpty ? 0.0 : doneCount / _tasks.length;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Today's Tasks", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('$doneCount/${_tasks.length} done'),
                  )
                ],
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(value: progress, minHeight: 12, color: Colors.green),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(top: 12, bottom: 24),
                  itemCount: _tasks.length,
                  itemBuilder: (_, i) {
                    final t = _tasks[i];
                    return Column(
                      children: [
                        _taskCard(context, t),
                        const SizedBox(height: 12),
                      ],
                    );
                  },
                ),
              )
            ],
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

