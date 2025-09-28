import 'dart:math';
import 'package:flutter/material.dart';
import 'coming_soon_screen.dart';
import 'settings_screen.dart';
import 'full_screen_map_page.dart';
import 'infographics_screen.dart';
import 'coordinate_entry_screen.dart';
import 'notification_page.dart';

class MainMenuScreen extends StatelessWidget {
  final List<String> menuItems = const [
    "Analytics Page", "Mapped Analytics", "Infographics",
    "Export Analytic Report", "Download Raw Data",
    "View Map", "Settings"
  ];

  const MainMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D986A),
      body: SafeArea(
        child: Column(
          children: [
            // Top profile + search + notification (perfectly matched)
            Padding(
              padding: const EdgeInsets.all(18.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, color: Color(0xFF0D986A), size: 28),
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
            ),

            // Main menu list
            Container(
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
                  ...menuItems.map((item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
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
                      ),
                    ),
                  )),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Widgets grid
            Flexible(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final diPad = MediaQuery.of(context).viewPadding.bottom;
                  final diInset = MediaQuery.of(context).viewInsets.bottom;
                  final bottomPad = max(diPad, diInset) + 10;
                  final maxHeight = constraints.maxHeight - bottomPad;

                  return Padding(
                    padding: EdgeInsets.only(
                        left: 18, right: 18, top: 10, bottom: bottomPad),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: maxHeight > 0 ? maxHeight : 0,
                      ),
                      child: GridView.count(
                        crossAxisCount: 2,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 1,
                        children: [
                          WidgetButton(
                            icon: Icons.newspaper,
                            label: "News",
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
                            icon: Icons.insights,
                            label: "Predicted Analytics & Data",
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
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const HomeNavBar(),
    );
  }
}

class WidgetButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  const WidgetButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.green[100],
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onPressed,
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
    );
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
