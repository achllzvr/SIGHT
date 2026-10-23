import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../services/offline_models.dart';
import '../../../theme/lumi_theme.dart';
import '../../../widgets/rounded_card.dart';

/// Weekly Screen Time Bar Chart
/// Displays Actual Usage (blue) vs Recommended (green) for each day of the week
class WeeklyScreenTimeChart extends StatelessWidget {
  final List<CuratedMetricBatch> batches;
  final Map<DateTime, List<CuratedMetricBatch>> batchesByDay;
  final int recommendedMinutes;
  final String rangeLabel;

  const WeeklyScreenTimeChart({
    super.key,
    required this.batches,
    required this.batchesByDay,
    this.recommendedMinutes = 120,
    this.rangeLabel = 'Last 7 Days',
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Build 7-day data starting from 6 days ago (local SQLite path, 7d only)
    final chartData = <({int dayIndex, String label, int actualMinutes, int recommendedMinutes})>[];

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

    return RoundedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Screen Time — $rangeLabel',
            style: const TextStyle(fontSize: 16, height: 24 / 16, fontWeight: FontWeight.w600, color: LumiColors.textDark),
          ),
          const SizedBox(height: LumiSpacing.sm),
          Text(
            'Actual vs Recommended Usage ($recommendedMinutes min/day for this age)',
            style: const TextStyle(fontSize: 12, color: LumiColors.textMuted),
          ),
          const SizedBox(height: LumiSpacing.lg),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 200,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => LumiColors.textDark,
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}m',
                          style: const TextStyle(fontSize: 10, color: LumiColors.textMuted),
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
                          style: const TextStyle(fontSize: 10, color: LumiColors.textMuted),
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
                    return const FlLine(
                      color: LumiColors.outline,
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
                        color: LumiColors.purpleMid,
                        width: 8,
                        borderRadius: const BorderRadius.all(Radius.circular(LumiRadii.sm)),
                      ),
                      BarChartRodData(
                        toY: chartData[index].recommendedMinutes.toDouble(),
                        color: LumiColors.greenMid,
                        width: 8,
                        borderRadius: const BorderRadius.all(Radius.circular(LumiRadii.sm)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: LumiSpacing.lg),
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: LumiColors.purpleMid,
                  borderRadius: BorderRadius.circular(LumiRadii.sm),
                ),
              ),
              const SizedBox(width: LumiSpacing.md),
              const Text('Actual Usage', style: TextStyle(fontSize: 12, height: 16 / 12, color: LumiColors.textMuted)),
              const SizedBox(width: LumiSpacing.xl),
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: LumiColors.greenMid,
                  borderRadius: BorderRadius.circular(LumiRadii.sm),
                ),
              ),
              const SizedBox(width: LumiSpacing.md),
              const Text('Recommended', style: TextStyle(fontSize: 12, height: 16 / 12, color: LumiColors.textMuted)),
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

    return RoundedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Blink Trends',
            style: TextStyle(fontSize: 16, height: 24 / 16, fontWeight: FontWeight.w600, color: LumiColors.textDark),
          ),
          const SizedBox(height: LumiSpacing.sm),
          const Text(
            'Daily average blinks',
            style: TextStyle(fontSize: 12, color: LumiColors.textMuted),
          ),
          Builder(
            builder: (context) {
              final rates = chartData.map((e) => e.blinkRate).where((r) => r > 0).toList();
              if (rates.isEmpty) return const SizedBox.shrink();
              final avg = rates.reduce((a, b) => a + b) / rates.length;
              // Ousler OPI live badge (TBUT≈6s): Levels 1–4 tear-film risk.
              final ibi = 60.0 / avg;
              final opi = 6.0 / ibi;
              final level = avg >= 12 && opi >= 1.2
                  ? 1
                  : avg >= 10 && opi >= 1.0
                      ? 2
                      : avg >= 6 && opi >= 0.6
                          ? 3
                          : 4;
              final label = switch (level) {
                1 => 'Eyes look comfortable',
                2 => 'Blinking a bit less than ideal',
                3 => 'Eyes may feel dry — more blinks help',
                _ => 'Eyes need a break — try the blink game',
              };
              return Padding(
                padding: const EdgeInsets.only(top: LumiSpacing.sm),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(LumiSpacing.md),
                  decoration: BoxDecoration(
                    color: LumiColors.secondaryLight,
                    borderRadius: BorderRadius.circular(LumiRadii.md),
                    border: Border.all(color: LumiColors.outline, width: 2),
                  ),
                  child: Text(
                    'Blink comfort · Level $level — $label',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: LumiColors.textDark),
                  ),
                ),
              );
            },
          ),
          if (hasWarning) ...[
            const SizedBox(height: LumiSpacing.md),
            Container(
              decoration: BoxDecoration(
                color: LumiColors.pinkUnsafe,
                borderRadius: BorderRadius.circular(LumiRadii.lg),
                border: Border.all(
                  color: LumiColors.redAlert.withValues(alpha: 0.3),
                  width: 1,
                ),
                boxShadow: LumiShadows.card(LumiColors.shadowFor(LumiColors.pinkUnsafe)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: LumiSpacing.md, vertical: LumiSpacing.md),
              child: const Row(
                children: [
                  Icon(
                    Icons.warning_rounded,
                    size: 16,
                    color: LumiColors.redAlert,
                  ),
                  SizedBox(width: LumiSpacing.md),
                  Expanded(
                    child: Text(
                      'Blink rate below healthy threshold (15/min)',
                      style: TextStyle(
                        fontSize: 12,
                        color: LumiColors.redAlert,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: LumiSpacing.lg),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                maxY: 25,
                minY: 0,
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => LumiColors.textDark,
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
                          style: const TextStyle(fontSize: 10, color: LumiColors.textMuted),
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
                          style: const TextStyle(fontSize: 10, color: LumiColors.textMuted),
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
                        color: LumiColors.redAlert.withValues(alpha: 0.3),
                        strokeWidth: 2,
                        dashArray: [5, 5],
                      );
                    }
                    return const FlLine(
                      color: LumiColors.outline,
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
                    color: LumiColors.greenMid,
                    barWidth: 3,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 5,
                          color: LumiColors.greenMid,
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: LumiColors.greenMid.withValues(alpha: 0.1),
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
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    const distanceThreshold = 30.0;

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

    return RoundedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Viewing Distance Trends',
            style: TextStyle(fontSize: 16, height: 24 / 16, fontWeight: FontWeight.w600, color: LumiColors.textDark),
          ),
          const SizedBox(height: LumiSpacing.sm),
          const Text(
            'Daily average distance in centimeters',
            style: TextStyle(fontSize: 12, color: LumiColors.textMuted),
          ),
          if (hasWarning) ...[
            const SizedBox(height: LumiSpacing.md),
            Container(
              decoration: BoxDecoration(
                color: LumiColors.pinkUnsafe,
                borderRadius: BorderRadius.circular(LumiRadii.lg),
                border: Border.all(
                  color: LumiColors.redAlert.withValues(alpha: 0.3),
                  width: 1,
                ),
                boxShadow: LumiShadows.card(LumiColors.shadowFor(LumiColors.pinkUnsafe)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: LumiSpacing.md, vertical: LumiSpacing.md),
              child: const Row(
                children: [
                  Icon(
                    Icons.warning_rounded,
                    size: 16,
                    color: LumiColors.redAlert,
                  ),
                  SizedBox(width: LumiSpacing.md),
                  Expanded(
                    child: Text(
                      'Viewing distance in harmful zone (below 30 cm)',
                      style: TextStyle(
                        fontSize: 12,
                        color: LumiColors.redAlert,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: LumiSpacing.lg),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                maxY: 80,
                minY: 0,
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => LumiColors.textDark,
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
                          style: const TextStyle(fontSize: 10, color: LumiColors.textMuted),
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
                          style: const TextStyle(fontSize: 10, color: LumiColors.textMuted),
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
                        color: LumiColors.redAlert.withValues(alpha: 0.3),
                        strokeWidth: 2,
                        dashArray: [5, 5],
                      );
                    }
                    return const FlLine(
                      color: LumiColors.outline,
                      strokeWidth: 1,
                    );
                  },
                ),
                borderData: FlBorderData(show: false),
                rangeAnnotations: RangeAnnotations(
                  horizontalRangeAnnotations: [
                    HorizontalRangeAnnotation(
                      y1: 0,
                      y2: distanceThreshold,
                      color: LumiColors.redAlert.withValues(alpha: 0.12),
                    ),
                  ],
                ),
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                      y: distanceThreshold,
                      color: LumiColors.redAlert,
                      strokeWidth: 2,
                      dashArray: [6, 4],
                      label: HorizontalLineLabel(
                        show: true,
                        alignment: Alignment.topRight,
                        style: const TextStyle(
                          fontSize: 10,
                          color: LumiColors.redAlert,
                          fontWeight: FontWeight.w700,
                        ),
                        labelResolver: (_) => '30 cm harmful',
                      ),
                    ),
                  ],
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(
                      chartData.length,
                      (i) => FlSpot(i.toDouble(), chartData[i].distance),
                    ),
                    isCurved: true,
                    color: LumiColors.greenMid,
                    barWidth: 3,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 5,
                          color: LumiColors.greenMid,
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: LumiColors.greenMid.withValues(alpha: 0.1),
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

  double _axisInterval(double maxY) {
    if (maxY <= 15) return 5;
    if (maxY <= 30) return 5;
    if (maxY <= 60) return 10;
    if (maxY <= 90) return 15;
    if (maxY <= 120) return 20;
    return (maxY / 4).ceilToDouble().clamp(10, 60);
  }

  @override
  Widget build(BuildContext context) {
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

    // Scale the Y-axis to today's peak block so bars never overflow the chart.
    final dataMax = chartData.fold<int>(
      0,
      (max, d) => d.screenTimeMinutes > max ? d.screenTimeMinutes : max,
    );
    final maxY = (dataMax <= 0 ? 60 : dataMax).toDouble();
    final interval = _axisInterval(maxY);

    return RoundedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Today's Usage Pattern",
            style: TextStyle(fontSize: 16, height: 24 / 16, fontWeight: FontWeight.w600, color: LumiColors.textDark),
          ),
          const SizedBox(height: LumiSpacing.sm),
          const Text(
            'Screen time by 2-hour blocks',
            style: TextStyle(fontSize: 12, color: LumiColors.textMuted),
          ),
          const SizedBox(height: LumiSpacing.lg),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                minY: 0,
                maxY: maxY,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => LumiColors.textDark,
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
                      interval: interval,
                      getTitlesWidget: (value, meta) {
                        if (value < 0 || value > maxY + 0.001) {
                          return const SizedBox.shrink();
                        }
                        return Text(
                          '${value.round()}m',
                          style: const TextStyle(fontSize: 10, color: LumiColors.textMuted),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= chartData.length) {
                          return const SizedBox.shrink();
                        }
                        return Text(
                          chartData[index].label,
                          style: const TextStyle(fontSize: 10, color: LumiColors.textMuted),
                        );
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: interval,
                  getDrawingHorizontalLine: (value) {
                    return const FlLine(
                      color: LumiColors.outline,
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
                        toY: chartData[index].screenTimeMinutes.toDouble().clamp(0, maxY),
                        color: LumiColors.purpleMid,
                        width: 14,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(LumiRadii.sm)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: LumiSpacing.lg),
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: LumiColors.purpleMid,
                  borderRadius: BorderRadius.circular(LumiRadii.sm),
                ),
              ),
              const SizedBox(width: LumiSpacing.md),
              const Text('Screen Time (minutes)', style: TextStyle(fontSize: 12, height: 16 / 12, color: LumiColors.textMuted)),
            ],
          ),
        ],
      ),
    );
  }
}
/// Online-DB series charts for non-7d ranges (server-bucketed labels/values).
List<String> _seriesLabels(Map<String, dynamic> s) =>
    ((s['labels'] as List?) ?? []).map((e) => e.toString()).toList();

List<double?> _seriesValues(Map<String, dynamic> s, String key) =>
    ((s[key] as List?) ?? []).map((e) => e is num ? e.toDouble() : null).toList();

class _SeriesLineChart extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<String> labels;
  final List<double?> values;
  final Color color;
  final String unit;
  final double? threshold;

  const _SeriesLineChart({
    required this.title,
    required this.subtitle,
    required this.labels,
    required this.values,
    required this.color,
    required this.unit,
    this.threshold,
  });

  @override
  Widget build(BuildContext context) {
    final nums = values.whereType<double>().toList();
    final maxV = nums.isEmpty ? 10.0 : nums.reduce((a, b) => a > b ? a : b);
    final maxY = (maxV * 1.25).clamp(10.0, 10000.0);
    return RoundedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, height: 24 / 16, fontWeight: FontWeight.w600, color: LumiColors.textDark)),
          const SizedBox(height: LumiSpacing.sm),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: LumiColors.textMuted)),
          const SizedBox(height: LumiSpacing.lg),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: maxY.toDouble(),
                lineTouchData: LineTouchData(enabled: true, touchTooltipData: LineTouchTooltipData(getTooltipColor: (_) => LumiColors.textDark)),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (v, _) => Text('${v.toInt()}$unit', style: const TextStyle(fontSize: 10, color: LumiColors.textMuted)))),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, _) {
                    final i = v.toInt();
                    if (i < 0 || i >= labels.length) return const SizedBox.shrink();
                    // Thin out crowded bucket labels.
                    if (labels.length > 8 && i % 2 != 0) return const SizedBox.shrink();
                    return Text(labels[i], style: const TextStyle(fontSize: 9, color: LumiColors.textMuted));
                  })),
                ),
                gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => v == threshold ? FlLine(color: LumiColors.redAlert.withValues(alpha: 0.3), strokeWidth: 2, dashArray: [5, 5]) : const FlLine(color: LumiColors.outline, strokeWidth: 1)),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: [for (var i = 0; i < values.length; i++) if (values[i] != null) FlSpot(i.toDouble(), values[i]!)],
                    isCurved: true,
                    color: color,
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(show: true, color: color.withValues(alpha: 0.1)),
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

class SeriesScreenTimeChart extends StatelessWidget {
  final Map<String, dynamic> series;
  final String rangeLabel;
  final int recommendedMinutes;
  const SeriesScreenTimeChart({super.key, required this.series, required this.rangeLabel, this.recommendedMinutes = 120});
  @override
  Widget build(BuildContext context) => _SeriesLineChart(
        title: 'Screen Time — $rangeLabel',
        subtitle: 'Online records · recommended $recommendedMinutes min/day for this age',
        labels: _seriesLabels(series),
        values: _seriesValues(series, 'screen_times'),
        color: LumiColors.purpleMid,
        unit: 'm',
        threshold: recommendedMinutes.toDouble(),
      );
}

class SeriesBlinkChart extends StatelessWidget {
  final Map<String, dynamic> series;
  final String rangeLabel;
  const SeriesBlinkChart({super.key, required this.series, required this.rangeLabel});
  @override
  Widget build(BuildContext context) {
    final values = _seriesValues(series, 'blink_rates');
    final nums = values.whereType<double>().toList();
    Widget badge = const SizedBox.shrink();
    if (nums.isNotEmpty) {
      final avg = nums.reduce((a, b) => a + b) / nums.length;
      final ibi = avg > 0 ? 60.0 / avg : 0.0;
      final opi = ibi > 0 ? 6.0 / ibi : 0.0;
      final level = avg >= 12 && opi >= 1.2 ? 1 : avg >= 10 && opi >= 1.0 ? 2 : avg >= 6 && opi >= 0.6 ? 3 : 4;
      final label = switch (level) { 1 => 'Eyes look comfortable', 2 => 'Blinking a bit less than ideal', 3 => 'Eyes may feel dry — more blinks help', _ => 'Eyes need a break — try the blink game' };
      badge = Padding(
        padding: const EdgeInsets.only(bottom: LumiSpacing.md),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(LumiSpacing.md),
          decoration: BoxDecoration(color: LumiColors.secondaryLight, borderRadius: BorderRadius.circular(LumiRadii.md), border: Border.all(color: LumiColors.outline, width: 2)),
          child: Text('Blink comfort · Level $level — $label', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: LumiColors.textDark)),
        ),
      );
    }
    return Column(children: [badge, _SeriesLineChart(title: 'Blink Trends — $rangeLabel', subtitle: 'Online daily/weekly/monthly averages', labels: _seriesLabels(series), values: values, color: LumiColors.greenMid, unit: '')]);
  }
}

class SeriesDistanceChart extends StatelessWidget {
  final Map<String, dynamic> series;
  final String rangeLabel;
  const SeriesDistanceChart({super.key, required this.series, required this.rangeLabel});
  @override
  Widget build(BuildContext context) => _SeriesLineChart(
        title: 'Viewing Distance — $rangeLabel',
        subtitle: 'Online averages · 30 cm or farther is the comfy zone',
        labels: _seriesLabels(series),
        values: _seriesValues(series, 'distances'),
        color: LumiColors.primaryPurple,
        unit: '',
        threshold: 30,
      );
}
