import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class InfographicsScreen extends StatefulWidget {
  const InfographicsScreen({super.key});

  @override
  State<InfographicsScreen> createState() => _InfographicsScreenState();
}

class _InfographicsScreenState extends State<InfographicsScreen> {
  // Dummy data for charts
  final List<Map<String, dynamic>> _chartData = [
    {'title': 'Crop Yield', 'value': 0.75, 'color': Colors.orange},
    {'title': 'Water Usage', 'value': 0.60, 'color': Colors.blue},
    {'title': 'Soil Health', 'value': 0.85, 'color': Colors.brown},
    {'title': 'Pest Risk', 'value': 0.30, 'color': Colors.red},
    {'title': 'Revenue', 'value': 0.90, 'color': Colors.green},
    {'title': 'Expenses', 'value': 0.45, 'color': Colors.purple},
  ];

  @override
  Widget build(BuildContext context) {
    const greenBg = Color(0xFF0D986A);
    const brand = Color(0xFF167339);

    return Scaffold(
      backgroundColor: greenBg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWeb = constraints.maxWidth > 900;
            final crossAxisCount = isWeb ? 4 : 2;

            return Column(
              children: [
                // Top Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
                          child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Text(
                        'Infographics',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 500.ms).slideX(begin: -0.2, end: 0),

                // Main Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(26),
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF083D2C), Color(0x00083D2C)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                        child: Column(
                          children: [
                            // Title
                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Performance Overview',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Icon(Icons.filter_list,
                                      color: Colors.white.withOpacity(0.7)),
                                ],
                              ),
                            ).animate().fadeIn(delay: 200.ms),

                            // Grid of Charts
                            Expanded(
                              child: GridView.builder(
                                padding: const EdgeInsets.all(16),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                  childAspectRatio: 1.0,
                                ),
                                itemCount: _chartData.length,
                                itemBuilder: (context, index) {
                                  final data = _chartData[index];
                                  return _buildChartCard(
                                    data['title'],
                                    data['value'],
                                    data['color'],
                                    index,
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1, end: 0),
                
                const SizedBox(height: 20),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildChartCard(String title, double value, Color color, int index) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 80,
                  height: 80,
                  child: CircularProgressIndicator(
                    value: value,
                    strokeWidth: 8,
                    backgroundColor: Colors.white.withOpacity(0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
                Text(
                  '${(value * 100).toInt()}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ).animate().fadeIn(delay: (300 + index * 100).ms).scale(curve: Curves.easeOutBack);
  }
}
