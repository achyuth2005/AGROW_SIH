import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class SidebarDrawer extends StatelessWidget {
  const SidebarDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    Future<void> logout() async {
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

    return Drawer(
      backgroundColor: const Color(0xFFE8F5F3), // Light mint background
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(0),
          bottomRight: Radius.circular(0),
        ),
      ),
      child: Column(
        children: [
          // Custom Header
          SizedBox(
            height: 160,
            child: Stack(
              children: [
                // Content
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Back Button (Close Drawer)
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.05),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_back_ios_new,
                              color: Colors.black,
                              size: 18,
                            ),
                          ),
                        ),
                        const Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(right: 40),
                            child: Text(
                              "Settings & Activity",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Menu Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              children: [
                _buildMenuItem(context, icon: Icons.person_outline, title: "Profile", onTap: () => Navigator.pushNamed(context, '/profile')),
                _buildMenuItem(context, icon: Icons.download_outlined, title: "Export Detailed Reports", onTap: () {}),
                _buildMenuItem(context, icon: Icons.translate, title: "Language Preference", onTap: () {}),
                _buildMenuItem(context, icon: Icons.settings_outlined, title: "Permissions", onTap: () {}),
                _buildMenuItem(context, icon: Icons.shield_outlined, title: "Privacy and Security", onTap: () {}),
                _buildMenuItem(context, icon: Icons.chat_bubble_outline, title: "Feedback", onTap: () {}),
                _buildMenuItem(context, icon: Icons.help_outline, title: "Help and Support", onTap: () {}),
                _buildMenuItem(context, icon: Icons.play_circle_outline, title: "App tutorial", onTap: () {}),
                _buildMenuItem(context, icon: Icons.help_center_outlined, title: "FAQs", onTap: () {}),
                
                // Log out
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: GestureDetector(
                    onTap: () {
                      logout();
                    },
                    child: const Row(
                      children: [
                        Icon(Icons.logout, color: Colors.redAccent),
                        SizedBox(width: 12),
                        Text(
                          "Log out",
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),


        ],
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, {required IconData icon, required String title, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(30),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: const Color(0xFF0F3C33), size: 22),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF0F3C33),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, color: Color(0xFF0F3C33), size: 14),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn().slideX(begin: -0.1, end: 0);
  }
}


