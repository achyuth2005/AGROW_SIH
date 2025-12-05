import 'package:flutter/material.dart';

class AnalyticsFabStack extends StatelessWidget {
  const AnalyticsFabStack({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12), // Reduced horizontal padding
      decoration: BoxDecoration(
        color: const Color(0xFF1B4D3E), // Dark green background
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildFloatingButton("Visual Analytics"),
          const SizedBox(height: 6),
          _buildFloatingButton("Take Action Now"),
          const SizedBox(height: 6),
          _buildFloatingButton("Mapped Analytics"),
        ],
      ),
    );
  }

  Widget _buildFloatingButton(String label) {
    return Container(
      width: 135, // Reduced width from 150
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFC6E96A), // Light green button
        borderRadius: BorderRadius.circular(20),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF1B4D3E),
          fontWeight: FontWeight.bold,
          fontSize: 12, // Slightly smaller font to fit
        ),
      ),
    );
  }
}
