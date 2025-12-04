import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'coming_soon_screen.dart';
import 'main_menu_screen.dart';

import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _userName = "User";

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('user_full_name') ?? "User";
    });
  }

  void _goComingSoon(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ComingSoonScreen()),
    );
  }

  Future<void> _logout(BuildContext context) async {
    try {
      await GoogleSignIn().signOut();
      await FirebaseAuth.instance.signOut();
      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error logging out: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D986A),
      body: Column(
        children: [
          // Custom Header
          Stack(
            children: [
              Image.asset(
                'assets/backsmall.png',
                width: double.infinity,
                fit: BoxFit.fitWidth,
                alignment: Alignment.topCenter,
              ),
              Positioned(
                top: 50,
                left: 20,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 24),
                  ),
                ),
              ),
              const Positioned(
                top: 50,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    'Settings',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          // Content
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
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
                          const SizedBox(height: 12),
                          Text(
                            _userName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            "Farmer", // Placeholder or load from prefs if we had role
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _pillButton(
                            context: context,
                            label: 'Edit Profile',
                            trailing: const Icon(Icons.edit, color: Color(0xFF167339)),
                            onTap: () => Navigator.pushNamed(context, '/profile'),
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
                            label: 'Legacy Main Menu',
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MainMenuScreen())),
                            delay: 250,
                            icon: Icons.history,
                          ),
                          _listButton(
                            label: 'All Features',
                            onTap: () => Navigator.pushNamed(context, '/main-menu-list'),
                            delay: 300,
                            icon: Icons.list_alt,
                          ),
                          _listButton(
                            label: 'Language',
                            onTap: () => Navigator.pushNamed(context, '/language-selection'),
                            delay: 350,
                            icon: Icons.language,
                          ),
                          _listButton(
                            label: 'Coordinates History',
                            onTap: () => _goComingSoon(context),
                            delay: 400,
                          ),
                          _listButton(
                            label: 'App Tutorial',
                            onTap: () => _goComingSoon(context),
                            delay: 500,
                          ),
                          _listButton(
                            label: 'Notifications',
                            onTap: () => _goComingSoon(context),
                            delay: 600,
                          ),
                          _listButton(
                            label: 'Privacy & Security',
                            onTap: () => _goComingSoon(context),
                            delay: 700,
                          ),
                          _listButton(
                            label: 'About',
                            onTap: () => _goComingSoon(context),
                            delay: 800,
                          ),
                          _listButton(
                            label: 'Logout',
                            onTap: () => _logout(context),
                            delay: 900,
                            icon: Icons.logout,
                            isDestructive: true,
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
            ),
          ),
        ],
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
    int delay = 0,
    IconData? icon,
    bool isDestructive = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Material(
        color: isDestructive ? Colors.red[50] : Colors.green[200],
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
                    style: TextStyle(
                      color: isDestructive ? Colors.red[700] : const Color(0xFF0D3F2C),
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
                Icon(
                  icon ?? Icons.chevron_right, 
                  color: isDestructive ? Colors.red[700] : const Color(0xFF167339)
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
