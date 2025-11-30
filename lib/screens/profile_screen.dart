import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:shared_preferences/shared_preferences.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // JSON configuration for the form fields
  final List<Map<String, dynamic>> _formFields = [
    {
      "label": "Full Name",
      "key": "full_name",
      "hint": "Achyuth Chetta", // Example from image
      "type": "text"
    },
    {
      "label": "Phone no.",
      "key": "phone",
      "hint": "",
      "type": "phone"
    },
    {
      "label": "Email Address",
      "key": "email",
      "hint": "",
      "type": "email"
    },
    {
      "label": "DOB",
      "key": "dob",
      "hint": "",
      "type": "date"
    },
    {
      "label": "Address",
      "key": "address",
      "hint": "",
      "type": "text"
    },
  ];

  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    // Initialize controllers
    for (var field in _formFields) {
      _controllers[field['key']] = TextEditingController();
    }
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _controllers['full_name']?.text = prefs.getString('user_full_name') ?? "Achyuth Chetta";
      // Load other fields if needed
    });
  }

  Future<void> _saveProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_full_name', _controllers['full_name']?.text ?? "User");
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile Saved')),
      );
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryDark = Color(0xFF0F3C33);
    const Color backgroundLight = Color(0xFFE1EFEF);

    return Scaffold(
      backgroundColor: backgroundLight,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header with Background Image and Profile Picture
            Stack(
              clipBehavior: Clip.none,
              children: [
                // Background Image
                Container(
                  height: 180,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/backsmallsetting.png'),
                      fit: BoxFit.fill,
                      alignment: Alignment.topCenter,
                    ),
                  ),
                ),
                
                // AppBar Content
                SafeArea(
                  child: Stack(
                    children: [
                      // Back Button (Top Left, White)
                      Align(
                        alignment: Alignment.topLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8, top: 8),
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                      ),
                      
                      // Title (Centered, Lower, Black)
                      Align(
                        alignment: Alignment.topCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 50),
                          child: Text(
                            "Profile",
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Profile Picture (Centered on boundary)
                Positioned(
                  bottom: -70, // Half of 140
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Stack(
                      children: [
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.grey[300],
                            border: Border.all(color: Colors.white, width: 4),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.person, size: 80, color: Colors.white),
                        ),
                        Positioned(
                          right: 5,
                          bottom: 5,
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: const BoxDecoration(
                              color: Color(0xFF0F3C33),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 24),
                          ),
                        ),
                      ],
                    ).animate().scale(curve: Curves.easeOutBack),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 80), // Space for the bottom half of profile pic + padding

            // Form Fields
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                children: [
                  ..._formFields.map((field) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            field['label'],
                            style: const TextStyle(
                              color: primaryDark,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          TextField(
                            controller: _controllers[field['key']],
                            decoration: InputDecoration(
                              hintText: field['hint'],
                              hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.6),
                              isDense: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            ),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ).animate().fadeIn().slideY(begin: 0.1, end: 0);
                  }),

                  const SizedBox(height: 20),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryDark,
                        foregroundColor: const Color(0xFFAEF051), // Lime green text
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "Save Changes",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2, end: 0),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
