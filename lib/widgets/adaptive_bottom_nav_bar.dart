/// ============================================================================
/// FILE: adaptive_bottom_nav_bar.dart
/// ============================================================================
/// PURPOSE: Provides a role-aware bottom navigation bar that automatically
///          switches between farmer and agronomist layouts based on user role.
/// 
/// WHY ADAPTIVE?
///   Farmers and agronomists have different needs:
///   - Farmers: Simplified 4-item nav (Home, Tools, Fields, Chatbot)
///   - Agronomists: 5-item nav with Analytics as first item
/// 
/// USAGE:
///   AdaptiveBottomNavBar(page: ActivePage.home)
///   // Automatically shows correct nav bar based on UserRoleProvider
/// ============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/user_role_provider.dart';
import 'custom_bottom_nav_bar.dart';
import 'farmers_bottom_nav_bar.dart';

/// Enum to identify the current page for navigation mapping
/// Used to highlight the correct nav item regardless of role
enum ActivePage {
  home,       // Main dashboard
  analytics,  // Analytics/charts screen (agronomist only)
  tools,      // Take Action screen
  chatbot,    // AI chatbot
  fields,     // Field management/map
  profile,    // User profile (unused in current nav)
  none        // No item highlighted
}

/// Adaptive bottom navigation bar that switches based on user role.
/// Automatically maps the logical page to the correct index for each role's nav bar.
class AdaptiveBottomNavBar extends StatelessWidget {
  /// Which page is currently active
  final ActivePage page;

  const AdaptiveBottomNavBar({
    super.key,
    required this.page,
  });

  /// Constructor for backward compatibility with simple index (deprecated)
  /// Prefer using the `page` parameter instead
  const AdaptiveBottomNavBar.fromIndex({
    super.key, 
    required int selectedIndex,
  }) : page = ActivePage.none;

  @override
  Widget build(BuildContext context) {
    // Watch the provider to rebuild when role changes
    final roleProvider = Provider.of<UserRoleProvider>(context);
    
    if (roleProvider.isFarmer) {
      // Farmers: 4 items - Home(0), Tools(1), Fields(2), Chatbot(3)
      int index = -1;
      switch (page) {
        case ActivePage.home: 
          index = 0; 
          break;
        case ActivePage.tools: 
          index = 1; 
          break;
        case ActivePage.fields: 
          index = 2; 
          break;
        case ActivePage.chatbot: 
          index = 3; 
          break;
        default: 
          index = -1;
      }
      return FarmersBottomNavBar(selectedIndex: index);
    } else {
      // Agronomist: 5 items - Analytics(0), Take Action(1), Home(2), Chatbot(3), Fields(4)
      int index = -1;
      switch (page) {
        case ActivePage.analytics: 
          index = 0; 
          break;
        case ActivePage.tools: 
          index = 1; 
          break;
        case ActivePage.home: 
          index = 2; 
          break;
        case ActivePage.chatbot: 
          index = 3; 
          break;
        case ActivePage.fields: 
          index = 4; 
          break;
        default: 
          index = -1;
      }
      return CustomBottomNavBar(selectedIndex: index);
    }
  }
}
