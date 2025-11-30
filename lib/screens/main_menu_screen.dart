import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'coming_soon_screen.dart';
import 'settings_screen.dart';
import 'full_screen_map_page.dart';
import 'infographics_screen.dart';
import 'coordinate_entry_screen.dart';
import 'notification_page.dart';
import 'sidebar_drawer.dart';
import 'chatbot_screen.dart';

class MainMenuScreen extends StatelessWidget {
  final List<String> menuItems = const [
    "Analytics Page", "Mapped Analytics", "Infographics",
    "Export Analytic Report", "Download Raw Data",
    "View Map", "View Profile", "Settings"
  ];

  const MainMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D986A),
      drawer: const SidebarDrawer(),
      body: Builder(
        builder: (context) {
          return SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWeb = constraints.maxWidth > 900;

            if (isWeb) {
              return Row(
                children: [
                  // Left Side: Menu
                  SizedBox(
                    width: 400,
                    child: Column(
                      children: [
                        _buildHeader(context),
                        Expanded(child: _buildMenuList(context)),
                      ],
                    ),
                  ),
                  // Right Side: Widgets
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: _buildWidgetGrid(context, isWeb: true),
                    ),
                  ),
                ],
              );
            } else {
              // Mobile Layout
              return Column(
                children: [
                  _buildHeader(context),
                  _buildMenuList(context),
                  const SizedBox(height: 18),
                  Expanded(child: _buildWidgetGrid(context, isWeb: false)),
                ],
              );
            }
          },
        ),
          );
        },
      ),
      bottomNavigationBar: const HomeNavBar().animate().slideY(begin: 1, end: 0, duration: 600.ms, curve: Curves.easeOutBack),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(18.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () {
              Scaffold.of(context).openDrawer();
            },
            child: const CircleAvatar(
              radius: 22,
              backgroundColor: Colors.white,
              child: Icon(Icons.menu, color: Color(0xFF0D986A), size: 28),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.green.shade300,
                borderRadius: BorderRadius.circular(25),
              ),
              child: const Row(
                children: [
                  SizedBox(width: 12),
                  Icon(Icons.search, color: Color(0xFF167339)),
                  SizedBox(width: 8),
                  Text("Search", style: TextStyle(color: Color(0xFF167339))),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationPage()),
              );
            },
            child: CircleAvatar(
              radius: 22,
              backgroundColor: Colors.green[100],
              child: const Icon(
                Icons.notifications,
                color: Color(0xFF167339),
                size: 28,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.3, end: 0, curve: Curves.easeOutQuad);
  }

  Widget _buildMenuList(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 26),
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF000000), Color(0x00000000)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "Main Menu",
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          ...menuItems.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: _ScaleButton(
                onTap: () {
                  if (item == "Mapped Analytics") {
                    Navigator.pushNamed(context, '/coordinate-entry');
                  } else if (item == "Settings") {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SettingsScreen(),
                      ),
                    );
                  } else if (item == "View Map") {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const FullScreenMapPage(),
                      ),
                    );
                  } else if (item == "View Profile") {
                    Navigator.pushNamed(context, '/profile');
                  } else if (item == "Infographics") {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const InfographicsScreen(),
                      ),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ComingSoonScreen(),
                      ),
                    );
                  }
                },
                child: Material(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(15),
                  child: ListTile(
                    dense: true,
                    title: Text(
                      item,
                      style: const TextStyle(
                        color: Color(0xFF167339),
                        fontWeight: FontWeight.w400,
                        fontSize: 15,
                      ),
                    ),
                    trailing: item == "Settings"
                        ? const Icon(Icons.settings, color: Color(0xFF167339))
                        : null,
                  ),
                ),
              ),
            ).animate().fadeIn(delay: (200 + (index * 50)).ms, duration: 400.ms).slideX(begin: -0.1, end: 0, curve: Curves.easeOut);
          }),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms, duration: 600.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuad);
  }

  Widget _buildWidgetGrid(BuildContext context, {required bool isWeb}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // For web, we want to fill the available space.
        // For mobile, we calculate based on bottom padding.
        double maxHeight = constraints.maxHeight;
        
        if (!isWeb) {
            final diPad = MediaQuery.of(context).viewPadding.bottom;
            final diInset = MediaQuery.of(context).viewInsets.bottom;
            final bottomPad = max(diPad, diInset) + 10;
            maxHeight = constraints.maxHeight - bottomPad;
        }

        return Padding(
          padding: isWeb 
            ? const EdgeInsets.all(18)
            : EdgeInsets.only(left: 18, right: 18, top: 10, bottom: 10), // Adjusted padding
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: maxHeight > 0 ? maxHeight : 0,
            ),
            child: GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: isWeb ? 1.5 : 1, // Wider cards on web
              children: [
                WidgetButton(
                  icon: Icons.newspaper,
                  label: "News",
                  delay: 600,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ComingSoonScreen(),
                      ),
                    );
                  },
                ),
                WidgetButton(
                  icon: Icons.bar_chart,
                  label: "View Previous Analytics",
                  delay: 700,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ComingSoonScreen(),
                      ),
                    );
                  },
                ),
                WidgetButton(
                  icon: Icons.chat_bubble_outline,
                  label: "AI Chatbot",
                  delay: 800,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ChatbotScreen(),
                      ),
                    );
                  },
                ),
                WidgetButton(
                  icon: Icons.insights,
                  label: "Predicted Analytics & Data",
                  delay: 900,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ComingSoonScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class WidgetButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final int delay;

  const WidgetButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.delay = 0,
  });

  @override
  Widget build(BuildContext context) {
    return _ScaleButton(
      onTap: onPressed,
      child: Material(
        color: Colors.green[100],
        borderRadius: BorderRadius.circular(18),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 44, color: const Color(0xFF167339)),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.all(4.0),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF167339),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: delay.ms, duration: 500.ms).scale(delay: delay.ms, curve: Curves.easeOutBack);
  }
}

class HomeNavBar extends StatelessWidget {
  const HomeNavBar({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      decoration: const BoxDecoration(
        color: Color(0xFF167339),
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: const Center(
        child: Icon(Icons.home, color: Colors.white, size: 40),
      ),
    );
  }
}

class _ScaleButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _ScaleButton({required this.child, required this.onTap});

  @override
  State<_ScaleButton> createState() => _ScaleButtonState();
}

class _ScaleButtonState extends State<_ScaleButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.95).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: widget.child,
      ),
    );
  }
}
