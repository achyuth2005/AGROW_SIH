/// ============================================================================
/// FILE: farmers_bottom_nav_bar.dart
/// ============================================================================
/// PURPOSE: Simplified 4-item bottom navigation bar for farmers.
///          Designed with fewer options for easier navigation.
/// 
/// NAVIGATION ITEMS:
///   0: Home    - Main farmer dashboard
///   1: Tools   - Take Action recommendations
///   2: Fields  - Field management and mapping
///   3: Chatbot - AI assistant
/// 
/// DESIGN FEATURES:
///   - Background image (assets/backdown.png)
///   - Rounded top corners (borderRadius: 28)
///   - Animated selection state (lime green background)
///   - Material icons (simpler than custom assets)
///   - Fade transition between screens
/// ============================================================================

import 'package:flutter/material.dart';
import 'package:agroww_sih/screens/home/farmers_home_screen.dart';
import 'package:agroww_sih/screens/features/take_action_screen.dart';
import 'package:agroww_sih/screens/field/farmland_map_screen.dart';
import 'package:agroww_sih/screens/features/chatbot_screen.dart';

/// Simplified bottom navigation bar for farmers with 4 items
class FarmersBottomNavBar extends StatelessWidget {
  /// Currently selected index (0-3)
  /// 0: Home, 1: Tools, 2: Fields, 3: Chatbot
  /// Set to -1 if no item should be highlighted
  final int selectedIndex;

  const FarmersBottomNavBar({
    super.key,
    required this.selectedIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      clipBehavior: Clip.antiAlias,
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
            height: 80,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: SafeArea(
              top: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(
                    context: context,
                    icon: Icons.home_rounded,
                    label: 'Home',
                    index: 0,
                    onTap: () => _navigateTo(context, 0),
                  ),
                  _buildNavItem(
                    context: context,
                    icon: Icons.build_rounded,
                    label: 'Tools',
                    index: 1,
                    onTap: () => _navigateTo(context, 1),
                  ),
                  _buildNavItem(
                    context: context,
                    icon: Icons.map_rounded,
                    label: 'Fields',
                    index: 2,
                    onTap: () => _navigateTo(context, 2),
                  ),
                  _buildNavItem(
                    context: context,
                    icon: Icons.chat_bubble_rounded,
                    label: 'Chatbot',
                    index: 3,
                    onTap: () => _navigateTo(context, 3),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  /// Navigate to the appropriate screen with fade transition
  void _navigateTo(BuildContext context, int index) {
    if (index == selectedIndex) return; // Already on this screen
    
    Widget destination;
    switch (index) {
      case 0:
        destination = const FarmersHomeScreen();
        break;
      case 1:
        destination = const TakeActionScreen();
        break;
      case 2:
        destination = const FarmlandMapScreen();
        break;
      case 3:
        destination = const ChatbotScreen();
        break;
      default:
        return;
    }
    
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => destination,
        transitionDuration: const Duration(milliseconds: 150),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  /// Build individual navigation item with Material icon
  Widget _buildNavItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required int index,
    required VoidCallback onTap,
  }) {
    final bool isSelected = selectedIndex == index;
    
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFC6F68D) // Lime green when selected
              : Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: Icon(
            icon,
            size: 26,
            color: isSelected 
                ? const Color(0xFF0F2420) // Dark when selected
                : Colors.white,
          ),
        ),
      ),
    );
  }
}
