import 'package:flutter/material.dart';
import 'package:agroww_sih/widgets/trend_chart.dart';
import 'package:agroww_sih/widgets/heatmap_widget.dart';
import 'package:agroww_sih/screens/soil_status_detail_screen.dart'; // For ForecastChartPainter
import 'package:agroww_sih/widgets/analytics_fab_stack.dart';

class CropStatusDetailScreen extends StatelessWidget {
  final Map<String, dynamic>? s2Data;

  const CropStatusDetailScreen({super.key, this.s2Data});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE1EFEF),
      body: Stack(
        children: [
          SafeArea(
            top: false, // Handle top safe area in header
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildDetailSection(
                          "Greenness",
                          "84",
                          "High",
                          true,
                          "12% in the past week",
                          [0.4, 0.5, 0.45, 0.6, 0.84, 0.75, 0.8],
                          [0.8, 0.82, 0.85, 0.83, 0.88, 0.85, 0.9],
                          metric: 'greenness', // NDVI
                          subMetrics: [
                            _buildSubMetric("Leaf Health", "Good", Colors.green),
                            _buildSubMetric("Canopy Density", "Average", Colors.green),
                            _buildSubMetric("Photosynthetic Activity", "Excellent", Colors.green),
                            _buildSubMetric("Crop Stress", "Low", Colors.green),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildDetailSection(
                          "Biomass Growth",
                          "1.2 dS/m",
                          "High",
                          true,
                          "0.1 dS/m past week",
                          [0.6, 0.58, 0.65, 0.7, 0.75, 0.72, 0.78],
                          [0.78, 0.8, 0.82, 0.85, 0.83, 0.88, 0.9],
                          metric: 'greenness', // EVI for biomass
                          subMetrics: [
                             _buildSubMetric("Crop Vigor", "High", Colors.green),
                             _buildSubMetric("Stem Count", "Detected", Colors.green),
                             _buildSubMetric("Canopy Density", "Ok", Colors.green),
                             _buildSubMetric("Field Drainage", "Mild", Colors.green),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildDetailSection(
                          "Nitrogen Level",
                          "5.9",
                          "Slightly Acidic",
                          false,
                          "0.2 in past week",
                          [0.5, 0.55, 0.52, 0.58, 0.6, 0.55, 0.58],
                          [0.58, 0.6, 0.62, 0.65, 0.63, 0.68, 0.7],
                          metric: 'nitrogen_level', // NDRE
                        ),
                        const SizedBox(height: 16),
                        _buildDetailSection(
                          "Photosynthesis Capacity",
                          "32°C",
                          "Mild",
                          false,
                          "2°C in the past week",
                          [0.3, 0.35, 0.4, 0.38, 0.42, 0.45, 0.48],
                          [0.48, 0.5, 0.52, 0.55, 0.5, 0.48, 0.52],
                          subMetrics: [
                            _buildSubMetric("Chlorophyll Efficiency", "Very", Colors.green),
                            _buildSubMetric("Photochemical Activity", "Excellent", Colors.green),
                            _buildSubMetric("Water-Energy Exchange", "Fair", Colors.green),
                            _buildSubMetric("Canopy Light Absorption", "12%", Colors.green),
                          ],
                        ),
                        const SizedBox(height: 200), // Space for FABs
                      ],
                    ),
                  ),
                ),
              ],
            ),
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
    return Stack(
      children: [
        Image.asset(
          'assets/backsmall.png',
          width: double.infinity,
          fit: BoxFit.fitWidth,
          alignment: Alignment.topCenter,
        ),
        Positioned(
          top: 50,
          left: 16,
          right: 16,
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                ),
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
              const SizedBox(width: 40), // Balance the back button
            ],
          ),
        ),
      ],
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
    List<Widget>? subMetrics,
    String indexType = 'NDVI',
    String metric = 'greenness',
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

          // Trend Chart
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
