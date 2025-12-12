/// ===========================================================================
/// MAIN MENU SCREEN
/// ===========================================================================
///
/// PURPOSE: Legacy grid-style main menu with all app features listed.
///          Provides central navigation hub for all functionality.
///
/// MENU ITEMS (16 options):
///   - Add a Farmland 1/2: Field registration flows
///   - Camera/Gallery: Image capture and viewing
///   - News: Agricultural news feed
///   - Analytics: AI-powered field analysis
///   - AI Chatbot: Conversational assistant
///   - Mapped/Infographics: Visual analytics
///   - Export/Download: Data export options
///   - View Map/Profile/Settings: Utility screens
///
/// KEY FEATURES:
///   - Search delegate for quick navigation
///   - FCM token sync for push notifications
///   - Sidebar drawer integration
///   - Foreground notification SnackBar display
///
/// DEPENDENCIES:
///   - NotificationService: Push notification handling
///   - FirebaseMessaging: FCM token management
///   - SharedPreferences: Avatar URL cache
/// ===========================================================================

import 'package:agroww_sih/screens/features/camera_screen.dart';
import 'package:agroww_sih/screens/features/gallery_screen.dart';
import 'package:agroww_sih/screens/misc/news_screen.dart';
import 'package:agroww_sih/screens/settings/export_reports_screen.dart';
import 'package:agroww_sih/screens/analytics/mapped_analytics_home_screen.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../misc/coming_soon_screen.dart';
import '../settings/settings_screen.dart';
import '../field/full_screen_map_page.dart';
import '../analytics/infographics_screen.dart';
import '../misc/notification_page.dart';
import '../settings/sidebar_drawer.dart';
import '../features/chatbot_screen.dart';
import '../field/locate_farmland_screen.dart';
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

    // Sync FCM Token
    _syncFcmToken();
  }

  Future<void> _syncFcmToken() async {
    try {
      String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await NotificationService.saveTokenToBackend(token);
      }
    } catch (e) {
      debugPrint("Error syncing FCM token in MainMenu: $e");
    }
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
      backgroundColor: const Color(0xFFE1EFEF), // Light mint background
      drawer: const SidebarDrawer(),
      body: Builder(
        builder: (context) {
          return Column(
            children: [
              _buildHeader(context),
              Expanded(child: _buildMenuList(context)),
            ],
          );
        },
      ),
      bottomNavigationBar: const HomeNavBar(),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Stack(
      children: [
        Image.asset(
          'assets/backsmall.png',
          width: double.infinity,
          fit: BoxFit.fitWidth,
          alignment: Alignment.topCenter,
        ),
        Positioned(
          top: 50,
          left: 16,
          right: 16,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () {
                  Scaffold.of(context).openDrawer();
                },
                child: _avatarUrl == null 
                      ? const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Icon(Icons.menu, color: Colors.white, size: 28),
                        )
                      : CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.white,
                          backgroundImage: NetworkImage(_avatarUrl!),
                        ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    final result = await showSearch(
                      context: context,
                      delegate: MenuSearchDelegate(menuItems),
                    );
                    if (result != null && result.isNotEmpty) {
                      _navigateToItem(result);
                    }
                  },
                  child: Container(
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: const Row(
                      children: [
                        SizedBox(width: 12),
                        Icon(Icons.search, color: Color(0xFF167339), size: 20),
                        SizedBox(width: 8),
                        Text("Search", style: TextStyle(color: Color(0xFF167339), fontSize: 14)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NotificationPage()),
                  );
                },
                child: const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Icon(
                    Icons.notifications_outlined,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMenuList(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 26),
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
      // Removed dark gradient
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Main Menu",
              style: TextStyle(
                color: Color(0xFF0F3C33), // Deep Forest Green
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...menuItems.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: GestureDetector(
                  onTap: () => _navigateToItem(item),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListTile(
                      dense: true,
                      title: Text(
                        item,
                        style: const TextStyle(
                          color: Color(0xFF0F3C33),
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      trailing: item == "Settings"
                          ? const Icon(Icons.settings, color: Color(0xFF167339))
                          : const Icon(Icons.arrow_forward_ios, color: Color(0xFF167339), size: 16),
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

  void _navigateToItem(String item) {
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
          builder: (_) => CameraScreen(),
        ),
      );
    } else if (item == "My Gallery") {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GalleryScreen(),
        ),
      );
    } else if (item == "Export Analytic Report") {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ExportReportsScreen(),
        ),
      );
    } else if (item == "News") {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NewsScreen(),
        ),
      );
    } else if (item == "View Previous Analytics" || 
               item == "Predicted Analytics & Data") {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const ComingSoonScreen(),
        ),
      );
    } else if (item == "Analytics Page") {
      Navigator.pushNamed(context, '/analytics');
    } else if (item == "AI Chatbot") {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatbotScreen(),
        ),
      );
    } else if (item == "Mapped Analytics") {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const MappedAnalyticsHomeScreen()));
    } else if (item == "Settings") {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SettingsScreen(),
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
          builder: (_) => InfographicsScreen(),
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
  }
}

class MenuSearchDelegate extends SearchDelegate<String> {
  final List<String> menuItems;

  MenuSearchDelegate(this.menuItems);

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, '');
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildList(context, query);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildList(context, query);
  }

  Widget _buildList(BuildContext context, String query) {
    final List<String> suggestions = query.isEmpty
        ? menuItems
        : menuItems.where((item) => item.toLowerCase().contains(query.toLowerCase())).toList();

    return ListView.builder(
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        final String item = suggestions[index];
        return ListTile(
          title: Text(item),
          onTap: () {
            close(context, item);
          },
        );
      },
    );
  }
}

class HomeNavBar extends StatelessWidget {
  const HomeNavBar({super.key});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamedAndRemoveUntil(context, '/main-menu', (route) => false);
      },
      child: Container(
        height: 60,
        decoration: const BoxDecoration(
          color: Color(0xFF167339),
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: const Center(
          child: Icon(Icons.home, color: Colors.white, size: 40),
        ),
      ),
    );
  }
}


