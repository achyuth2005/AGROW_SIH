import 'package:flutter/material.dart';
import 'package:agroww_sih/widgets/trend_chart.dart';
import 'package:agroww_sih/widgets/heatmap_widget.dart';
import 'package:agroww_sih/widgets/analytics_fab_stack.dart';

class SoilStatusDetailScreen extends StatelessWidget {
  final Map<String, dynamic>? s2Data;

  const SoilStatusDetailScreen({super.key, this.s2Data});

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
                          "Soil Moisture",
                          "64%",
                          "Moderate",
                          true, // isPositive (Green arrow)
                          "12% in the past week",
                          [0.4, 0.5, 0.45, 0.6, 0.64, 0.58, 0.62],
                          [0.62, 0.65, 0.7, 0.68, 0.72, 0.65, 0.75], // Forecast
                          indexType: 'SMI', // Soil Moisture Index
                        ),
                        const SizedBox(height: 16),
                        _buildDetailSection(
                          "Soil Organic Matter",
                          "2.8%",
                          "Low",
                          false, // isPositive (Red arrow)
                          "0.2% in the past week",
                          [0.3, 0.28, 0.32, 0.3, 0.28, 0.25, 0.28],
                          [0.28, 0.27, 0.26, 0.25, 0.24, 0.23, 0.22], // Forecast
                          indexType: 'NDVI', // Vegetation health
                        ),
                        const SizedBox(height: 16),
                        _buildDetailSection(
                          "Soil Fertility",
                          "High",
                          "Optimal",
                          true,
                          "Stable",
                          [0.7, 0.72, 0.75, 0.78, 0.8, 0.82, 0.8],
                          [0.8, 0.81, 0.82, 0.83, 0.84, 0.85, 0.86],
                          indexType: 'EVI', // Enhanced Vegetation
                        ),
                        const SizedBox(height: 16),
                        _buildDetailSection(
                          "Soil Salinity",
                          "0.8 dS/m",
                          "Normal",
                          true,
                          "No significant change",
                          [0.2, 0.22, 0.21, 0.23, 0.2, 0.19, 0.2],
                          [0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2],
                          indexType: 'NDWI', // Water index
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
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                ),
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
    String indexType = 'NDVI',
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
                indexType: indexType,
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
              color: const Color(0xFFFFD700), // Using the yellow from ForecastChartPainter
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
