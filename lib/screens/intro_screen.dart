import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class IntroScreen extends StatelessWidget {
  const IntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const Color primaryDark = Color(0xFF0F3C33);
    const Color limeGreen = Color(0xFF9FE870);
    
    // Bar colors from top to bottom
    final List<Color> barColors = [
      const Color(0xFFA8D5BA), // Light mint
      const Color(0xFFC5E898), // Pale lime
      const Color(0xFF9FE870), // Lime green
      Colors.black,            // Black
      const Color(0xFF1A4D3E), // Dark green
      const Color(0xFF5D7A74), // Greyish green
      const Color(0xFFE0F2F1), // Very light mint/white
    ];

    // Width percentages for the bars
    final List<double> barWidths = [0.30, 0.50, 0.70, 0.85, 0.75, 0.60, 0.40];

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),
            // Header Text
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHighlightedText("Turning cutting-edge", limeGreen, Colors.transparent),
                const SizedBox(height: 4),
                _buildHighlightedText("agri-technology into", primaryDark, Colors.transparent, textColor: limeGreen),
                const SizedBox(height: 4),
                _buildHighlightedText("everyday growth", limeGreen, Colors.transparent),
              ],
            ).animate().fadeIn().slideX(),

            const Spacer(flex: 1),

            // Graphic (Bars)
            Center(
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end, // Align bars to the right
                  children: List.generate(barColors.length, (index) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      height: 40, // Height of each bar
                      width: MediaQuery.of(context).size.width * barWidths[index],
                      decoration: BoxDecoration(
                        color: barColors[index],
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          bottomLeft: Radius.circular(20),
                        ),
                      ),
                    ).animate().fadeIn(delay: (100 * index).ms).slideX(begin: 1, end: 0);
                  }),
                ),
              ),
            ),

            const Spacer(flex: 2),

            // Get Started Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacementNamed(context, '/research-profile');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: limeGreen,
                    foregroundColor: primaryDark,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    "Get Started",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ).animate().fadeIn(delay: 800.ms).slideY(begin: 0.5, end: 0),
            ),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildHighlightedText(String text, Color bgColor, Color borderColor, {Color textColor = const Color(0xFF0F3C33)}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 8, 20, 8), // Left padding to offset text from edge
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: textColor,
          fontFamily: 'Inter',
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}
