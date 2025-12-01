import 'package:agroww_sih/screens/camera_screen.dart';
import 'package:agroww_sih/screens/gallery_screen.dart';
import 'package:agroww_sih/screens/export_reports_screen.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'coming_soon_screen.dart';
import 'settings_screen.dart';
import 'full_screen_map_page.dart';
import 'infographics_screen.dart';
import 'notification_page.dart';
import 'sidebar_drawer.dart';
import 'chatbot_screen.dart';
import 'locate_farmland_screen.dart';
import 'package:agroww_sih/services/notification_service.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  final List<String> menuItems = const [
    "Add a Farmland", "Add a Farmland 2", "Camera", "My Gallery",
    "News", "View Previous Analytics", "AI Chatbot", "Predicted Analytics & Data",
    "Analytics Page", "Mapped Analytics", "Infographics",
    "Export Analytic Report", "Download Raw Data",
    "View Map", "View Profile", "Settings"
  ];

  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _loadAvatar();
    
    // Listen for foreground messages
    NotificationService.onMessageReceived.addListener(() {
      final message = NotificationService.onMessageReceived.value;
      if (message != null && message.notification != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.notification!.title ?? 'New Notification',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(message.notification!.body ?? ''),
                ],
              ),
              backgroundColor: const Color(0xFF167339),
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: 'VIEW',
                textColor: Colors.white,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NotificationPage()),
                  );
                },
              ),
            ),
          );
        }
      }
    });
  }

  Future<void> _loadAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _avatarUrl = prefs.getString('user_avatar_url');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D986A),
      drawer: const SidebarDrawer(),
      body: Builder(
        builder: (context) {
          return SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(child: _buildMenuList(context)),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: const HomeNavBar(),
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
            child: CircleAvatar(
              radius: 22,
              backgroundColor: Colors.white,
              backgroundImage: _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
              child: _avatarUrl == null 
                  ? const Icon(Icons.menu, color: Color(0xFF0D986A), size: 28)
                  : null,
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
    );
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
      child: SingleChildScrollView(
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
                child: GestureDetector(
                  onTap: () {
                    if (item == "Add a Farmland") {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LocateFarmlandScreen(),
                        ),
                      );
                    } else if (item == "Add a Farmland 2") {
                      Navigator.pushNamed(context, '/farmland-map');
                    } else if (item == "Camera") {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CameraScreen(),
                        ),
                      );
                    } else if (item == "My Gallery") {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const GalleryScreen(),
                        ),
                      );
                    } else if (item == "Export Analytic Report") {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ExportReportsScreen(),
                        ),
                      );
                    } else if (item == "News" || 
                               item == "View Previous Analytics" || 
                               item == "Predicted Analytics & Data") {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ComingSoonScreen(),
                        ),
                      );
                    } else if (item == "AI Chatbot") {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ChatbotScreen(),
                        ),
                      );
                    } else if (item == "Mapped Analytics") {
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
                      Navigator.pushNamed(context, '/profile').then((_) => _loadAvatar()); // Refresh avatar on return
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
              );
            }),
          ],
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


