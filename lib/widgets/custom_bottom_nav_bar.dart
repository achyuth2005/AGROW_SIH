import 'package:flutter/material.dart';
import 'package:agroww_sih/screens/analytics_screen.dart';
import 'package:agroww_sih/screens/take_action_screen.dart';
import 'package:agroww_sih/screens/home_screen.dart';
import 'package:agroww_sih/screens/chatbot_screen.dart';
import 'package:agroww_sih/screens/farmland_map_screen.dart';

/// Custom bottom navigation bar matching the app's design language.
class CustomBottomNavBar extends StatelessWidget {
  /// The currently selected navigation index (0-4)
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
          // Background image
          Positioned.fill(
            child: Image.asset(
              'assets/backdown.png',
              fit: BoxFit.cover,
            ),
          ),
          Container(
            height: 95,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: SafeArea(
              top: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildNavItem(
                    context: context,
                    iconPath: 'assets/icons/Anlaytics icon.png',
                    index: 0,
                    destination: const AnalyticsScreen(),
                  ),
                  _buildNavItem(
                    context: context,
                    iconPath: 'assets/icons/Take Action Icon.png',
                    index: 1,
                    destination: const TakeActionScreen(),
                  ),
                  _buildHomeNavItem(
                    context: context,
                    index: 2,
                    destination: const HomeScreen(),
                  ),
                  _buildNavItem(
                    context: context,
                    iconPath: 'assets/icons/Chatbot.png',
                    index: 3,
                    destination: const ChatbotScreen(),
                  ),
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
              ? const Color(0xFFC6F68D) // Bright lime green for selected
              : Colors.white.withValues(alpha: 0.12), // Subtle white box for unselected
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
                : Colors.white, // White when not selected
          ),
        ),
      ),
    );
  }

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
        width: 65,
        height: 65,
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFC6F68D) // Bright lime green for selected
              : Colors.white.withValues(alpha: 0.12), // Subtle white box for unselected
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
                ? const Color(0xFF0F2420) // Dark when selected
                : Colors.white, // White when not selected
          ),
        ),
      ),
    );
  }
}

