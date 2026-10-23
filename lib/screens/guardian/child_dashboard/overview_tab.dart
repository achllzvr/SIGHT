import 'package:flutter/material.dart';

import '../../../services/active_child_context_service.dart';
import '../../../services/auth_session_service.dart';
import '../../../services/clinical_analytics_helpers.dart';
import '../../../services/gamification_service.dart';
import '../../../services/local_metrics_service.dart';
import '../../../services/offline_database_service.dart';
import '../../../services/offline_models.dart';
import '../../../services/server_sync_service.dart';
import '../../../theme/lumi_theme.dart';
import '../../../widgets/arcade/arcade.dart';
import '../../../widgets/clinical_trend_alert_card.dart';
import '../how_lumi_works_screen.dart';
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

  String _selectedRangeApi = '7d';
  String _selectedPeriod = 'Last 7 Days';
  Map<String, dynamic>? _analyticsData;
  Map<String, dynamic>? _dashboardRemote;
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
    // Stars halt must never go stale: only a fresh remote tier >= 3 may set it.
    GamificationService.instance.haltStarEconomy = false;
    try {
      final childId = widget.childId ?? await ActiveChildContextService.instance.getActiveChildId();
      if (childId == null) return;

      final remote = await ServerSyncService.instance.fetchChildDashboard(
        childId,
        range: _selectedRangeApi,
      );
      if (remote.success && remote.data != null) {
        _dashboardRemote = remote.data;
        final usage = remote.data!['usage_threshold'];
        GamificationService.instance.haltStarEconomy =
            usage is Map && (usage['tier'] as num?) != null && ((usage['tier'] as num).toInt() >= 3);
      } else {
        _dashboardRemote = null;
        GamificationService.instance.haltStarEconomy = false;
      }

      final isSevenDays = _selectedRangeApi == '7d';

      // Non-7d ranges chart from the online DB (server series), not local SQLite.
      if (!isSevenDays) {
        _batches = [];
        _batchesByDay = {};
        final d = _dashboardRemote;
        String fmt(dynamic v, {int dp = 1}) =>
            v is num ? v.toStringAsFixed(dp) : '-';
        _analyticsData = {
          'avg_screen_time': fmt(d?['mean_screen_time_minutes'], dp: 0) == '-' ? '0' : fmt(d?['mean_screen_time_minutes'], dp: 0),
          'avg_blink_rate': fmt(d?['mean_blink_rate']),
          'avg_distance': fmt(d?['mean_distance_cm']),
        };
        return;
      }

      await LocalMetricsService.instance.initialize();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final startDate = today.subtract(ClinicalAnalyticsHelpers.lookbackForRange(_selectedRangeApi));

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
    } catch (_) {
      GamificationService.instance.haltStarEconomy = false;
    }
  }

  Map<String, dynamic>? get _remoteSeries {
    final s = _dashboardRemote?['series'];
    return s is Map ? Map<String, dynamic>.from(s) : null;
  }

  bool get _hasChartData =>
      _selectedRangeApi == '7d' ? _batches.isNotEmpty : (_remoteSeries?['labels'] as List?)?.isNotEmpty == true;

  int get _recommendedMinutes =>
      (_dashboardRemote?['age_max_minutes'] as num?)?.toInt() ?? 120;

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
                  Tooltip(
                    message: 'How LUMI measures distance, blinks, and screen time',
                    child: IconButton(
                      icon: const Icon(Icons.info_outline, color: LumiColors.primaryPurple),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const HowLumiWorksScreen()),
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    initialValue: _selectedRangeApi,
                    color: LumiColors.cardWhite,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(LumiRadii.md),
                      side: const BorderSide(color: LumiColors.primaryPurple, width: 3),
                    ),
                    onSelected: (value) async {
                      final opt = ClinicalAnalyticsHelpers.rangeOptions
                          .firstWhere((o) => o.api == value, orElse: () => ClinicalAnalyticsHelpers.rangeOptions.first);
                      setState(() {
                        _selectedRangeApi = opt.api;
                        _selectedPeriod = opt.label;
                      });
                      await _loadAnalyticsData();
                      if (mounted) setState(() {});
                    },
                    itemBuilder: (context) => [
                      for (final opt in ClinicalAnalyticsHelpers.rangeOptions)
                        PopupMenuItem(
                          value: opt.api,
                          child: Text(opt.label, style: LumiTheme.clanMedium(14, color: LumiColors.textDark)),
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
            ClinicalTrendAlertCard(
              alert: _dashboardRemote?['clinical_trend_alert'] is Map
                  ? Map<String, dynamic>.from(_dashboardRemote!['clinical_trend_alert'] as Map)
                  : null,
              usageThreshold: _dashboardRemote?['usage_threshold'] is Map
                  ? Map<String, dynamic>.from(_dashboardRemote!['usage_threshold'] as Map)
                  : null,
              opi: _dashboardRemote?['ocular_protection_index'] is Map
                  ? Map<String, dynamic>.from(_dashboardRemote!['ocular_protection_index'] as Map)
                  : null,
              childId: widget.childId,
            ),
            const SizedBox(height: LumiSpacing.md),
            if (!_hasChartData)
              const EmptyDataIndicator(message: 'No eye-care data for this time period yet.')
            else ...[
              Tooltip(
                message: 'Average Watch time per day in $_selectedPeriod. Shorter is gentler for young eyes.',
                child: AnalyticsMetricCard(
                  title: 'Avg Screen Time',
                  value: _analyticsData?['avg_screen_time'] ?? '0',
                  unit: 'min/day',
                  change: _selectedPeriod,
                ),
              ),
              const SizedBox(height: LumiSpacing.md),
              Tooltip(
                message: 'Blinking keeps eyes moist. Around 12 or more per minute is comfy.',
                child: AnalyticsMetricCard(
                  title: 'Avg Blinks',
                  value: _analyticsData?['avg_blink_rate'] ?? '-',
                  unit: 'blinks/min',
                  change: _selectedPeriod,
                ),
              ),
              const SizedBox(height: LumiSpacing.md),
              Tooltip(
                message: 'About an arm\'s length (30 cm or more) is the comfy zone.',
                child: AnalyticsMetricCard(
                  title: 'Avg Distance',
                  value: _analyticsData?['avg_distance'] ?? '-',
                  unit: 'cm',
                  change: _selectedPeriod,
                ),
              ),
              const SizedBox(height: LumiSpacing.xl),
              if (_selectedRangeApi == '7d') ...[
                WeeklyScreenTimeChart(
                  batches: _batches,
                  batchesByDay: _batchesByDay,
                  recommendedMinutes: _recommendedMinutes,
                  rangeLabel: _selectedPeriod,
                ),
                const SizedBox(height: LumiSpacing.xl),
                BlinkRateTrendsChart(batches: _batches, batchesByDay: _batchesByDay),
                const SizedBox(height: LumiSpacing.xl),
                ViewingDistanceTrendsChart(batches: _batches, batchesByDay: _batchesByDay),
                const SizedBox(height: LumiSpacing.xl),
                DailyUsagePatternChart(batches: _batches, batchesByDay: _batchesByDay),
              ] else ...[
                SeriesScreenTimeChart(series: _remoteSeries!, rangeLabel: _selectedPeriod, recommendedMinutes: _recommendedMinutes),
                const SizedBox(height: LumiSpacing.xl),
                SeriesBlinkChart(series: _remoteSeries!, rangeLabel: _selectedPeriod),
                const SizedBox(height: LumiSpacing.xl),
                SeriesDistanceChart(series: _remoteSeries!, rangeLabel: _selectedPeriod),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
