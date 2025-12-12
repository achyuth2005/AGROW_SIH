/// ===========================================================================
/// COMING SOON SCREEN
/// ===========================================================================
///
/// PURPOSE: Placeholder screen for features under development.
///          Auto-dismisses after 2 seconds.
///
/// DESIGN:
///   - Dark green background with curved header
///   - Team attribution message
///   - Auto-pop navigation after delay
///
/// USED FOR:
///   - Coordinates History, App Tutorial, Notifications
///   - Privacy & Security, About pages
///   - Any WIP features
/// ===========================================================================

import 'package:flutter/material.dart';

class ComingSoonScreen extends StatefulWidget {
  const ComingSoonScreen({super.key});

  @override
  State<ComingSoonScreen> createState() => _ComingSoonScreenState();
}

class _ComingSoonScreenState extends State<ComingSoonScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF233328),
      body: Stack(
        children: [
          ClipPath(
            clipper: TopCurveClipper(),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.33,
              color: const Color(0xFF4CA67A),
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Team "What The Hack"\nwill soon come up with this feature.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF7FFFB1),
                        fontWeight: FontWeight.w900,
                        fontSize: 28,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      "Wait till then! Happy Farming.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF4CA67A),
                        fontWeight: FontWeight.w700,
                        fontSize: 21,
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
}

// Use this same clipper for brand consistency
class TopCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, size.height * 0.23);
    path.quadraticBezierTo(
      size.width / 2, size.height * 0.4,
      size.width, size.height * 0.15,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }
  @override
  bool shouldReclip(oldClipper) => false;
}
