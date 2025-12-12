/// ===========================================================================
/// LOCATION PERMISSION SCREEN
/// ===========================================================================
///
/// PURPOSE: Request device location permission for localized content.
///          Part of onboarding flow after intro screen.
///
/// PERMISSION FLOW:
///   1. Display explanation of why location is needed
///   2. "Allow" → Request permission via permission_handler
///   3. If granted → /notification-permission
///   4. If permanently denied → Open app settings
///   5. "Skip" → Continue without permission
///
/// UI DESIGN:
///   - Illustration showing location concept
///   - Clear explanation text
///   - Allow/Skip buttons at bottom
///
/// DEPENDENCIES:
///   - permission_handler: Runtime permission requests
/// ===========================================================================

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationPermissionScreen extends StatelessWidget {
  const LocationPermissionScreen({super.key});

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
                  const Spacer(flex: 1), // Reduced top spacer
                  
                  // Illustration
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10), // Reduced padding for larger image
                    child: Image.asset(
                      'assets/LocationPerm2.png',
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
                          "Access to device location",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: primaryDark,
                            fontFamily: 'Inter',
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        const Text(
                          "To provide you with localized content, Agrow needs access to your device's location",
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
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () {
                            Navigator.pushReplacementNamed(context, '/notification-permission');
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
                            PermissionStatus status = await Permission.location.request();
                            
                            if (context.mounted) {
                              if (status.isGranted) {
                                Navigator.pushReplacementNamed(context, '/notification-permission');
                              } else if (status.isPermanentlyDenied) {
                                openAppSettings();
                              } else {
                                // Optionally show a message explaining why permission is needed
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Location permission is needed for local content'),
                                  ),
                                );
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


