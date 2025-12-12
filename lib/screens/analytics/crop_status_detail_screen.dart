/// ===========================================================================
/// CROP STATUS DETAIL SCREEN
/// ===========================================================================
///
/// PURPOSE: Detailed analytics dashboard for vegetation/crop health metrics.
///          Displays 4 key crop indicators with heatmaps and time series.
///
/// KEY SECTIONS:
///   1. Greenness (NDVI) - Overall vegetation density
///   2. Biomass Growth (EVI) - Biomass accumulation
///   3. Nitrogen Level (NDRE) - Leaf nitrogen content
///   4. Photosynthesis Capacity (PRI) - Photosynthetic efficiency
///
/// VISUALIZATION:
///   - HeatmapDetailCard: Interactive heatmap from Sentinel-2
///   - TimeSeriesChartWidget: 30-day historical + 30-day forecast
///   - Sub-metrics grid for detailed breakdown
///
/// DATA FLOW:
///   1. Receives s2Data from navigation (contains center_lat, center_lon)
///   2. Passes coordinates to HeatmapDetailCard for API calls
///   3. HeatmapService fetches NDVI, EVI, NDRE, PRI indices
///   4. TimeSeriesService provides trend predictions
///
/// DEPENDENCIES:
///   - HeatmapDetailCard, TimeSeriesChartWidget widgets
///   - AnalyticsFabStack for action buttons
///   - CustomBottomNavBar for navigation
/// ===========================================================================

import 'package:flutter/material.dart';
import 'package:agroww_sih/widgets/trend_chart.dart';
import 'package:agroww_sih/widgets/heatmap_widget.dart';
import 'package:agroww_sih/screens/analytics/soil_status_detail_screen.dart'; // For ForecastChartPainter
import 'package:agroww_sih/widgets/analytics_fab_stack.dart';
import 'package:agroww_sih/widgets/timeseries_chart_widget.dart';
import 'package:agroww_sih/widgets/heatmap_detail_card.dart';

import 'package:agroww_sih/widgets/custom_bottom_nav_bar.dart';

class CropStatusDetailScreen extends StatelessWidget {
  final Map<String, dynamic>? s2Data;

  const CropStatusDetailScreen({super.key, this.s2Data});

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
                        "Greenness",
                        'greenness',
                        'NDVI',
                      ),
                      const SizedBox(height: 16),
                      _buildHeatmapCard(
                        "Biomass Growth",
                        'greenness', // Uses NDVI-based metric on backend
                        'EVI',
                      ),
                      const SizedBox(height: 16),
                      _buildHeatmapCard(
                        "Nitrogen Level",
                        'nitrogen_level',
                        'NDRE',
                      ),
                      const SizedBox(height: 16),
                      _buildHeatmapCard(
                        "Photosynthesis Capacity",
                        'photosynthetic_capacity',
                        'PRI',
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
                "Crop Status",
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

  Widget _buildSubMetric(String title, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 10,
            color: Color(0xFF0F3C33),
            fontWeight: FontWeight.w500,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F3C33),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 4,
          width: 40,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailSection(
    String title,
    String value,
    String level,
    bool isPositive,
    String changeText,
    List<double> trendData,
    List<double> forecastData, {
    String metric = 'greenness',
    String? satelliteMetric, // VV, VH, B04, B05 etc. for TimeSeries API
    List<Widget> subMetrics = const [],
  }) {
    // Get coordinates from s2Data or use defaults
    final double lat = s2Data?['center_lat'] ?? 26.1885;
    final double lon = s2Data?['center_lon'] ?? 91.6894;
    final double fieldSize = s2Data?['field_size_hectares'] ?? 10.0;
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
          
          if (subMetrics != null) ...[
            const SizedBox(height: 16),
            const Text(
              "Greenness Scoring", // Or generic title? Mockup says "Greenness Scoring" for first card
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F3C33),
              ),
            ),
            const SizedBox(height: 8),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 2.5,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: subMetrics,
            ),
          ],

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
              height: 100,
              child: TrendChart(
                dataPoints: forecastData,
                color: const Color(0xFF167339),
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

  String _getDataValue(String key, String fallback) {
    if (s2Data == null) return fallback;
    
    // Check specific keys first
    if (s2Data!['health_summary'] != null) {
      final summary = s2Data!['health_summary'];
      // Try key_level as value if no numeric value exists
      if (summary is Map && summary.containsKey('${key}_level')) {
        return summary['${key}_level'].toString().toUpperCase();
      }
    }
    
    // Check top level
    if (s2Data!.containsKey('${key}_level')) {
        return s2Data!['${key}_level'].toString().toUpperCase();
    }

    return fallback;
  }

  String _getDataStatusText(String key, String fallback) {
    if (s2Data == null) return fallback;

    // Check health_summary
    if (s2Data!['health_summary'] != null) {
      final summary = s2Data!['health_summary'];
      // Try key_status first
      if (summary is Map && summary.containsKey('${key}_status')) {
        return summary['${key}_status'].toString();
      }
      // Fallback to key_level if status not found
      if (summary is Map && summary.containsKey('${key}_level')) {
        return summary['${key}_level'].toString();
      }
    }
    
    // Check top level
    if (s2Data!.containsKey('${key}_status')) {
        return s2Data!['${key}_status'].toString();
    }
    if (s2Data!.containsKey('${key}_level')) {
        return s2Data!['${key}_level'].toString();
    }

    return fallback;
  }
}
