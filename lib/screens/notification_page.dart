import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  // Initial notifications data
  final List<Map<String, dynamic>> _initialNotifications = [
    {
      'date': '2/12/2025',
      'time': '10:21 A.M.',
      'delay': 100,
    },
    {
      'date': '23/11/2025',
      'time': '3:30 P.M.',
      'delay': 200,
    },
    {
      'date': '11/11/2025',
      'time': '11:30 A.M.',
      'delay': 300,
    },
  ];

  late List<Map<String, dynamic>> _notifications;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadNotifications(); // Call _loadNotifications instead of initializing from _initialNotifications
  }

  Future<void> _loadNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? saved = prefs.getStringList('notifications');
    
    if (saved != null) {
      setState(() {
        _notifications = saved.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
      });
    } else {
      setState(() {
        _notifications = [];
      });
    }
  }

  void _toggleNotifications() {
    // For now, just a placeholder or could load more from history if we had pagination
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F5F3), // Light greenish-white background
      body: Stack(
        children: [
          // Header Background
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Image.asset(
              'assets/backsmall.png',
              fit: BoxFit.fitWidth,
              alignment: Alignment.topCenter,
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                // Custom App Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 0.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Back Button
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3), // Changed withValues to withOpacity
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          'Notifications',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white, // White text
                            fontSize: 20, 
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 40), // Balance the back button container (approx size)
                    ],
                  ),
                ),

                const SizedBox(height: 30), // Increased breathing room

                // Search Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05), // Changed withValues to withOpacity
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.search, color: Color(0xFF0D4F40), size: 24),
                        SizedBox(width: 12),
                        Text(
                          'Search',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn().slideY(begin: -0.2, end: 0),

                const SizedBox(height: 20),

                // Notification List
                Expanded(
                  child: _notifications.isEmpty 
                    ? const Center(child: Text("No notifications yet"))
                    : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    itemCount: _notifications.length, // Removed +1 for the button
                    itemBuilder: (context, index) {
                      // Removed the button logic from here
                      final notification = _notifications[index];
                      return _buildNotificationCard(
                        title: notification['title'] ?? 'No Title',
                        body: notification['body'] ?? 'No Body',
                        date: notification['date'] ?? '',
                        time: notification['time'] ?? '',
                        delay: (index * 100), // Adjusted delay calculation
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard({
    required String title,
    required String body,
    required String date,
    required String time,
    required int delay,
  }) {
    return Container(
      // Removed fixed height
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF7A918D), // Muted green/gray color
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1), // Changed withValues to withOpacity
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column( // Changed from Stack to Column
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end, // Aligned to end
            children: [
              Text(
                "$date $time", // Combined date and time
                style: const TextStyle(
                  color: Colors.black54, // Changed color
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: delay.ms).slideX(begin: -0.1, end: 0);
  }
}
