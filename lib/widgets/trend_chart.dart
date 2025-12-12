/// ============================================================================
/// FILE: trend_chart.dart
/// ============================================================================
/// PURPOSE: Simple line chart widget for displaying weekly trends.
///          Used throughout the app to show 7-day data patterns.
/// 
/// FEATURES:
///   - Curved line with gradient fill below
///   - Touch tooltips showing percentage values
///   - Day labels (Sun-Sat) on x-axis
///   - Customizable line color
/// 
/// USAGE:
///   TrendChart(
///     dataPoints: [0.3, 0.5, 0.6, 0.4, 0.7, 0.8, 0.6], // 7 days
///     color: Colors.green,
///   )
/// 
/// DEPENDENCIES:
///   - fl_chart: Charting library for Flutter
/// ============================================================================

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

/// Simple weekly trend chart widget
class TrendChart extends StatelessWidget {
  /// Data points to display (should be 7 values for Sun-Sat)
  /// Values should be normalized to 0.0-1.0 range
  final List<double> dataPoints;
  
  /// Line and area fill color
  final Color color;

  const TrendChart({
    super.key,
    required this.dataPoints,
    this.color = const Color(0xFF167339), // Default: app green
  });

  @override
  Widget build(BuildContext context) {
    // Return empty widget if no data
    if (dataPoints.isEmpty) return const SizedBox();

    // Convert data points to FlSpot format
    List<FlSpot> spots = [];
    for (int i = 0; i < dataPoints.length; i++) {
      spots.add(FlSpot(i.toDouble(), dataPoints[i]));
    }

    return LineChart(
      LineChartData(
        // Hide grid lines for cleaner look
        gridData: FlGridData(show: false),
        
        // Configure axis titles
        titlesData: FlTitlesData(
          show: true,
          // Bottom axis: Day labels
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thur', 'Fri', 'Sat'];
                int index = value.toInt();
                if (index >= 0 && index < days.length && index < dataPoints.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      days[index],
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
                    ),
                  );
                }
                return const SizedBox();
              },
              interval: 1,
            ),
          ),
          // Hide other axis labels
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        
        // Hide border
        borderData: FlBorderData(show: false),
        
        // Chart bounds
        minX: 0,
        maxX: (dataPoints.length - 1).toDouble(),
        minY: 0,
        maxY: 1.0, // Values should be normalized to 0-1
        
        // Line configuration
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true, // Smooth curve
            color: color,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(show: true), // Show data points
            // Gradient fill below line
            belowBarData: BarAreaData(
              show: true,
              color: color.withOpacity(0.1),
            ),
          ),
        ],
        
        // Touch interaction: show tooltip with percentage
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                return LineTooltipItem(
                  "${(spot.y * 100).toInt()}%",
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }
}
