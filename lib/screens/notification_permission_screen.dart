import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationPermissionScreen extends StatelessWidget {
  const NotificationPermissionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const Color primaryDark = Color(0xFF0F3C33);
    const Color backgroundLight = Color(0xFFE1EFEF);

    return Scaffold(
      backgroundColor: backgroundLight,
      body: Column(
        children: [
          // Header with Background Image
          Image.asset(
            'assets/backsmall.png',
            width: double.infinity,
            fit: BoxFit.fitWidth,
            alignment: Alignment.topCenter,
          ),

          // Main Content
          Expanded(
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  const Spacer(flex: 1),
                  
                  // Illustration
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Image.asset(
                      'assets/notif.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  
                  const Spacer(flex: 1),
                  
                  // Text Content
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 30),
                    child: Column(
                      children: [
                        const Text(
                          "Allow Notifications",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: primaryDark,
                            fontFamily: 'Inter',
                          ),
                        ),
                        
                        const SizedBox(height: 12), // Reduced from 16
                        
                        const Text(
                          "To receive timely alerts, you need to enable notifications",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: primaryDark,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const Spacer(flex: 2),
                  
                  // Buttons
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10), // Reduced vertical from 20 to 10
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () {
                            Navigator.pushReplacementNamed(context, '/intro');
                          },
                          child: const Text(
                            "Skip",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                        
                        ElevatedButton(
                          onPressed: () async {
                            PermissionStatus status = await Permission.notification.request();
                            
                            if (context.mounted) {
                              if (status.isGranted) {
                                Navigator.pushReplacementNamed(context, '/intro');
                              } else if (status.isPermanentlyDenied) {
                                openAppSettings();
                              } else {
                                // Optionally show a message
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Notification permission is recommended for alerts'),
                                  ),
                                );
                                // Still navigate to main menu if just denied (optional choice)
                                // For now, let's keep it consistent with location: require it or skip
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryDark,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            "Allow",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


