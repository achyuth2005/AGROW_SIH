import 'package:flutter/material.dart';
import 'package:agroww_sih/widgets/trend_chart.dart';
import 'package:agroww_sih/widgets/heatmap_widget.dart';
import 'package:agroww_sih/widgets/analytics_fab_stack.dart';
import 'package:agroww_sih/widgets/timeseries_chart_widget.dart';
import 'package:agroww_sih/widgets/heatmap_detail_card.dart';

import 'package:agroww_sih/widgets/custom_bottom_nav_bar.dart';

class SoilStatusDetailScreen extends StatelessWidget {
  final Map<String, dynamic>? s2Data;

  const SoilStatusDetailScreen({super.key, this.s2Data});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE1EFEF),
      bottomNavigationBar: const CustomBottomNavBar(selectedIndex: 2),
      body: Stack(
        children: [
          // Background Image (Header)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Image.asset(
              'assets/backsmall.png',
              fit: BoxFit.fitWidth,
              alignment: Alignment.topCenter,
            ),
          ),
          // Content
          Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildHeatmapCard(
                        "Soil Moisture",
                        'soil_moisture',
                        'SMI',
                      ),
                      const SizedBox(height: 16),
                      _buildHeatmapCard(
                        "Soil Organic Matter",
                        'soil_organic_matter',
                        'SOMI',
                      ),
                      const SizedBox(height: 16),
                      _buildHeatmapCard(
                        "Soil Fertility",
                        'soil_fertility',
                        'SFI',
                      ),
                      const SizedBox(height: 16),
                      _buildHeatmapCard(
                        "Soil Salinity",
                        'soil_salinity',
                        'SASI',
                      ),
                      const SizedBox(height: 200), // Space for FABs
                    ],
                  ),
                ),
              ),
            ],
          ),
          const Positioned(
            bottom: 24,
            right: 16,
            child: AnalyticsFabStack(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 22),
              onPressed: () => Navigator.pop(context),
            ),
            const Expanded(
              child: Text(
                "Soil Status",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 48), // Balance the back button
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // HEATMAP CARD BUILDER - Uses new HeatmapDetailCard widget
  // ============================================================================
  
  Widget _buildHeatmapCard(String title, String metric, String satelliteMetric) {
    final double lat = s2Data?['center_lat'] ?? 26.1885;
    final double lon = s2Data?['center_lon'] ?? 91.6894;
    final double fieldSize = s2Data?['field_size_hectares'] ?? 10.0;
    
    return HeatmapDetailCard(
      title: title,
      metric: metric,
      satelliteMetric: satelliteMetric,
      centerLat: lat,
      centerLon: lon,
      fieldSizeHectares: fieldSize,
    );
  }

  // ============================================================================
  // DYNAMIC DATA HELPERS - Extract values from s2Data
  // ============================================================================
  
  String _getDataValue(String key, String fallback) {
    if (s2Data == null) return fallback;
    
    // NEW: Check for mean_value from heatmap API response (average index value)
    if (s2Data!.containsKey('mean_value')) {
      final mean = s2Data!['mean_value'];
      if (mean is num) {
        return _formatIndexValue(key, mean.toDouble());
      }
    }
    
    // Check in health_summary first
    if (s2Data!['health_summary'] != null) {
      final summary = s2Data!['health_summary'];
      if (summary is Map) {
        // Try direct key
        if (summary.containsKey(key)) {
          final val = summary[key];
          if (val is Map && val.containsKey('score')) {
            return '${val['score']}%';
          }
          return val.toString();
        }
        // Try key_level
        if (summary.containsKey('${key}_level')) {
          return summary['${key}_level'].toString();
        }
      }
    }
    
    // Check top level
    if (s2Data!.containsKey(key)) {
      return s2Data![key].toString();
    }
    
    return fallback;
  }
  
  /// Format index value with appropriate unit based on metric type
  String _formatIndexValue(String key, double value) {
    switch (key) {
      case 'soil_salinity':
        return '${value.toStringAsFixed(2)} dS/m';
      case 'soil_moisture':
        return '${(value * 100).toStringAsFixed(1)}%';
      case 'organic_matter':
      case 'soil_organic_matter':
        return '${value.toStringAsFixed(2)}';
      case 'soil_fertility':
        return '${value.toStringAsFixed(2)}';
      default:
        return value.toStringAsFixed(2);
    }
  }

  String _getDataStatusText(String key, String fallback) {
    if (s2Data == null) return fallback;
    
    // Check health_summary
    if (s2Data!['health_summary'] != null) {
      final summary = s2Data!['health_summary'];
      if (summary is Map) {
        if (summary.containsKey(key)) {
          final val = summary[key];
          if (val is Map && val.containsKey('status')) {
            return val['status'].toString();
          }
        }
        if (summary.containsKey('${key}_status')) {
          return summary['${key}_status'].toString();
        }
        if (summary.containsKey('${key}_level')) {
          return summary['${key}_level'].toString();
        }
      }
    }
    
    return fallback;
  }

  bool _isPositiveTrend(String key) {
    if (s2Data == null) return true;
    
    // Check health_summary for trend info
    if (s2Data!['health_summary'] != null) {
      final summary = s2Data!['health_summary'];
      if (summary is Map && summary.containsKey(key)) {
        final val = summary[key];
        if (val is Map && val.containsKey('trend')) {
          return val['trend'] == 'improving' || val['trend'] == 'stable';
        }
      }
    }
    
    return true; // Default positive
  }

  String _getTrendDescription(String key) {
    if (s2Data == null) return 'Data pending';
    
    // Check health_summary for trend info
    if (s2Data!['health_summary'] != null) {
      final summary = s2Data!['health_summary'];
      if (summary is Map && summary.containsKey(key)) {
        final val = summary[key];
        if (val is Map && val.containsKey('trend_description')) {
          return val['trend_description'].toString();
        }
        if (val is Map && val.containsKey('trend')) {
          final trend = val['trend'].toString();
          return trend == 'improving' ? 'Improving' : trend == 'declining' ? 'Declining' : 'Stable';
        }
      }
    }
    
    return 'Stable';
  }

  Widget _buildDetailSection(
    String title,
    String value,
    String level,
    bool isPositive,
    String changeText,
    List<double> trendData,
    List<double> forecastData, {
    String indexType = 'NDVI',
    String metric = 'greenness',
    String? satelliteMetric, // VV, VH, B04, B08 etc. for TimeSeries API
  }) {
    // Get coordinates from s2Data or use defaults
    final double lat = s2Data?['center_lat'] ?? 26.1885;
    final double lon = s2Data?['center_lon'] ?? 91.6894;
    final double fieldSize = s2Data?['field_size_hectares'] ?? 10.0;
    
    // DEBUG: Print coordinates being used
    debugPrint('🗺️ HEATMAP for $title: lat=$lat, lon=$lon, size=$fieldSize ha, s2Data=$s2Data');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F3C33),
            ),
          ),
          const SizedBox(height: 12),
          
          // Value & Heatmap Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F3C33),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          isPositive ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                          color: isPositive ? Colors.green : Colors.red,
                          size: 20,
                        ),
                        Expanded(
                          child: Text(
                            changeText,
                            style: TextStyle(
                              fontSize: 12,
                              color: isPositive ? Colors.green : Colors.red,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      level,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Heatmap from API
              HeatmapWidget(
                centerLat: lat,
                centerLon: lon,
                fieldSizeHectares: fieldSize,
                metric: metric,
                title: title,
                width: 100,
                height: 80,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Interactive Time Series Chart (if satellite metric available)
          if (satelliteMetric != null) ...[
            TimeSeriesChartWidget(
              centerLat: lat,
              centerLon: lon,
              fieldSizeHectares: fieldSize,
              metric: satelliteMetric,
              title: '$title Time Series (Tap for details)',
              height: 200,
            ),
          ] else ...[
            // Fallback: Static Trend Chart
            Text(
              "$title Trend",
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F3C33),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 120,
              child: TrendChart(
                dataPoints: trendData,
                color: const Color(0xFF167339),
              ),
            ),
            const SizedBox(height: 24),

            // Forecast Chart
            Row(
              children: [
                Text(
                  "$title Forecast",
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F3C33),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.info_outline, size: 14, color: Colors.grey),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 120,
              child: TrendChart(
                dataPoints: forecastData,
                color: const Color(0xFFFFD700),
              ),
            ),
          ],
          const SizedBox(height: 16),

          // Analysis Text
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5F3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.",
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF167339),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Reusing the painter logic but with yellow for forecast
class ForecastChartPainter extends CustomPainter {
  final List<double> dataPoints;
  final int highlightIndex;
  final double highlightValue;

  ForecastChartPainter({
    required this.dataPoints,
    required this.highlightIndex,
    required this.highlightValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (dataPoints.isEmpty) return;

    final paint = Paint()
      ..color = const Color(0xFFFFD700) // Gold/Yellow
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = const Color(0xFFFFD700).withOpacity(0.1)
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();
    
    final stepX = size.width / (dataPoints.length - 1);
    final maxY = size.height - 30;

    fillPath.moveTo(0, size.height);

    for (int i = 0; i < dataPoints.length; i++) {
      final x = i * stepX;
      final y = maxY - (dataPoints[i] * maxY);

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.lineTo(x, y);
      } else {
        final prevX = (i - 1) * stepX;
        final prevY = maxY - (dataPoints[i - 1] * maxY);
        final controlX = (prevX + x) / 2;
        path.quadraticBezierTo(controlX, prevY, x, y);
        fillPath.quadraticBezierTo(controlX, prevY, x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

    // Highlight
    if (highlightIndex >= 0 && highlightIndex < dataPoints.length) {
      final hx = highlightIndex * stepX;
      final hy = maxY - (dataPoints[highlightIndex] * maxY);

      canvas.drawCircle(Offset(hx, hy), 4, Paint()..color = const Color(0xFFFFD700));
      canvas.drawCircle(Offset(hx, hy), 2, Paint()..color = Colors.white);

      // Label
      final textPainter = TextPainter(
        text: const TextSpan(
          text: "64%",
          style: TextStyle(
            color: Colors.black,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      final labelRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(hx, hy - 20),
          width: textPainter.width + 12,
          height: textPainter.height + 6,
        ),
        const Radius.circular(12),
      );
      canvas.drawRRect(labelRect, Paint()..color = Colors.white);
      canvas.drawRRect(
        labelRect,
        Paint()
          ..color = const Color(0xFFFFD700)
          ..style = PaintingStyle.stroke,
      );

      textPainter.paint(
        canvas,
        Offset(hx - textPainter.width / 2, hy - 20 - textPainter.height / 2),
      );
    }
    
    // Days
    final days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thur', 'Fri', 'Sat'];
    for (int i = 0; i < days.length && i < dataPoints.length; i++) {
      final x = i * stepX;
      final textPainter = TextPainter(
        text: TextSpan(
          text: days[i],
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 10,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, size.height - 15));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
