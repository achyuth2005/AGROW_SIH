import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class NotificationPage extends StatelessWidget {
  const NotificationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D986A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF167339),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 21,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
            children: [
              ...[
                {
                  'title': 'Soil moisture alert',
                  'subtitle': 'Field 3 is below 30% threshold – irrigation advised'
                },
                {
                  'title': 'NDVI Weekly Update',
                  'subtitle': 'Vegetation health improving in Zone North after rain.'
                },
                {
                  'title': 'Fertilizer application',
                  'subtitle': 'Recommended timing: Tomorrow 9 AM for best absorption.'
                }
              ].asMap().entries.map((entry) {
                final index = entry.key;
                final notif = entry.value;
                return Card(
                  color: Colors.green[100],
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    title: Text(
                      notif['title']!,
                      style: const TextStyle(
                        color: Color(0xFF167339),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      notif['subtitle']!,
                      style: const TextStyle(color: Color(0xFF167339)),
                    ),
                    leading: const Icon(Icons.notifications_active, color: Color(0xFF167339)),
                  ),
                ).animate().fadeIn(delay: (index * 100).ms).slideX(begin: -0.1, end: 0);
              }),
            ],
          ),
        ),
      ),
    );
  }
}
