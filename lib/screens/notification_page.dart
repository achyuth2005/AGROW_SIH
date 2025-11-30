import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

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
    _notifications = List.from(_initialNotifications);
  }

  void _toggleNotifications() {
    setState(() {
      if (_isExpanded) {
        // Hide older notifications (reset to initial)
        _notifications = List.from(_initialNotifications);
        _isExpanded = false;
      } else {
        // Show older notifications (duplicate existing for demo)
        final olderNotifications = List<Map<String, dynamic>>.from(_initialNotifications);
        _notifications.addAll(olderNotifications);
        _isExpanded = true;
      }
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
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Back Button
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
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
                          color: Colors.black.withOpacity(0.05),
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
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    itemCount: _notifications.length + 1, // +1 for the button
                    itemBuilder: (context, index) {
                      if (index == _notifications.length) {
                        // View/Hide Older Notifications Button
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 20.0),
                          child: GestureDetector(
                            onTap: _toggleNotifications,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _isExpanded ? 'Hide Older Notifications' : 'View Older Notifications',
                                    style: const TextStyle(
                                      color: Color(0xFF0D4F40),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                    color: const Color(0xFF0D4F40),
                                  ),
                                ],
                              ),
                            ).animate().fadeIn(delay: 400.ms),
                          ),
                        );
                      }

                      final notification = _notifications[index];
                      return _buildNotificationCard(
                        date: notification['date'],
                        time: notification['time'],
                        delay: notification['delay'] ?? 0,
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
    required String date,
    required String time,
    required int delay,
  }) {
    return Container(
      height: 140, // Fixed height as per design
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF7A918D), // Muted green/gray color
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Content placeholder (if any text was needed, it would go here)
          
          // Date and Time at bottom left
          Positioned(
            bottom: 0,
            left: 0,
            child: Row(
              children: [
                Text(
                  date,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 20),
                Text(
                  time,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: delay.ms).slideX(begin: -0.1, end: 0);
  }
}
