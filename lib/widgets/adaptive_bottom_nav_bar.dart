import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/user_role_provider.dart';
import 'custom_bottom_nav_bar.dart';
import 'farmers_bottom_nav_bar.dart';

/// Enum to identify the current page for navigation mapping
enum ActivePage {
  home,
  analytics,
  tools, // Take Action
  chatbot,
  fields,
  profile,
  none
}

/// Adaptive bottom navigation bar that switches based on user role
/// Automatically maps the logical page to the correct index for each role's nav bar
class AdaptiveBottomNavBar extends StatelessWidget {
  final ActivePage page;

  const AdaptiveBottomNavBar({
    super.key,
    required this.page,
  });

  // Constructor for backward compatibility with simple index (deprecated use)
  const AdaptiveBottomNavBar.fromIndex({
    super.key, 
    required int selectedIndex,
  }) : page = ActivePage.none; // This fallback is risky, prefer using page

  @override
  Widget build(BuildContext context) {
    // Watch the provider to rebuild when role changes
    final roleProvider = Provider.of<UserRoleProvider>(context);
    
    if (roleProvider.isFarmer) {
      // Farmers: 0=Home, 1=Tools, 2=Fields, 3=Profile
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
      // Custom (Agronomist): 0=Analytics, 1=Take Action, 2=Home, 3=Chatbot, 4=My Fields
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
