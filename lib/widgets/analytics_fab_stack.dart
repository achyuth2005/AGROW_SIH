/// ============================================================================
/// FILE: analytics_fab_stack.dart
/// ============================================================================
/// PURPOSE: Floating action button stack that provides quick access to
///          analytics features. Displayed as a vertical column of buttons
///          with a distinctive dark green background.
/// 
/// BUTTONS:
///   1. Visual Analytics - Charts and graphs view
///   2. Take Action Now - Actionable recommendations
///   3. Mapped Analytics - Geospatial analysis on map
/// 
/// DESIGN:
///   - Dark green container (matches app theme)
///   - Lime green buttons for contrast
///   - Rounded corners and shadow for floating effect
/// ============================================================================

import 'package:flutter/material.dart';
import '../screens/analytics/mapped_analytics_home_screen.dart';
import '../screens/features/take_action_screen.dart';

/// Floating action button stack for analytics quick actions
class AnalyticsFabStack extends StatelessWidget {
  const AnalyticsFabStack({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
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
          // Visual Analytics button (no navigation yet)
          _buildFloatingButton(context, "Visual Analytics", null),
          const SizedBox(height: 6),
          // Take Action button
          _buildFloatingButton(context, "Take Action Now", () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const TakeActionScreen()));
          }),
          const SizedBox(height: 6),
          // Mapped Analytics button
          _buildFloatingButton(context, "Mapped Analytics", () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const MappedAnalyticsHomeScreen()));
          }),
        ],
      ),
    );
  }

  /// Build individual floating button
  Widget _buildFloatingButton(BuildContext context, String label, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 135,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFC6E96A), // Lime green button
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF1B4D3E),
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
