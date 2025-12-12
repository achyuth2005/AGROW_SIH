/// ===========================================================================
/// KNOWLEDGE HUB SCREEN
/// ===========================================================================
///
/// PURPOSE: Educational content hub for farmers (placeholder).
///          Will contain tutorials, best practices, and guides.
///
/// PLANNED FEATURES:
///   - Farming best practices articles
///   - Video tutorials
///   - Seasonal crop guides
///   - Pest/disease identification guides
///
/// CURRENT STATE:
///   - "Coming Soon" placeholder UI
///   - Icon and message indicating feature in development
/// ===========================================================================

import 'package:flutter/material.dart';
import 'package:agroww_sih/widgets/adaptive_bottom_nav_bar.dart';

class KnowledgeHubPlaceholderScreen extends StatelessWidget {
  const KnowledgeHubPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E9),
      appBar: AppBar(
        title: const Text('Knowledge Hub'),
        centerTitle: true,
        backgroundColor: const Color(0xFF0D986A),
      ),
      bottomNavigationBar: const AdaptiveBottomNavBar(page: ActivePage.home),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)
                ]
              ),
              child: const Icon(Icons.menu_book, size: 60, color: Color(0xFF1B4D3E)),
            ),
            const SizedBox(height: 20),
            const Text(
              'Coming Soon',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B4D3E),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'We are working on this feature.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
