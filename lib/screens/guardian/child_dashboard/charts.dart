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

  const WeeklyScreenTimeChart({
    super.key,
    required this.batches,
    required this.batchesByDay,
  });

  @override
  Widget build(BuildContext context) {
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

    return RoundedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Weekly Screen Time',
            style: TextStyle(fontSize: 16, height: 24 / 16, fontWeight: FontWeight.w600, color: LumiColors.textDark),
          ),
          const SizedBox(height: LumiSpacing.sm),
          const Text(
            'Actual vs Recommended Usage',
            style: TextStyle(fontSize: 12, color: LumiColors.textMuted),
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