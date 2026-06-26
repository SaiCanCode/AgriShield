import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'node_history_model.dart';

class DhtChart extends StatefulWidget {
  const DhtChart({
    super.key,
    required this.points,
    this.heatThreshold = 32.0,
    this.blightHumMin  = 80.0,
  });

  final List<NodeHistoryPoint> points;
  final double heatThreshold;
  final double blightHumMin;

  @override
  State<DhtChart> createState() => _DhtChartState();
}

class _DhtChartState extends State<DhtChart> {
  // Which series to highlight — null means both shown equally

  static const _tempColor = Color(0xFFF59E0B);   // amber
  static const _humColor  = Color(0xFF60A5FA);   // blue
  static const _dangerRed = Color(0xFFEF4444);

  // Normalise temperature to 0–100 range for display (assume 0–50°C range)
  double _normTemp(double t) => (t / 50.0 * 100.0).clamp(0.0, 100.0);

  // Humidity is already 0–100
  double _normHum(double h) => h.clamp(0.0, 100.0);

  @override
  Widget build(BuildContext context) {
    if (widget.points.isEmpty) return _empty(context);

    final cs     = Theme.of(context).colorScheme;
    final latest = widget.points.last;

    final tempSpots = widget.points.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), _normTemp(e.value.temp));
    }).toList();

    final humSpots = widget.points.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), _normHum(e.value.humidity));
    }).toList();

    // Normalised threshold lines
    final normHeatThreshold  = _normTemp(widget.heatThreshold);
    final normBlightHumMin   = _normHum(widget.blightHumMin);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header 
        Row(
          children: [
            const SizedBox(width: 5),
            Text(
              'Temp / Humidity',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.5),
                letterSpacing: .05,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Text(
              '${latest.temp.toStringAsFixed(1)}°C',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: _tempColor,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 1,
              height: 12,
              color: cs.outline.withValues(alpha: 0.4),
            ),
            const SizedBox(width: 8),
            Text(
              '${latest.humidity.toStringAsFixed(0)}%',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: _humColor,
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
              minY: 0,
              maxY: 100,
              clipData: const FlClipData.all(),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 25,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: cs.outline.withValues(alpha: 0.25),
                  strokeWidth: 0.5,
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: 25,
                    getTitlesWidget: (v, _) {
                      // convert normalised value back to °C for left axis
                      final real = (v / 100.0 * 50.0);
                      return Text(
                        '${real.toInt()}°',
                        style: TextStyle(
                          fontSize: 9,
                          color: _tempColor.withValues(alpha: 0.5),
                        ),
                      );
                    },
                  ),
                ),
                rightTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    interval: 25,
                    getTitlesWidget: (v, _) => Text(
                      '${v.toInt()}%',
                      style: TextStyle(
                        fontSize: 9,
                        color: _humColor.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 16,
                    interval: (tempSpots.length / 4).ceilToDouble(),
                    getTitlesWidget: (v, _) {
                      final idx = v.toInt();
                      if (idx < 0 || idx >= widget.points.length) {
                        return const SizedBox.shrink();
                      }
                      final dt = DateTime.fromMillisecondsSinceEpoch(
                        widget.points[idx].timestamp * 1000,
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
                touchCallback: (event, response) {
                  setState(() {
                  });
                },
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((s) {
                      final idx = s.spotIndex;
                      if (idx >= widget.points.length) {
                        return null;
                      }
                      final p = widget.points[idx];
                      final isTemp = s.barIndex == 0;
                      return LineTooltipItem(
                        isTemp
                            ? '${p.temp.toStringAsFixed(1)}°C'
                            : '${p.humidity.toStringAsFixed(0)}%',
                        TextStyle(
                          color: isTemp ? _tempColor : _humColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    }).toList();
                  },
                ),
              ),
              extraLinesData: ExtraLinesData(
                horizontalLines: [
                  // Heat stress threshold
                  HorizontalLine(
                    y: normHeatThreshold,
                    color: _dangerRed.withValues(alpha: 0.5),
                    strokeWidth: 1,
                    dashArray: [4, 3],
                    label: HorizontalLineLabel(
                      show: true,
                      alignment: Alignment.topRight,
                      labelResolver: (_) =>
                          '${widget.heatThreshold.toInt()}°C max',
                      style: TextStyle(
                        color: _dangerRed.withValues(alpha: 0.65),
                        fontSize: 8,
                      ),
                    ),
                  ),
                  // Blight humidity threshold
                  HorizontalLine(
                    y: normBlightHumMin,
                    color: _humColor.withValues(alpha: 0.45),
                    strokeWidth: 1,
                    dashArray: [4, 3],
                    label: HorizontalLineLabel(
                      show: true,
                      alignment: Alignment.bottomRight,
                      labelResolver: (_) =>
                          '${widget.blightHumMin.toInt()}% blight',
                      style: TextStyle(
                        color: _humColor.withValues(alpha: 0.65),
                        fontSize: 8,
                      ),
                    ),
                  ),
                ],
              ),
              lineBarsData: [
                // Temperature line
                LineChartBarData(
                  spots: tempSpots,
                  isCurved: true,
                  curveSmoothness: 0.25,
                  color: _tempColor,
                  barWidth: 1.5,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        _tempColor.withValues(alpha: 0.08),
                        _tempColor.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
                // Humidity line
                LineChartBarData(
                  spots: humSpots,
                  isCurved: true,
                  curveSmoothness: 0.25,
                  color: _humColor,
                  barWidth: 1.5,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        _humColor.withValues(alpha: 0.08),
                        _humColor.withValues(alpha: 0.0),
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
            _LegendLabel(label: 'Temp (°C)'),
            const SizedBox(width: 12),
            _LegendLabel(label: 'Humidity (%)'),
            const SizedBox(width: 12),
            _LegendLabel(label: 'Thresholds'),
          ],
        ),
      ],
    );
  }

  Widget _empty(BuildContext context) => SizedBox(
        height: 110,
        child: Center(
          child: Text(
            'No sensor data',
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
