import 'package:flutter/material.dart';
import 'coming_soon_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _goComingSoon(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ComingSoonScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D986A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF167339),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Settings',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          children: [
            // Profile card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  colors: [Color(0xFF003A2A), Color(0x00003A2A)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 58,
                    backgroundColor: Colors.white24,
                    child: CircleAvatar(
                      radius: 52,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.person, size: 56, color: Color(0xFF167339)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _pillButton(
                    context: context,
                    label: 'Edit Profile',
                    trailing: const Icon(Icons.edit, color: Color(0xFF167339)),
                    onTap: () => _goComingSoon(context),
                  ),
                  const SizedBox(height: 10),
                  _pillButton(
                    context: context,
                    label: 'Change Password',
                    onTap: () => _goComingSoon(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // List section
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.18),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  _listButton(
                    label: 'Coordinates History',
                    onTap: () => _goComingSoon(context),
                  ),
                  _listButton(
                    label: 'App Tutorial',
                    onTap: () => _goComingSoon(context),
                  ),
                  _listButton(
                    label: 'Notifications',
                    onTap: () => _goComingSoon(context),
                  ),
                  _listButton(
                    label: 'Privacy & Security',
                    onTap: () => _goComingSoon(context),
                  ),
                  _listButton(
                    label: 'About',
                    onTap: () => _goComingSoon(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Bottom home chip (static)
            Center(
              child: Container(
                height: 56,
                width: 96,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF003A2A), Color(0xFF167339)],
                  ),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Center(
                  child: Icon(Icons.home, color: Colors.white, size: 28),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pillButton({
    required BuildContext context,
    required String label,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.green[100],
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF0D3F2C),
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
        ),
      ),
    );
  }

  Widget _listButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Material(
        color: Colors.green[200],
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFF0D3F2C),
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right, color: Color(0xFF167339)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
