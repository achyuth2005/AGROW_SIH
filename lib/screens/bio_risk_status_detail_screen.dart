import 'package:flutter/material.dart';
import 'package:agroww_sih/widgets/trend_chart.dart';
import 'package:agroww_sih/screens/soil_status_detail_screen.dart'; // For ForecastChartPainter
import 'package:agroww_sih/widgets/analytics_fab_stack.dart';
import 'package:agroww_sih/widgets/heatmap_widget.dart';

class BioRiskStatusDetailScreen extends StatelessWidget {
  final Map<String, dynamic>? s2Data;

  const BioRiskStatusDetailScreen({super.key, this.s2Data});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE1EFEF),
      body: Stack(
        children: [
          SafeArea(
            top: false,
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildDetailSection(
                          "Pest Risk",
                          "32°C",
                          "Mild",
                          false, // Negative/Neutral change
                          "High risk detected", // Placeholder text
                          [0.3, 0.4, 0.35, 0.5, 0.45, 0.4, 0.42],
                          [0.42, 0.45, 0.48, 0.5, 0.48, 0.52, 0.55],
                          metric: 'pest_risk',
                        ),
                        const SizedBox(height: 16),
                        _buildDetailSection(
                          "Disease Risk",
                          "84",
                          "High",
                          true, // Positive change (or high risk is bad?) - Mockup shows green arrow for High? Assuming green arrow means "Trend is up"
                          "15% rate per week",
                          [0.4, 0.5, 0.6, 0.7, 0.84, 0.8, 0.85],
                          [0.85, 0.88, 0.9, 0.92, 0.9, 0.95, 0.98],
                          metric: 'disease_risk',
                        ),
                        const SizedBox(height: 16),
                        _buildDetailSection(
                          "Nutrient Stress",
                          "5.9",
                          "Slightly Acidic",
                          false,
                          "Mild decrease",
                          [0.6, 0.55, 0.58, 0.52, 0.5, 0.48, 0.5],
                          [0.5, 0.48, 0.45, 0.42, 0.4, 0.38, 0.35],
                          metric: 'nutrient_stress',
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
                  "Bio-Risk Status",
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

  Widget _buildDetailSection(
    String title,
    String value,
    String level,
    bool isPositive,
    String changeText,
    List<double> trendData,
    List<double> forecastData, {
    String metric = 'pest_risk',
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
            height: 120,
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
              "The pest risk level is currently 7% in the past week which is a moderate level. It is advised to wait until 20% to control the pest risk level.",
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




