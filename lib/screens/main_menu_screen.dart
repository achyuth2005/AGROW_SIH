import 'dart:math';

import 'package:flutter/material.dart';
import 'coming_soon_screen.dart';

class MainMenuScreen extends StatelessWidget {
  final List<String> menuItems = [
    "Analytics Page", "Mapped Analytics", "Infographics",
    "Export Analytic Report", "Download Raw Data",
    "View Map", "Settings"
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D986A),
      body: SafeArea(
        child: Column(
          children: [
            // Top profile + search
            Padding(
              padding: const EdgeInsets.all(18.0),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, color: const Color(0xFF0D986A)),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.green.shade300,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Row(
                        children: const [
                          SizedBox(width: 12),
                          Icon(Icons.search, color: Color(0xFF167339)),
                          SizedBox(width: 8),
                          Text("Search", style: TextStyle(color: Color(0xFF167339))),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Main menu
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 26),
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF000000),
                    Color(0x00000000),
                  ],
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
                        trailing: item == "Settings" ? const Icon(Icons.arrow_drop_down) : null,
                        onTap: () {
                          if (item == "View Map") {
                            Navigator.pushNamed(context, '/coordinate-entry');
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => ComingSoonScreen()),
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
            // Widgets area with dynamic bottom padding considering nav bar and system UI
            Flexible(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  double diPad = MediaQuery.of(context).viewPadding.bottom;
                  double diInset = MediaQuery.of(context).viewInsets.bottom;
                  double bottomPad = max(diPad, diInset) + 10;
                  double maxHeight = constraints.maxHeight - bottomPad;

                  return Padding(
                    padding: EdgeInsets.only(left: 18, right: 18, top: 10, bottom: bottomPad),
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
                                MaterialPageRoute(builder: (context) => ComingSoonScreen()),
                              );
                            },
                          ),
                          WidgetButton(
                            icon: Icons.bar_chart,
                            label: "View Previous Analytics",
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => ComingSoonScreen()),
                              );
                            },
                          ),
                          WidgetButton(
                            icon: Icons.chat_bubble_outline,
                            label: "AI Chatbot",
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => ComingSoonScreen()),
                              );
                            },
                          ),
                          WidgetButton(
                            icon: Icons.insights,
                            label: "Predicted Analytics & Data",
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => ComingSoonScreen()),
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
    Key? key,
    required this.icon,
    required this.label,
    required this.onPressed,
  }) : super(key: key);
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
  const HomeNavBar({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: const Color(0xFF167339),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: const Center(
        child: Icon(Icons.home, color: Colors.white, size: 40),
      ),
    );
  }
}
