import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'node_history_model.dart';

class SoilChart extends StatelessWidget {
  const SoilChart({
    super.key,
    required this.points,
    this.droughtThreshold = 60.0,
    this.floodThreshold   = 85.0,
  });

  final List<NodeHistoryPoint> points;
  final double droughtThreshold;
  final double floodThreshold;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return _empty(context);

    final cs        = Theme.of(context).colorScheme;
    final soilColor = const Color(0xFF22C55E);
    final dangerRed = const Color(0xFFEF4444);
    final floodTeal = const Color(0xFF14B8A6);

    // current reading for header
    final latest    = points.last;
    final soilNow   = latest.soil.toStringAsFixed(0);
    final alertType = latest.alertType;

    Color valueColor = soilColor;
    if (alertType == 'drought') valueColor = const Color(0xFFF59E0B);
    if (alertType == 'flood')   valueColor = floodTeal;

    final spots = points.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.soil);
    }).toList();

    final minY = (points.map((p) => p.soil).reduce((a, b) => a < b ? a : b) - 10)
        .clamp(0.0, 100.0);
    final maxY = (points.map((p) => p.soil).reduce((a, b) => a > b ? a : b) + 10)
        .clamp(0.0, 100.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
        Row(
          children: [
            const SizedBox(width: 6),
            Text(
              'Soil Moisture',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.5),
                letterSpacing: .05,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Text(
              '$soilNow%',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: valueColor,
                fontWeight: FontWeight.w700,
                fontSize: 20,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Chart
        SizedBox(
          height: 110,
          child: LineChart(
            LineChartData(
              minY: minY,
              maxY: maxY,
              clipData: const FlClipData.all(),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 20,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: cs.outline.withValues(alpha: 0.3),
                  strokeWidth: 0.5,
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: 20,
                    getTitlesWidget: (v, _) => Text(
                      '${v.toInt()}',
                      style: TextStyle(
                        fontSize: 9,
                        color: cs.onSurface.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 16,
                    interval: (spots.length / 4).ceilToDouble(),
                    getTitlesWidget: (v, _) {
                      final idx = v.toInt();
                      if (idx < 0 || idx >= points.length) {
                        return const SizedBox.shrink();
                      }
                      final dt = DateTime.fromMillisecondsSinceEpoch(
                        points[idx].timestamp * 1000,
                      );
                      return Text(
                        '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}',
                        style: TextStyle(
                          fontSize: 9,
                          color: cs.onSurface.withValues(alpha: 0.35),
                        ),
                      );
                    },
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (spots) => spots.map((s) {
                    return LineTooltipItem(
                      '${s.y.toStringAsFixed(1)}%',
                      TextStyle(
                        color: soilColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  }).toList(),
                ),
              ),
              extraLinesData: ExtraLinesData(
                horizontalLines: [
                  // drought threshold
                  HorizontalLine(
                    y: droughtThreshold,
                    color: dangerRed.withValues(alpha: 0.55),
                    strokeWidth: 1,
                    dashArray: [4, 3],
                    label: HorizontalLineLabel(
                      show: true,
                      alignment: Alignment.topRight,
                      labelResolver: (_) =>
                          'min ${droughtThreshold.toInt()}%',
                      style: TextStyle(
                        color: dangerRed.withValues(alpha: 0.7),
                        fontSize: 8,
                      ),
                    ),
                  ),
                  // flood threshold
                  HorizontalLine(
                    y: floodThreshold,
                    color: floodTeal.withValues(alpha: 0.55),
                    strokeWidth: 1,
                    dashArray: [4, 3],
                    label: HorizontalLineLabel(
                      show: true,
                      alignment: Alignment.bottomRight,
                      labelResolver: (_) =>
                          'max ${floodThreshold.toInt()}%',
                      style: TextStyle(
                        color: floodTeal.withValues(alpha: 0.7),
                        fontSize: 8,
                      ),
                    ),
                  ),
                ],
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  curveSmoothness: 0.25,
                  color: soilColor,
                  barWidth: 1.5,
                  dotData: FlDotData(
                    show: true,
                    checkToShowDot: (spot, _) {
                      final idx = spot.x.toInt();
                      if (idx < 0 || idx >= points.length) return false;
                      return points[idx].alertType != 'none';
                    },
                    getDotPainter: (spot, _, __, ___) =>
                        FlDotCirclePainter(
                      radius: 3,
                      color: dangerRed,
                      strokeWidth: 1,
                      strokeColor: dangerRed,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        soilColor.withValues(alpha: 0.12),
                        soilColor.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Legend — plain text only
        const SizedBox(height: 8),
        Row(
          children: [
            _LegendLabel(label: 'Soil %'),
            const SizedBox(width: 12),
            _LegendLabel(label: 'Drought min'),
            const SizedBox(width: 12),
            _LegendLabel(label: 'Flood max'),
          ],
        ),
      ],
    );
  }

  Widget _empty(BuildContext context) => SizedBox(
        height: 110,
        child: Center(
          child: Text(
            'No soil data',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.35),
            ),
          ),
        ),
      );
}

class _LegendLabel extends StatelessWidget {
  const _LegendLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: TextStyle(
          fontSize: 9,
          color: Theme.of(context)
              .colorScheme
              .onSurface
              .withValues(alpha: 0.45),
        ),
      );
}
