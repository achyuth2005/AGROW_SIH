/// ============================================================================
/// FILE: custom_bottom_nav_bar.dart
/// ============================================================================
/// PURPOSE: Premium-styled bottom navigation bar for agronomists/power users.
///          Features 5 navigation items with custom icons and animations.
/// 
/// NAVIGATION ITEMS:
///   0: Analytics  - Charts and data visualization
///   1: Take Action - Actionable recommendations
///   2: Home       - Main dashboard (center, slightly larger)
///   3: Chatbot    - AI assistant
///   4: Your Fields - Field management and mapping
/// 
/// DESIGN FEATURES:
///   - Background image (assets/backdown.png)
///   - Rounded top corners (borderRadius: 28)
///   - Animated selection state (lime green background)
///   - Custom icon assets for each item
///   - Fade transition between screens
/// ============================================================================

import 'package:flutter/material.dart';
import 'package:agroww_sih/screens/analytics/analytics_screen.dart';
import 'package:agroww_sih/screens/features/take_action_screen.dart';
import 'package:agroww_sih/screens/home/home_screen.dart';
import 'package:agroww_sih/screens/features/chatbot_screen.dart';
import 'package:agroww_sih/screens/field/farmland_map_screen.dart';

/// Custom bottom navigation bar for agronomists with 5 items
class CustomBottomNavBar extends StatelessWidget {
  /// Currently selected index (0-4)
  /// 0: Analytics, 1: Take Action, 2: Home, 3: Chatbot, 4: Your Fields
  final int selectedIndex;

  const CustomBottomNavBar({
    super.key,
    required this.selectedIndex,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(28),
        topRight: Radius.circular(28),
      ),
      child: Stack(
        children: [
          // Background image layer
          Positioned.fill(
            child: Image.asset(
              'assets/backdown.png',
              fit: BoxFit.cover,
            ),
          ),
          // Navigation items container
          Container(
            height: 95,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: SafeArea(
              top: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Analytics
                  _buildNavItem(
                    context: context,
                    iconPath: 'assets/icons/Anlaytics icon.png',
                    index: 0,
                    destination: const AnalyticsScreen(),
                  ),
                  // Take Action
                  _buildNavItem(
                    context: context,
                    iconPath: 'assets/icons/Take Action Icon.png',
                    index: 1,
                    destination: const TakeActionScreen(),
                  ),
                  // Home (center, larger)
                  _buildHomeNavItem(
                    context: context,
                    index: 2,
                    destination: const HomeScreen(),
                  ),
                  // Chatbot
                  _buildNavItem(
                    context: context,
                    iconPath: 'assets/icons/Chatbot.png',
                    index: 3,
                    destination: const ChatbotScreen(),
                  ),
                  // Your Fields
                  _buildNavItem(
                    context: context,
                    iconPath: 'assets/icons/Your fields.png',
                    index: 4,
                    destination: const FarmlandMapScreen(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build standard navigation item with custom icon
  Widget _buildNavItem({
    required BuildContext context,
    required String iconPath,
    required int index,
    required Widget destination,
  }) {
    final bool isSelected = selectedIndex == index;
    
    return GestureDetector(
      onTap: () {
        if (index != selectedIndex) {
          // Use pushReplacement with fade transition
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => destination,
              transitionDuration: const Duration(milliseconds: 200),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
            ),
          );
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFC6F68D) // Lime green when selected
              : Colors.white.withValues(alpha: 0.12), // Subtle white when not
          borderRadius: BorderRadius.circular(16),
          border: isSelected 
              ? null 
              : Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
        ),
        child: Center(
          child: Image.asset(
            iconPath,
            width: 34,
            height: 34,
            color: isSelected 
                ? const Color(0xFF0F2420) // Dark when selected
                : Colors.white, // White when not
          ),
        ),
      ),
    );
  }

  /// Build home navigation item (center, slightly larger)
  Widget _buildHomeNavItem({
    required BuildContext context,
    required int index,
    required Widget destination,
  }) {
    final bool isSelected = selectedIndex == index;
    
    return GestureDetector(
      onTap: () {
        if (index != selectedIndex) {
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => destination,
              transitionDuration: const Duration(milliseconds: 200),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
            ),
          );
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 65, // Slightly larger
        height: 65,
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFC6F68D)
              : Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(18),
          border: isSelected 
              ? null 
              : Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
        ),
        child: Center(
          child: Icon(
            Icons.home_rounded,
            size: 38,
            color: isSelected 
                ? const Color(0xFF0F2420)
                : Colors.white,
          ),
        ),
      ),
    );
  }
}
