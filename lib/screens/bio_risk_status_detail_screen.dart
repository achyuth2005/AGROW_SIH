import 'package:flutter/material.dart';
import 'package:agroww_sih/widgets/trend_chart.dart';
import 'package:agroww_sih/screens/soil_status_detail_screen.dart'; // For ForecastChartPainter
import 'package:agroww_sih/widgets/analytics_fab_stack.dart';
import 'package:agroww_sih/widgets/heatmap_widget.dart';
import 'package:agroww_sih/widgets/timeseries_chart_widget.dart';
import 'package:agroww_sih/widgets/heatmap_detail_card.dart';

import 'package:agroww_sih/widgets/custom_bottom_nav_bar.dart';

class BioRiskStatusDetailScreen extends StatelessWidget {
  final Map<String, dynamic>? s2Data;

  const BioRiskStatusDetailScreen({super.key, this.s2Data});

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
                        "Pest Risk",
                        'pest_risk',
                      ),
                      const SizedBox(height: 16),
                      _buildHeatmapCard(
                        "Disease Risk",
                        'disease_risk',
                      ),
                      const SizedBox(height: 16),
                      _buildHeatmapCard(
                        "Nutrient Stress",
                        'nutrient_stress',
                      ),
                      const SizedBox(height: 16),
                      _buildStressZoneSection(),
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
                "Bio-Risk Status",
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
  
  Widget _buildHeatmapCard(String title, String metric) {
    final double lat = s2Data?['center_lat'] ?? 26.1885;
    final double lon = s2Data?['center_lon'] ?? 91.6894;
    final double fieldSize = s2Data?['field_size_hectares'] ?? 10.0;
    
    return HeatmapDetailCard(
      title: title,
      metric: metric,
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
        if (summary.containsKey(key)) {
          final val = summary[key];
          if (val is Map && val.containsKey('score')) {
            return '${val['score']}%';
          }
          return val.toString();
        }
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
      case 'pest_risk':
      case 'disease_risk':
      case 'nutrient_stress':
        return '${(value * 100).toStringAsFixed(0)}%'; // Stress as percentage
      case 'stress_zones':
        return value.toStringAsFixed(2);
      default:
        return value.toStringAsFixed(2);
    }
  }

  String _getDataStatusText(String key, String fallback) {
    if (s2Data == null) return fallback;
    
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
    
    if (s2Data!['health_summary'] != null) {
      final summary = s2Data!['health_summary'];
      if (summary is Map && summary.containsKey(key)) {
        final val = summary[key];
        if (val is Map && val.containsKey('trend')) {
          return val['trend'] == 'improving' || val['trend'] == 'stable';
        }
      }
    }
    
    return true;
  }

  String _getTrendDescription(String key) {
    if (s2Data == null) return 'Data pending';
    
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
    String metric = 'pest_risk',
    String? satelliteMetric, // VV, VH, B04, B05 etc. for TimeSeries API
  }) {
    // Get coordinates from s2Data or use defaults
    final double lat = s2Data?['center_lat'] ?? 26.1885;
    final double lon = s2Data?['center_lon'] ?? 91.6894;
    final double fieldSize = s2Data?['field_size_hectares'] ?? 10.0;
    
    debugPrint('🗺️ BIORISK HEATMAP for $title: lat=$lat, lon=$lon, size=$fieldSize ha, metric=$metric');
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
              // Real Heatmap Widget
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

          const SizedBox(height: 24),

          // Interactive Time Series Chart (if satellite metric available)
          if (satelliteMetric != null) ...[
            TimeSeriesChartWidget(
              centerLat: lat,
              centerLon: lon,
              fieldSizeHectares: fieldSize,
              metric: satelliteMetric,
              title: '$title Time Series',
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
          ],
          
          const SizedBox(height: 24),
          
          // Forecast Chart (Always show in fallback mode or if logic demands)
           if (satelliteMetric == null) ...[
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
                  color: const Color(0xFF167339),
                ),
              ),
              const SizedBox(height: 16),
           ]
        ],
      ),
    );
  }

  Widget _buildStressZoneSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Stress Zones",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F3C33),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: RichText(
                  text: const TextSpan(
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF0F3C33),
                      height: 1.4,
                    ),
                    children: [
                      TextSpan(text: "Stress\ndetected in\nthe "),
                      TextSpan(
                        text: "north",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                      TextSpan(text: " side"),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Container(
                width: 100,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey.shade200,
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        gradient: RadialGradient(
                          colors: [Colors.red.withValues(alpha: 0.8), Colors.green.withValues(alpha: 0.3)],
                          center: const Alignment(0.0, -0.5), // North side
                          radius: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
           Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5F3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              "The soil pH level decreased by 0.5 in the past week which is slightly acidic. It is advised to monitor the soil pH level for the next few weeks.",
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




