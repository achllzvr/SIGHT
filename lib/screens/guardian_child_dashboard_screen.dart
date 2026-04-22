import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../services/active_child_context_service.dart';
import '../services/auth_session_service.dart';
import '../services/guardian_preferences_service.dart';
import '../services/offline_database_service.dart';
import '../services/local_metrics_service.dart';
import '../services/offline_models.dart';

class GuardianChildDashboardScreen extends StatefulWidget {
  final int? childId;

  const GuardianChildDashboardScreen({
    super.key,
    this.childId,
  });

  @override
  State<GuardianChildDashboardScreen> createState() => _GuardianChildDashboardScreenState();
}

class _GuardianChildDashboardScreenState extends State<GuardianChildDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);
    
    // If childId provided, set it. Otherwise use the active one from service
    if (widget.childId != null) {
      ActiveChildContextService.instance.setActiveChildId(widget.childId!);
    }
  }

  void _handleTabChange() {
    // Tab changed
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F11) : const Color(0xFFFAFAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF5F5F7),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Child Dashboard'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF5F5F7),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF00ACC1),
              unselectedLabelColor: isDark ? Colors.white54 : Colors.black54,
              indicatorColor: const Color(0xFF00ACC1),
              indicatorWeight: 3,
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'Analytics'),
                Tab(text: 'Controls'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          OverviewTab(childId: widget.childId),
          AnalyticsTab(childId: widget.childId),
          ControlsTab(childId: widget.childId),
        ],
      ),
    );
  }
}

// ==================== OVERVIEW TAB ====================
class OverviewTab extends StatefulWidget {
  final int? childId;

  const OverviewTab({super.key, this.childId});

  @override
  State<OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<OverviewTab> {
  Map<String, dynamic>? _todayMetrics;
  int? _todayScore;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMetrics();
  }

  Future<void> _loadMetrics() async {
    try {
      // Get active child ID
      final childId = widget.childId ?? await ActiveChildContextService.instance.getActiveChildId();
      if (childId == null) {
        throw Exception('No active child');
      }

      // Fetch today's batches from local database
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));

      await LocalMetricsService.instance.initialize();
      final todayBatches = await OfflineDatabaseService.instance.loadBatchesForChild(childId, today, tomorrow);

      // Aggregate metrics from today's batches
      double totalScreenTime = 0;
      double totalBlinkRate = 0;
      double averageDistance = 0;
      int totalStrainEvents = 0;
      int batchCount = 0;

      for (final batch in todayBatches) {
        totalScreenTime += batch.screenTimeMinutes;
        if (batch.averageBlinkRate != null) {
          totalBlinkRate += batch.averageBlinkRate!;
        }
        if (batch.averageDistanceCm != null) {
          averageDistance += batch.averageDistanceCm!;
        }
        totalStrainEvents += batch.strainEvents;
        if (batch.averageBlinkRate != null || batch.averageDistanceCm != null) {
          batchCount++;
        }
      }

      // Calculate averages
      final avgBlinkRate = batchCount > 0 ? (totalBlinkRate / batchCount).toStringAsFixed(1) : '-';
      final avgDistance = batchCount > 0 ? (averageDistance / batchCount).toStringAsFixed(1) : '-';

      final todayData = {
        'screen_time_minutes': totalScreenTime.toInt(),
        'avg_blink_rate': avgBlinkRate,
        'avg_distance': avgDistance,
        'strain_events': totalStrainEvents,
      };

      // Score calculation: based on screen time, blink rate, distance, and strain events
      // This would normally come from the backend API
      int score = 100;
      if (totalScreenTime > 120) score -= 10;
      if (totalScreenTime > 180) score -= 10;
      if (totalBlinkRate / (batchCount > 0 ? batchCount : 1) < 10) score -= 15;
      if (avgDistance.split('.')[0] != '-' && double.parse(avgDistance) < 30) score -= 10;
      if (totalStrainEvents > 3) score -= (totalStrainEvents - 3) * 5;
      score = (score).clamp(0, 100);

      if (mounted) {
        setState(() {
          _todayMetrics = todayData;
          _todayScore = score;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading metrics: $e');
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Welcome Greeting
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: FutureBuilder<UserSession?>(
              future: AuthSessionService.instance.loadUserSession(),
              builder: (context, snapshot) {
                String greeting = 'Welcome back! 👋';
                if (snapshot.hasData && snapshot.data != null) {
                  final session = snapshot.data!;
                  if (session.guardianEmail != null && session.guardianEmail!.isNotEmpty) {
                    final emailName = session.guardianEmail!.split('@').first;
                    greeting = 'Welcome back, ${emailName.replaceAll('.', ' ')}! 👋';
                  }
                }
                return Text(
                  greeting,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                );
              },
            ),
          ),
          // Eye Health Score Card
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.black.withOpacity(0.08),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Overall Eye Health Score',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_todayScore ?? 78}/100',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00ACC1),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Good, but room for improvement',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 100,
                  height: 100,
                  decoration: const BoxDecoration(
                    color: Color(0xFFB9E3A4),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${_todayScore ?? 78}%',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Metrics Grid
          _MetricCard(
            isDark: isDark,
            icon: Icons.screen_lock_portrait,
            title: 'Screen Time',
            value: '${_todayMetrics?['screen_time_minutes'] ?? 145}m',
            subtitle: "Today's usage",
          ),
          const SizedBox(height: 12),
          _MetricCard(
            isDark: isDark,
            icon: Icons.auto_awesome,
            title: 'Avg Blink Rate',
            value: '${_todayMetrics?['avg_blink_rate'] ?? '14'}/min',
            subtitle: "Today's usage",
          ),
          const SizedBox(height: 12),
          _MetricCard(
            isDark: isDark,
            icon: Icons.zoom_out_map,
            title: 'Viewing Distance',
            value: '${_todayMetrics?['avg_distance'] ?? '42'}cm',
            subtitle: "Today's usage",
          ),
          const SizedBox(height: 12),
          _MetricCard(
            isDark: isDark,
            icon: Icons.warning,
            title: 'Alerts Today',
            value: '${_todayMetrics?['strain_events'] ?? 3}',
            subtitle: 'Strain events',
          ),
          const SizedBox(height: 20),

          // 20-20-20 Break Compliance
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.black.withOpacity(0.08),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '20-20-20 Break Compliance',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Breaks Completed',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: LinearProgressIndicator(
                    value: 0.5,
                    minHeight: 8,
                    backgroundColor: isDark ? const Color(0xFF2A2A2C) : const Color(0xFFEEEEF0),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFFB9E3A4),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFB9E3A4).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: const Text(
                    'Good adherence to break schedule',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFFB9E3A4),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Recent Activity
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.black.withOpacity(0.08),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Recent Activity',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _ActivityItem(
                  isDark: isDark,
                  icon: Icons.check_circle,
                  title: 'Completed 20-20-20 break',
                  time: '2:45 PM',
                  iconColor: Colors.green,
                ),
                const SizedBox(height: 12),
                _ActivityItem(
                  isDark: isDark,
                  icon: Icons.check_circle,
                  title: 'Completed 20-20-20 break',
                  time: '2:45 PM',
                  iconColor: Colors.green,
                ),
                const SizedBox(height: 12),
                _ActivityItem(
                  isDark: isDark,
                  icon: Icons.check_circle,
                  title: 'Completed 20-20-20 break',
                  time: '2:45 PM',
                  iconColor: Colors.yellow,
                ),
                const SizedBox(height: 12),
                _ActivityItem(
                  isDark: isDark,
                  icon: Icons.check_circle,
                  title: 'Completed 20-20-20 break',
                  time: '2:45 PM',
                  iconColor: Colors.red,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Recommendations
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFE3F2FD),
              borderRadius: BorderRadius.circular(18),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Recommendations',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1976D2),
                  ),
                ),
                const SizedBox(height: 12),
                _RecommendationItem(
                  text: 'Encourage more frequent breaks during afternoon sessions',
                ),
                const SizedBox(height: 8),
                _RecommendationItem(
                  text: 'Monitor ink rate during gaming - detected reduction to 8/min',
                ),
                const SizedBox(height: 8),
                _RecommendationItem(
                  text: 'Consider scheduling an eye check-up (last visit: 4 months ago)',
                ),
                const SizedBox(height: 8),
                _RecommendationItem(
                  text: 'Enable stricter distance alerts for evening usage',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== ANALYTICS TAB ====================
class AnalyticsTab extends StatefulWidget {
  final int? childId;

  const AnalyticsTab({super.key, this.childId});

  @override
  State<AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends State<AnalyticsTab> {
  String _selectedPeriod = '7 days';
  Map<String, dynamic>? _analyticsData;
  List<CuratedMetricBatch> _batches = [];
  Map<DateTime, List<CuratedMetricBatch>> _batchesByDay = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAnalyticsData();
  }

  Future<void> _loadAnalyticsData() async {
    try {
      final childId = widget.childId ?? await ActiveChildContextService.instance.getActiveChildId();
      if (childId == null) throw Exception('No active child');

      await LocalMetricsService.instance.initialize();
      
      // Determine date range based on selected period
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      DateTime startDate;

      switch (_selectedPeriod) {
        case '7 days':
          startDate = today.subtract(const Duration(days: 7));
          break;
        case '30 days':
          startDate = today.subtract(const Duration(days: 30));
          break;
        case '3 months':
          startDate = today.subtract(const Duration(days: 90));
          break;
        default:
          startDate = today.subtract(const Duration(days: 7));
      }

      final endDate = today.add(const Duration(days: 1));

      // Fetch batches for the period
      final batches = await OfflineDatabaseService.instance.loadBatchesForChild(childId, startDate, endDate);

      // Aggregate data
      double totalScreenTime = 0;
      double totalBlinkRate = 0;
      double totalDistance = 0;
      int dayCount = 0;
      int batchCount = 0;

      // Calculate by day to get daily averages
      final batchesByDay = <DateTime, List<CuratedMetricBatch>>{};
      for (final batch in batches) {
        final day = DateTime(batch.windowStart.year, batch.windowStart.month, batch.windowStart.day);
        batchesByDay.putIfAbsent(day, () => []).add(batch);
      }

      dayCount = batchesByDay.length;

      for (final dayBatches in batchesByDay.values) {
        double dayScreenTime = 0;
        double dayBlinkRate = 0;
        double dayDistance = 0;
        int dayBatches_ = 0;

        for (final batch in dayBatches) {
          dayScreenTime += batch.screenTimeMinutes;
          if (batch.averageBlinkRate != null) {
            dayBlinkRate += batch.averageBlinkRate!;
            dayBatches_++;
          }
          if (batch.averageDistanceCm != null) {
            dayDistance += batch.averageDistanceCm!;
          }
        }

        totalScreenTime += dayScreenTime;
        if (dayBatches_ > 0) {
          totalBlinkRate += (dayBlinkRate / dayBatches_);
          batchCount++;
        }
        totalDistance += dayDistance;
      }

      final avgScreenTime = dayCount > 0 ? (totalScreenTime / dayCount).toStringAsFixed(0) : '0';
      final avgBlinkRate = batchCount > 0 ? (totalBlinkRate / batchCount).toStringAsFixed(1) : '-';
      final avgDistance = dayCount > 0 && batchesByDay.isNotEmpty ? (totalDistance / (batchesByDay.values.length)).toStringAsFixed(1) : '-';

      if (mounted) {
        setState(() {
          _batches = batches;
          _batchesByDay = batchesByDay;
          _analyticsData = {
            'avg_screen_time': avgScreenTime,
            'avg_blink_rate': avgBlinkRate,
            'avg_distance': avgDistance,
            'batch_count': batchCount,
          };
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading analytics: $e');
      if (mounted) {
        setState(() {
          _analyticsData = null;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Period Selector
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.black.withOpacity(0.08),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Usage Analytics',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                PopupMenuButton<String>(
                  initialValue: _selectedPeriod,
                  onSelected: (value) {
                    setState(() => _selectedPeriod = value);
                    _loadAnalyticsData();
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: '7 days', child: Text('7 days')),
                    const PopupMenuItem(value: '30 days', child: Text('30 days')),
                    const PopupMenuItem(value: '3 months', child: Text('3 months')),
                  ],
                  child: Row(
                    children: [
                      Text(_selectedPeriod),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Usage Stats
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else ...[
            _AnalyticsMetricCard(
              isDark: isDark,
              title: 'Avg Screen Time',
              value: _analyticsData?['avg_screen_time'] ?? '0',
              unit: 'min/day',
              change: _selectedPeriod,
              changeType: 'neutral',
            ),
            const SizedBox(height: 12),
            _AnalyticsMetricCard(
              isDark: isDark,
              title: 'Avg Blink Rate',
              value: _analyticsData?['avg_blink_rate'] ?? '-',
              unit: 'blinks/min',
              change: _selectedPeriod,
              changeType: 'neutral',
            ),
            const SizedBox(height: 12),
            _AnalyticsMetricCard(
              isDark: isDark,
              title: 'Avg Distance',
              value: _analyticsData?['avg_distance'] ?? '-',
              unit: 'cm',
              change: _selectedPeriod,
              changeType: 'neutral',
            ),
            const SizedBox(height: 20),
          ],

          // Charts section
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.black.withOpacity(0.08),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Weekly Screen Time',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                if (_batches.isNotEmpty)
                  SizedBox(
                    height: 180,
                    child: WeeklyScreenTimeChart(
                      batches: _batches,
                      batchesByDay: _batchesByDay,
                    ),
                  )
                else
                  SizedBox(
                    height: 150,
                    child: Center(
                      child: Text(
                        'No data available',
                        style: TextStyle(
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Blink Rate Trends
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.black.withOpacity(0.08),
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Blink Rate Trends',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                if (_batches.isNotEmpty)
                  SizedBox(
                    height: 180,
                    child: BlinkRateTrendsChart(
                      batches: _batches,
                      batchesByDay: _batchesByDay,
                    ),
                  )
                else
                  SizedBox(
                    height: 150,
                    child: Center(
                      child: Text(
                        'No data available',
                        style: TextStyle(
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Viewing Distance Trends
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.black.withOpacity(0.08),
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Viewing Distance Trends',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                if (_batches.isNotEmpty)
                  SizedBox(
                    height: 180,
                    child: ViewingDistanceTrendsChart(
                      batches: _batches,
                      batchesByDay: _batchesByDay,
                    ),
                  )
                else
                  SizedBox(
                    height: 150,
                    child: Center(
                      child: Text(
                        'No data available',
                        style: TextStyle(
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Daily Usage Pattern
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.black.withOpacity(0.08),
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Daily Usage Pattern (Today)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                if (_batches.isNotEmpty)
                  SizedBox(
                    height: 180,
                    child: DailyUsagePatternChart(
                      batches: _batches,
                      batchesByDay: _batchesByDay,
                    ),
                  )
                else
                  SizedBox(
                    height: 150,
                    child: Center(
                      child: Text(
                        'No data available',
                        style: TextStyle(
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Recommendations
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFE3F2FD),
              borderRadius: BorderRadius.circular(18),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Recommendations',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1976D2),
                  ),
                ),
                const SizedBox(height: 12),
                _RecommendationItem(
                  text: 'Peak usage occurs during 6-8 PM (average 45 min/day)',
                ),
                const SizedBox(height: 8),
                _RecommendationItem(
                  text: 'Weekend screen time 28% higher than weekdays',
                ),
                const SizedBox(height: 8),
                _RecommendationItem(
                  text: 'Blink rate consistently drops during afternoon sessions',
                ),
                const SizedBox(height: 8),
                _RecommendationItem(
                  text: 'Completed 71% of recommended 20-20-20 breaks this week',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== CONTROLS TAB ====================
class ControlsTab extends StatefulWidget {
  final int? childId;

  const ControlsTab({super.key, this.childId});

  @override
  State<ControlsTab> createState() => _ControlsTabState();
}

class _ControlsTabState extends State<ControlsTab> {
  late GuardianPreferences _preferences;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await GuardianPreferencesService.instance.loadPreferences();
      if (mounted) {
        setState(() {
          _preferences = prefs;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading preferences: $e');
      if (mounted) {
        setState(() {
          _preferences = const GuardianPreferences.defaults();
          _loading = false;
        });
      }
    }
  }

  Future<void> _savePreferences() async {
    setState(() => _saving = true);

    try {
      await GuardianPreferencesService.instance.savePreferences(_preferences);
      await GuardianPreferencesService.instance.pushSessionLimitsToServer(_preferences);

      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved and synced')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Screen Time Limits - SINGLE SLIDER
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.black.withOpacity(0.08),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Screen Time Limits',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${_preferences.dailyScreenLimitMinutes} min',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF00ACC1),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Daily Screen Time Limit',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 16),
                Slider(
                  value: _preferences.dailyScreenLimitMinutes.toDouble(),
                  min: 30,
                  max: 240,
                  divisions: 21,
                  onChanged: (value) {
                    setState(() {
                      _preferences = _preferences.copyWith(
                        dailyScreenLimitMinutes: value.toInt(),
                      );
                    });
                  },
                  label: '${_preferences.dailyScreenLimitMinutes} min',
                  activeColor: const Color(0xFF00ACC1),
                  inactiveColor: isDark
                      ? Colors.white12
                      : Colors.black.withOpacity(0.1),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '30 min',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                    Text(
                      '240 min',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Monitoring Settings
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.black.withOpacity(0.08),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Monitoring Settings',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _ModeButton(
                      label: 'Relaxed',
                      isSelected: _preferences.monitoringMode == 'Relaxed',
                      onTap: () {
                        setState(() {
                          _preferences = _preferences.copyWith(
                            monitoringMode: 'Relaxed',
                          );
                        });
                      },
                      subtitle: 'Fewer alerts\nfor older kids',
                    ),
                    const SizedBox(width: 12),
                    _ModeButton(
                      label: 'Moderate',
                      isSelected: _preferences.monitoringMode == 'Moderate',
                      onTap: () {
                        setState(() {
                          _preferences = _preferences.copyWith(
                            monitoringMode: 'Moderate',
                          );
                        });
                      },
                      subtitle: 'Balanced\napproach',
                    ),
                    const SizedBox(width: 12),
                    _ModeButton(
                      label: 'Strict',
                      isSelected: _preferences.monitoringMode == 'Strict',
                      onTap: () {
                        setState(() {
                          _preferences = _preferences.copyWith(
                            monitoringMode: 'Strict',
                          );
                        });
                      },
                      subtitle: 'Strict for\nmyopia',
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _ToggleSetting(
                  isDark: isDark,
                  title: 'Auto-Enforce Breaks',
                  subtitle: 'Force 20-20-20 breaks (locks screen)',
                  value: _preferences.autoEnforceBreaks,
                  onChanged: (value) {
                    setState(() {
                      _preferences = _preferences.copyWith(autoEnforceBreaks: value);
                    });
                  },
                ),
                const SizedBox(height: 16),
                _ToggleSetting(
                  isDark: isDark,
                  title: 'Weekend Relaxed Mode',
                  subtitle: 'Less strict limits on Saturdays & Sundays',
                  value: _preferences.weekendRelaxedMode,
                  onChanged: (value) {
                    setState(() {
                      _preferences = _preferences.copyWith(weekendRelaxedMode: value);
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Alert Thresholds
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.black.withOpacity(0.08),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Alert Thresholds',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                // Distance Threshold
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Distance Alert Threshold (cm)',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                        Text(
                          '${_preferences.distanceAlertThresholdCm.toStringAsFixed(0)}cm',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF00ACC1),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Alert when viewing closer than this distance',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Slider(
                      value: _preferences.distanceAlertThresholdCm,
                      min: 20,
                      max: 50,
                      onChanged: (value) {
                        setState(() {
                          _preferences = _preferences.copyWith(
                            distanceAlertThresholdCm: value,
                          );
                        });
                      },
                      activeColor: const Color(0xFF00ACC1),
                      inactiveColor: isDark
                          ? Colors.white12
                          : Colors.black.withOpacity(0.1),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '20cm',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                        ),
                        Text(
                          '50cm',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Blink Rate Threshold
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Blink Rate Alert Threshold (blinks/min)',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                        Text(
                          '${_preferences.blinkRateAlertThresholdPerMin}/min',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF00ACC1),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Alert when blinking less than this rate',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Slider(
                      value: _preferences.blinkRateAlertThresholdPerMin.toDouble(),
                      min: 5,
                      max: 15,
                      divisions: 10,
                      onChanged: (value) {
                        setState(() {
                          _preferences = _preferences.copyWith(
                            blinkRateAlertThresholdPerMin: value.toInt(),
                          );
                        });
                      },
                      activeColor: const Color(0xFF00ACC1),
                      inactiveColor: isDark
                          ? Colors.white12
                          : Colors.black.withOpacity(0.1),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '5/min',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                        ),
                        Text(
                          '15/min',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Additional Settings
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.black.withOpacity(0.08),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Additional Settings',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _ToggleSetting(
                  isDark: isDark,
                  title: 'Parent Notifications',
                  subtitle: 'Get alerts for concerning eye health events',
                  value: _preferences.parentNotificationsEnabled,
                  onChanged: (value) {
                    setState(() {
                      _preferences = _preferences.copyWith(
                        parentNotificationsEnabled: value,
                      );
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Save Button
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _saving ? null : _savePreferences,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00ACC1),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                disabledBackgroundColor: const Color(0xFF00ACC1).withOpacity(0.5),
              ),
              child: _saving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'Save Settings',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ==================== WIDGETS ====================

class _MetricCard extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;

  const _MetricCard({
    required this.isDark,
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black.withOpacity(0.08),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFB9E3A4),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
              ],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF00ACC1),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final String title;
  final String time;
  final Color iconColor;

  const _ActivityItem({
    required this.isDark,
    required this.icon,
    required this.title,
    required this.time,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          time,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white54 : Colors.black45,
          ),
        ),
      ],
    );
  }
}

class _RecommendationItem extends StatelessWidget {
  final String text;

  const _RecommendationItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '•  ',
          style: TextStyle(
            fontSize: 16,
            color: Color(0xFF1976D2),
            fontWeight: FontWeight.bold,
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF1565C0),
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _AnalyticsMetricCard extends StatelessWidget {
  final bool isDark;
  final String title;
  final String value;
  final String unit;
  final String change;
  final String changeType;

  const _AnalyticsMetricCard({
    required this.isDark,
    required this.title,
    required this.value,
    required this.unit,
    required this.change,
    required this.changeType,
  });

  @override
  Widget build(BuildContext context) {
    final changeColor = changeType == 'increase'
        ? Colors.red
        : changeType == 'decrease'
            ? Colors.green
            : Colors.orange;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black.withOpacity(0.08),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00BCD4),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    unit,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                change,
                style: TextStyle(
                  fontSize: 12,
                  color: changeColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final String subtitle;

  const _ModeButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF00ACC1).withOpacity(0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF00ACC1)
                  : Colors.grey.withOpacity(0.3),
              width: isSelected ? 2 : 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? const Color(0xFF00ACC1)
                      : Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToggleSetting extends StatelessWidget {
  final bool isDark;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleSetting({
    required this.isDark,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: const Color(0xFF00ACC1),
        ),
      ],
    );
  }
}

// ==================== CHART WIDGETS ====================

/// Weekly Screen Time Bar Chart
/// Displays Actual Usage (blue) vs Recommended (green) for each day of the week
class WeeklyScreenTimeChart extends StatelessWidget {
  final List<CuratedMetricBatch> batches;
  final Map<DateTime, List<CuratedMetricBatch>> batchesByDay;

  const WeeklyScreenTimeChart({
    super.key,
    required this.batches,
    required this.batchesByDay,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Build 7-day data starting from 6 days ago
    final chartData = <({int dayIndex, String label, int actualMinutes, int recommendedMinutes})>[];
    const recommendedMinutes = 110;

    for (int i = 6; i >= 0; i--) {
      final dayDate = today.subtract(Duration(days: i));
      final batchesForDay = batchesByDay[dayDate] ?? [];
      final totalScreenTime = batchesForDay.fold<int>(0, (sum, b) => sum + b.screenTimeMinutes);

      chartData.add((
        dayIndex: i,
        label: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][dayDate.weekday % 7],
        actualMinutes: totalScreenTime,
        recommendedMinutes: recommendedMinutes,
      ));
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black.withOpacity(0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Weekly Screen Time',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Actual vs Recommended Usage',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 200,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) =>
                        isDark ? const Color(0xFF2A2A2C) : Colors.grey[800]!,
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}m',
                          style: TextStyle(
                            fontSize: 10,
                            color:
                                isDark ? Colors.white38 : Colors.black38,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          chartData[value.toInt()].label,
                          style: TextStyle(
                            fontSize: 10,
                            color:
                                isDark ? Colors.white54 : Colors.black54,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 50,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1),
                      strokeWidth: 1,
                    );
                  },
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(
                  chartData.length,
                  (index) => BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: chartData[index].actualMinutes.toDouble(),
                        color: const Color(0xFF007AFF),
                        width: 8,
                        borderRadius: const BorderRadius.all(Radius.circular(4)),
                      ),
                      BarChartRodData(
                        toY: chartData[index].recommendedMinutes.toDouble(),
                        color: const Color(0xFF34C759),
                        width: 8,
                        borderRadius: const BorderRadius.all(Radius.circular(4)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: const Color(0xFF007AFF),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              const Text('Actual Usage', style: TextStyle(fontSize: 12)),
              const SizedBox(width: 20),
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: const Color(0xFF34C759),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              const Text('Recommended', style: TextStyle(fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Blink Rate Trends Line Chart
/// Shows daily average blink rates with warning banner if below 15/min threshold
class BlinkRateTrendsChart extends StatelessWidget {
  final List<CuratedMetricBatch> batches;
  final Map<DateTime, List<CuratedMetricBatch>> batchesByDay;

  const BlinkRateTrendsChart({
    super.key,
    required this.batches,
    required this.batchesByDay,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    const blinkThreshold = 15.0;

    // Build 7-day data
    final chartData = <({int dayIndex, String label, double blinkRate})>[];
    bool hasWarning = false;

    for (int i = 6; i >= 0; i--) {
      final dayDate = today.subtract(Duration(days: i));
      final batchesForDay = batchesByDay[dayDate] ?? [];

      double totalBlinkRate = 0;
      int count = 0;
      for (final batch in batchesForDay) {
        if (batch.averageBlinkRate != null) {
          totalBlinkRate += batch.averageBlinkRate!;
          count++;
        }
      }

      final avgBlinkRate = count > 0 ? totalBlinkRate / count : 0.0;
      if (avgBlinkRate < blinkThreshold && avgBlinkRate > 0) {
        hasWarning = true;
      }

      chartData.add((
        dayIndex: i,
        label: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][dayDate.weekday % 7],
        blinkRate: avgBlinkRate,
      ));
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black.withOpacity(0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Blink Rate Trends',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Daily average blinks per minute',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
          if (hasWarning) ...[
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFF3B30).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFFF3B30).withOpacity(0.3),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_rounded,
                    size: 16,
                    color: Color(0xFFFF3B30),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Blink rate below healthy threshold (15/min)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFFFF3B30),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                maxY: 25,
                minY: 0,
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) =>
                        isDark ? const Color(0xFF2A2A2C) : Colors.grey[800]!,
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}',
                          style: TextStyle(
                            fontSize: 10,
                            color:
                                isDark ? Colors.white38 : Colors.black38,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          chartData[value.toInt()].label,
                          style: TextStyle(
                            fontSize: 10,
                            color:
                                isDark ? Colors.white54 : Colors.black54,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 5,
                  getDrawingHorizontalLine: (value) {
                    if (value == blinkThreshold) {
                      return FlLine(
                        color: const Color(0xFFFF3B30).withOpacity(0.3),
                        strokeWidth: 2,
                        dashArray: [5, 5],
                      );
                    }
                    return FlLine(
                      color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1),
                      strokeWidth: 1,
                    );
                  },
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(
                      chartData.length,
                      (i) => FlSpot(i.toDouble(), chartData[i].blinkRate),
                    ),
                    isCurved: true,
                    color: const Color(0xFF00ACC1),
                    barWidth: 3,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 5,
                          color: const Color(0xFF00ACC1),
                          strokeWidth: 2,
                          strokeColor: isDark
                              ? const Color(0xFF2A2A2C)
                              : Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF00ACC1).withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Viewing Distance Trends Line Chart
/// Shows daily average viewing distances with warning banner if below 40cm threshold
class ViewingDistanceTrendsChart extends StatelessWidget {
  final List<CuratedMetricBatch> batches;
  final Map<DateTime, List<CuratedMetricBatch>> batchesByDay;

  const ViewingDistanceTrendsChart({
    super.key,
    required this.batches,
    required this.batchesByDay,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    const distanceThreshold = 40.0;

    // Build 7-day data
    final chartData = <({int dayIndex, String label, double distance})>[];
    bool hasWarning = false;

    for (int i = 6; i >= 0; i--) {
      final dayDate = today.subtract(Duration(days: i));
      final batchesForDay = batchesByDay[dayDate] ?? [];

      double totalDistance = 0;
      int count = 0;
      for (final batch in batchesForDay) {
        if (batch.averageDistanceCm != null) {
          totalDistance += batch.averageDistanceCm!;
          count++;
        }
      }

      final avgDistance = count > 0 ? totalDistance / count : 0.0;
      if (avgDistance < distanceThreshold && avgDistance > 0) {
        hasWarning = true;
      }

      chartData.add((
        dayIndex: i,
        label: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][dayDate.weekday % 7],
        distance: avgDistance,
      ));
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black.withOpacity(0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Viewing Distance Trends',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Daily average distance in centimeters',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
          if (hasWarning) ...[
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFF3B30).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFFF3B30).withOpacity(0.3),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_rounded,
                    size: 16,
                    color: Color(0xFFFF3B30),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Viewing distance too close (below 40cm)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFFFF3B30),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                maxY: 80,
                minY: 0,
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) =>
                        isDark ? const Color(0xFF2A2A2C) : Colors.grey[800]!,
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}cm',
                          style: TextStyle(
                            fontSize: 10,
                            color:
                                isDark ? Colors.white38 : Colors.black38,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          chartData[value.toInt()].label,
                          style: TextStyle(
                            fontSize: 10,
                            color:
                                isDark ? Colors.white54 : Colors.black54,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 10,
                  getDrawingHorizontalLine: (value) {
                    if (value == distanceThreshold) {
                      return FlLine(
                        color: const Color(0xFFFF3B30).withOpacity(0.3),
                        strokeWidth: 2,
                        dashArray: [5, 5],
                      );
                    }
                    return FlLine(
                      color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1),
                      strokeWidth: 1,
                    );
                  },
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(
                      chartData.length,
                      (i) => FlSpot(i.toDouble(), chartData[i].distance),
                    ),
                    isCurved: true,
                    color: const Color(0xFF34C759),
                    barWidth: 3,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 5,
                          color: const Color(0xFF34C759),
                          strokeWidth: 2,
                          strokeColor: isDark
                              ? const Color(0xFF2A2A2C)
                              : Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF34C759).withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Daily Usage Pattern Bar Chart
/// Shows hourly breakdown for today (2-hour intervals from 8AM to 8PM)
class DailyUsagePatternChart extends StatelessWidget {
  final List<CuratedMetricBatch> batches;
  final Map<DateTime, List<CuratedMetricBatch>> batchesByDay;

  const DailyUsagePatternChart({
    super.key,
    required this.batches,
    required this.batchesByDay,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Build hourly data for today (8AM to 8PM)
    final chartData = <({int hour, String label, int screenTimeMinutes})>[];
    final todayBatches = batchesByDay[today] ?? [];

    final hourBlockLabels = [
      (hour: 8, label: '8AM'),
      (hour: 10, label: '10AM'),
      (hour: 12, label: '12PM'),
      (hour: 14, label: '2PM'),
      (hour: 16, label: '4PM'),
      (hour: 18, label: '6PM'),
      (hour: 20, label: '8PM'),
    ];

    for (final timeSlot in hourBlockLabels) {
      final blockStart = DateTime(today.year, today.month, today.day, timeSlot.hour);
      final blockEnd = blockStart.add(const Duration(hours: 2));

      int totalScreenTime = 0;
      for (final batch in todayBatches) {
        if (batch.windowStart.isBefore(blockEnd) && batch.windowEnd.isAfter(blockStart)) {
          totalScreenTime += batch.screenTimeMinutes;
        }
      }

      chartData.add((
        hour: timeSlot.hour,
        label: timeSlot.label,
        screenTimeMinutes: totalScreenTime,
      ));
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black.withOpacity(0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Today\'s Usage Pattern',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Screen time by 2-hour blocks',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 60,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) =>
                        isDark ? const Color(0xFF2A2A2C) : Colors.grey[800]!,
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}m',
                          style: TextStyle(
                            fontSize: 10,
                            color:
                                isDark ? Colors.white38 : Colors.black38,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          chartData[value.toInt()].label,
                          style: TextStyle(
                            fontSize: 10,
                            color:
                                isDark ? Colors.white54 : Colors.black54,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 10,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1),
                      strokeWidth: 1,
                    );
                  },
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(
                  chartData.length,
                  (index) => BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: chartData[index].screenTimeMinutes.toDouble(),
                        color: const Color(0xFF007AFF),
                        width: 14,
                        borderRadius: const BorderRadius.all(Radius.circular(4)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: const Color(0xFF007AFF),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              const Text('Screen Time (minutes)', style: TextStyle(fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}
