/// ===========================================================================
/// LANDING SCREEN
/// ===========================================================================
///
/// PURPOSE: Initial entry point after splash, offering Login/Signup/Guest.
///          Main authentication gateway for the application.
///
/// NAVIGATION OPTIONS:
///   - Login → /login (existing users)
///   - Sign-up → /registration (new users)
///   - Continue as Guest → /location-permission (skip auth)
///
/// UI DESIGN:
///   - Large AGROW logo centered
///   - Dark curved background with BottomCurveClipper
///   - Rounded authentication buttons
///
/// CUSTOM WIDGETS:
///   - BottomCurveClipper: Custom path clipper for curved header
/// ===========================================================================

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const Color primaryDark = Color(0xFF0F3C33);
    const Color backgroundLight = Color(0xFFE1EFEF);

    return Scaffold(
      backgroundColor: backgroundLight,
      body: Stack(
        children: [
          // Top Section with Curve
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.65,
            child: ClipPath(
              clipper: BottomCurveClipper(),
              child: Container(
                color: primaryDark,
                // Empty container for background only
              ),
            ),
          ),

          // Logo (Foreground)
          Positioned(
            top: MediaQuery.of(context).size.height * 0.01, // 1/4th distance from top
            left: 0,
            right: 0,
            child: Center(
              child: Image.asset(
                'assets/AGROW LOGO.png',
                height: 500, // Adjusted height to fit well with new position
              ),
            ),
          ),

          // Bottom Section (Buttons)
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 376,
                height: 240, // Increased height for guest button
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: primaryDark,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildButton(
                      context,
                      label: "Login",
                      onTap: () {
                        Navigator.pushNamed(context, '/login');
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildButton(
                      context,
                      label: "Sign-up",
                      onTap: () {
                        Navigator.pushNamed(context, '/registration');
                      },
                    ),
                    const SizedBox(height: 16),
                      GestureDetector(
                        onTap: () {
                          Navigator.pushNamed(context, '/location-permission');
                        },
                      child: const Text(
                        "Continue as Guest",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButton(BuildContext context, {required String label, required VoidCallback onTap}) {
    return SizedBox(
      width: 346,
      height: 62,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFF1F8F8), // #F1F8F8
          foregroundColor: const Color(0xFF0F3C33),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class BottomCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    path.lineTo(0, size.height - 100); // Deeper curve start
    
    // Quadratic bezier curve for the bottom arc
    var firstControlPoint = Offset(size.width / 2, size.height + 50); // Deeper control point
    var firstEndPoint = Offset(size.width, size.height - 100);

    path.quadraticBezierTo(
      firstControlPoint.dx,
      firstControlPoint.dy,
      firstEndPoint.dx,
      firstEndPoint.dy,
    );

    path.lineTo(size.width, 0);
    path.lineTo(0, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
