import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class ArticMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final Color accentColor;
  final IconData? icon;
  final String? subtitle;
  final List<double>? trendData;
  final bool showSparkline;

  const ArticMetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.accentColor,
    this.icon,
    this.subtitle,
    this.trendData,
    this.showSparkline = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Generar datos ficticios elegantes en caso de que no haya datos de tendencia
    final sparklinePoints = trendData ?? [1.0, 1.2, 1.1, 1.5, 1.3, 1.8, 1.6, 2.0];

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.white.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.25),
              width: 1.2,
            ),
            gradient: LinearGradient(
              colors: isDark
                  ? [
                      Colors.white.withValues(alpha: 0.02),
                      accentColor.withValues(alpha: 0.03),
                    ]
                  : [
                      Colors.white.withValues(alpha: 0.4),
                      accentColor.withValues(alpha: 0.04),
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            children: [
              // Métrica e Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        if (icon != null) ...[
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: isDark ? 0.12 : 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              icon,
                              size: 18,
                              color: accentColor,
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white70 : Colors.black87,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black87,
                        letterSpacing: -0.5,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white38 : Colors.black54,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Sparkline (Tendencia)
              if (showSparkline && sparklinePoints.isNotEmpty) ...[
                const SizedBox(width: 12),
                SizedBox(
                  width: 80,
                  height: 48,
                  child: LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: false),
                      titlesData: const FlTitlesData(show: false),
                      borderData: FlBorderData(show: false),
                      minX: 0,
                      maxX: (sparklinePoints.length - 1).toDouble(),
                      minY: sparklinePoints.reduce((a, b) => a < b ? a : b) * 0.95,
                      maxY: sparklinePoints.reduce((a, b) => a > b ? a : b) * 1.05,
                      lineTouchData: const LineTouchData(enabled: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: List.generate(
                            sparklinePoints.length,
                            (index) => FlSpot(index.toDouble(), sparklinePoints[index]),
                          ),
                          isCurved: true,
                          color: accentColor,
                          barWidth: 2.5,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                accentColor.withValues(alpha: 0.2),
                                accentColor.withValues(alpha: 0.0),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
