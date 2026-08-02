import 'package:flutter/material.dart';

import '../../../services/active_child_context_service.dart';
import '../../../services/auth_session_service.dart';
import '../../../services/local_metrics_service.dart';
import '../../../services/offline_database_service.dart';
import '../../../services/offline_models.dart';
import '../../../theme/lumi_theme.dart';
import '../../../widgets/arcade/arcade.dart';
import 'charts.dart';
import 'shared_widgets.dart';

class ChildDashboardOverviewTab extends StatefulWidget {
  final int? childId;
  const ChildDashboardOverviewTab({super.key, this.childId});

  @override
  State<ChildDashboardOverviewTab> createState() => _ChildDashboardOverviewTabState();
}

class _ChildDashboardOverviewTabState extends State<ChildDashboardOverviewTab> {
  Map<String, dynamic>? _todayMetrics;
  int? _todayScore;
  bool _loading = true;
  bool _hasData = false;

  String _selectedPeriod = '7 days';
  Map<String, dynamic>? _analyticsData;
  List<CuratedMetricBatch> _batches = [];
  Map<DateTime, List<CuratedMetricBatch>> _batchesByDay = {};

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    await Future.wait([_loadTodayMetrics(), _loadAnalyticsData()]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadTodayMetrics() async {
    try {
      final childId = widget.childId ?? await ActiveChildContextService.instance.getActiveChildId();
      if (childId == null) return;

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));

      await LocalMetricsService.instance.initialize();
      final todayBatches = await OfflineDatabaseService.instance.loadBatchesForChild(childId, today, tomorrow);

      double totalScreenTime = 0;
      double totalBlinkRate = 0;
      double averageDistance = 0;
      int totalStrainEvents = 0;
      int batchCount = 0;

      for (final batch in todayBatches) {
        totalScreenTime += batch.screenTimeMinutes;
        if (batch.averageBlinkRate != null) totalBlinkRate += batch.averageBlinkRate!;
        if (batch.averageDistanceCm != null) averageDistance += batch.averageDistanceCm!;
        totalStrainEvents += batch.strainEvents;
        if (batch.averageBlinkRate != null || batch.averageDistanceCm != null) batchCount++;
      }

      final hasData = batchCount > 0;
      _todayMetrics = {
        'screen_time_minutes': totalScreenTime.toInt(),
        'avg_blink_rate': hasData ? (totalBlinkRate / batchCount).toStringAsFixed(1) : '-',
        'avg_distance': hasData ? (averageDistance / batchCount).toStringAsFixed(1) : '-',
        'strain_events': totalStrainEvents,
      };
      _todayScore = hasData ? (todayBatches.last.healthScore ?? 100) : null;
      _hasData = hasData;
    } catch (_) {}
  }

  Future<void> _loadAnalyticsData() async {
    try {
      final childId = widget.childId ?? await ActiveChildContextService.instance.getActiveChildId();
      if (childId == null) return;

      await LocalMetricsService.instance.initialize();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final startDate = switch (_selectedPeriod) {
        '30 days' => today.subtract(const Duration(days: 30)),
        '3 months' => today.subtract(const Duration(days: 90)),
        _ => today.subtract(const Duration(days: 7)),
      };

      final batches = await OfflineDatabaseService.instance.loadBatchesForChild(
        childId,
        startDate,
        today.add(const Duration(days: 1)),
      );

      final batchesByDay = <DateTime, List<CuratedMetricBatch>>{};
      for (final batch in batches) {
        final day = DateTime(batch.windowStart.year, batch.windowStart.month, batch.windowStart.day);
        batchesByDay.putIfAbsent(day, () => []).add(batch);
      }

      double totalScreenTime = 0;
      double totalBlinkRate = 0;
      double totalDistance = 0;
      int dayCount = batchesByDay.length;
      int batchCount = 0;

      for (final dayBatches in batchesByDay.values) {
        double dayBlinkRate = 0;
        int dayBatches_ = 0;
        for (final batch in dayBatches) {
          totalScreenTime += batch.screenTimeMinutes;
          if (batch.averageBlinkRate != null) {
            dayBlinkRate += batch.averageBlinkRate!;
            dayBatches_++;
          }
          if (batch.averageDistanceCm != null) totalDistance += batch.averageDistanceCm!;
        }
        if (dayBatches_ > 0) {
          totalBlinkRate += dayBlinkRate / dayBatches_;
          batchCount++;
        }
      }

      _batches = batches;
      _batchesByDay = batchesByDay;
      _analyticsData = {
        'avg_screen_time': dayCount > 0 ? (totalScreenTime / dayCount).toStringAsFixed(0) : '0',
        'avg_blink_rate': batchCount > 0 ? (totalBlinkRate / batchCount).toStringAsFixed(1) : '-',
        'avg_distance': dayCount > 0 ? (totalDistance / dayCount).toStringAsFixed(1) : '-',
      };
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: LumiColors.primaryPurple));
    }

    return RefreshIndicator(
      color: LumiColors.primaryPurple,
      onRefresh: _loadAll,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(LumiSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FutureBuilder<UserSession?>(
              future: AuthSessionService.instance.loadUserSession(),
              builder: (context, snapshot) {
                var greeting = 'Welcome back!';
                if (snapshot.hasData && snapshot.data?.guardianEmail != null) {
                  final emailName = snapshot.data!.guardianEmail!.split('@').first;
                  greeting = 'Welcome back, ${emailName.replaceAll('.', ' ')}!';
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: LumiSpacing.lg),
                  child: Text(
                    LumiTheme.caps(greeting),
                    style: LumiTheme.joyful(24, color: LumiColors.primaryPurple, height: 1.2),
                  ),
                );
              },
            ),
            ArcadeCard(
              padding: const EdgeInsets.all(LumiSpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const GuardianSectionTitle('Eye Care Score', size: 16),
                        const SizedBox(height: LumiSpacing.sm),
                        Text(
                          _hasData ? '$_todayScore/100' : '--/100',
                          style: LumiTheme.joyful(
                            34,
                            color: _hasData ? LumiColors.primaryGreen : LumiColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: LumiSpacing.xs),
                        Text(
                          "Today's summary",
                          style: LumiTheme.clanRegular(12, color: LumiColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 88,
                    height: 88,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _hasData ? LumiColors.secondaryPurple : LumiColors.secondaryLight,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _hasData ? LumiColors.primaryPurple : LumiColors.textDisabled,
                        width: ArcadeSizes.cardBorder,
                      ),
                      boxShadow: LumiShadows.card(
                        _hasData ? LumiColors.primaryPurple : LumiColors.textDisabled,
                      ),
                    ),
                    child: Text(
                      _hasData ? '$_todayScore%' : '--%',
                      style: LumiTheme.joyful(
                        22,
                        color: _hasData ? LumiColors.primaryPurple : LumiColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: LumiSpacing.lg),
            if (!_hasData)
              const EmptyDataIndicator(
                message: 'No tracking data for today yet. Make sure the child app is open and watching.',
              )
            else ...[
              MetricCard(
                icon: Icons.screen_lock_portrait,
                title: 'Screen Time',
                value: '${_todayMetrics?['screen_time_minutes']}m',
                subtitle: "Today's usage",
              ),
              const SizedBox(height: LumiSpacing.md),
              MetricCard(
                icon: Icons.auto_awesome,
                title: 'Avg Blinks',
                value: '${_todayMetrics?['avg_blink_rate']}/min',
                subtitle: "Today's usage",
              ),
              const SizedBox(height: LumiSpacing.md),
              MetricCard(
                icon: Icons.zoom_out_map,
                title: 'Distance',
                value: '${_todayMetrics?['avg_distance']}cm',
                subtitle: "Today's usage",
              ),
              const SizedBox(height: LumiSpacing.md),
              MetricCard(
                icon: Icons.warning,
                title: 'Alerts Today',
                value: '${_todayMetrics?['strain_events']}',
                subtitle: 'Gentle reminders',
              ),
            ],
            const SizedBox(height: LumiSpacing.xl),
            ArcadeCard(
              padding: const EdgeInsets.symmetric(horizontal: LumiSpacing.lg, vertical: LumiSpacing.md),
              child: Row(
                children: [
                  const Expanded(child: GuardianSectionTitle('Usage Analytics', size: 17)),
                  PopupMenuButton<String>(
                    initialValue: _selectedPeriod,
                    color: LumiColors.cardWhite,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(LumiRadii.md),
                      side: const BorderSide(color: LumiColors.primaryPurple, width: 3),
                    ),
                    onSelected: (value) async {
                      setState(() => _selectedPeriod = value);
                      await _loadAnalyticsData();
                      if (mounted) setState(() {});
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: '7 days',
                        child: Text('7 days', style: LumiTheme.clanMedium(14, color: LumiColors.textDark)),
                      ),
                      PopupMenuItem(
                        value: '30 days',
                        child: Text('30 days', style: LumiTheme.clanMedium(14, color: LumiColors.textDark)),
                      ),
                      PopupMenuItem(
                        value: '3 months',
                        child: Text('3 months', style: LumiTheme.clanMedium(14, color: LumiColors.textDark)),
                      ),
                    ],
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: LumiSpacing.md, vertical: 6),
                      decoration: BoxDecoration(
                        color: LumiColors.secondaryPurple,
                        borderRadius: BorderRadius.circular(LumiRadii.pill),
                        border: Border.all(color: LumiColors.primaryPurple, width: 3),
                        boxShadow: LumiShadows.badge(LumiColors.primaryPurple),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _selectedPeriod,
                            style: LumiTheme.clanMedium(13, color: LumiColors.primaryPurple),
                          ),
                          const Icon(Icons.arrow_drop_down, size: 18, color: LumiColors.primaryPurple),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: LumiSpacing.md),
            if (_batches.isEmpty)
              const EmptyDataIndicator(message: 'No analytical data available for this time period.')
            else ...[
              AnalyticsMetricCard(
                title: 'Avg Screen Time',
                value: _analyticsData?['avg_screen_time'] ?? '0',
                unit: 'min/day',
                change: _selectedPeriod,
              ),
              const SizedBox(height: LumiSpacing.md),
              AnalyticsMetricCard(
                title: 'Avg Blinks',
                value: _analyticsData?['avg_blink_rate'] ?? '-',
                unit: 'blinks/min',
                change: _selectedPeriod,
              ),
              const SizedBox(height: LumiSpacing.md),
              AnalyticsMetricCard(
                title: 'Avg Distance',
                value: _analyticsData?['avg_distance'] ?? '-',
                unit: 'cm',
                change: _selectedPeriod,
              ),
              const SizedBox(height: LumiSpacing.xl),
              WeeklyScreenTimeChart(batches: _batches, batchesByDay: _batchesByDay),
              const SizedBox(height: LumiSpacing.xl),
              BlinkRateTrendsChart(batches: _batches, batchesByDay: _batchesByDay),
              const SizedBox(height: LumiSpacing.xl),
              ViewingDistanceTrendsChart(batches: _batches, batchesByDay: _batchesByDay),
              const SizedBox(height: LumiSpacing.xl),
              DailyUsagePatternChart(batches: _batches, batchesByDay: _batchesByDay),
            ],
          ],
        ),
      ),
    );
  }
}
