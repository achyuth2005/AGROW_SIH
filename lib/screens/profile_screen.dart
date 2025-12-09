import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:agroww_sih/widgets/adaptive_bottom_nav_bar.dart';

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
      "hint": "Enter Full Name",
      "type": "text"
    },
    {
      "label": "Phone no.",
      "key": "phone_number",
      "hint": "Enter Phone Number",
      "type": "phone"
    },
    {
      "label": "Email Address",
      "key": "email",
      "hint": "Enter Email Address",
      "type": "email"
    },
    {
      "label": "DOB",
      "key": "date_of_birth",
      "hint": "Select Date",
      "type": "date"
    },
    {
      "label": "Address",
      "key": "address",
      "hint": "Enter Address",
      "type": "text"
    },
  ];

  final Map<String, TextEditingController> _controllers = {};
  bool _isLoading = false;
  String? _avatarUrl;
  File? _imageFile;

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
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final data = await Supabase.instance.client
            .from('user_profiles')
            .select()
            .eq('user_id', user.uid)
            .maybeSingle();

        if (data != null) {
          setState(() {
            _controllers['full_name']?.text = data['full_name'] ?? user.displayName ?? "";
            _controllers['email']?.text = data['email'] ?? user.email ?? "";
            _controllers['phone_number']?.text = data['phone_number'] ?? "";
            _controllers['address']?.text = data['address'] ?? "";
            _controllers['date_of_birth']?.text = data['date_of_birth'] ?? "";
            _avatarUrl = data['avatar_url'];
          });
        } else {
          // Pre-fill from Firebase if no Supabase profile yet
          setState(() {
            _controllers['full_name']?.text = user.displayName ?? "";
            _controllers['email']?.text = user.email ?? "";
            _avatarUrl = user.photoURL;
          });
        }
      }
    } catch (e) {
      debugPrint("Error loading profile: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0F3C33),
              onPrimary: Colors.white,
              onSurface: Color(0xFF0F3C33),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _controllers['date_of_birth']?.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Photo Library'),
                onTap: () async {
                  Navigator.of(context).pop();
                  final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                  if (image != null) {
                    _uploadImage(File(image.path));
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Camera'),
                onTap: () async {
                  Navigator.of(context).pop();
                  final XFile? image = await picker.pickImage(source: ImageSource.camera);
                  if (image != null) {
                    _uploadImage(File(image.path));
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _uploadImage(File image) async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final fileExt = image.path.split('.').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final filePath = '${user.uid}/$fileName';

      await Supabase.instance.client.storage
          .from('profile_avatars')
          .upload(filePath, image);

      final imageUrl = Supabase.instance.client.storage
          .from('profile_avatars')
          .getPublicUrl(filePath);

      setState(() {
        _avatarUrl = imageUrl;
        _imageFile = image;
      });

      // Optionally save immediately or wait for "Save Changes"
      // Let's save immediately for better UX on image update
      await Supabase.instance.client.from('user_profiles').upsert({
        'user_id': user.uid,
        'avatar_url': imageUrl,
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Save to SharedPreferences for global usage
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_avatar_url', imageUrl);

    } catch (e) {
      debugPrint("Error uploading image: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading image: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    final email = _controllers['email']?.text.trim() ?? "";
    if (email.isNotEmpty && !_isValidEmail(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final updates = {
          'user_id': user.uid,
          'full_name': _controllers['full_name']?.text.trim(),
          'email': email,
          'phone_number': _controllers['phone_number']?.text.trim(),
          'date_of_birth': _controllers['date_of_birth']?.text.trim().isEmpty == true ? null : _controllers['date_of_birth']?.text.trim(),
          'address': _controllers['address']?.text.trim(),
          'updated_at': DateTime.now().toIso8601String(),
          // avatar_url is already saved if changed, but good to include if we want atomic updates
          if (_avatarUrl != null) 'avatar_url': _avatarUrl, 
        };

        await Supabase.instance.client.from('user_profiles').upsert(updates);

        // Update SharedPreferences for global usage
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_full_name', _controllers['full_name']?.text ?? "User");

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile Saved Successfully')),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      debugPrint("Error saving profile: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving profile: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
      bottomNavigationBar: const AdaptiveBottomNavBar(page: ActivePage.profile),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryDark))
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Header with Background Image and Profile Picture
                  SizedBox(
                    height: 250,
                    child: Stack(
                      children: [
                        // Background Image
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          height: 180,
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Color(0xFF167339),
                              image: DecorationImage(
                                image: AssetImage('assets/Background.png'),
                                fit: BoxFit.cover,
                                opacity: 0.4,
                              ),
                              borderRadius: BorderRadius.vertical(bottom: Radius.circular(25)),
                            ),
                          ),
                        ),
                        
                        // AppBar Content
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: SafeArea(
                            child: SizedBox(
                              height: 60, // Approximate height for header content
                              child: Stack(
                                children: [
                                  // Back Button Removed
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: const SizedBox(height: 24),
                                  ),
                                  
                                  // Title (Centered, Lower, Black)
                                  // Note: The original design had the title lower, likely below the white text area of the image?
                                  // The image 'backsmallsetting.png' likely has a curve.
                                  // Let's try to match the previous visual position: "top: 50" in original code.
                                  Align(
                                    alignment: Alignment.bottomCenter,
                                    child: Padding(
                                      padding: const EdgeInsets.only(bottom: 10),
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
                          ),
                        ),

                        // Profile Picture (Centered at bottom)
                        Positioned(
                          bottom: 0,
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
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 10,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: ClipOval(
                                    child: _imageFile != null
                                        ? Image.file(_imageFile!, fit: BoxFit.cover)
                                        : _avatarUrl != null && _avatarUrl!.isNotEmpty
                                            ? Image.network(
                                                _avatarUrl!,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) =>
                                                    const Icon(Icons.person, size: 80, color: Colors.white),
                                              )
                                            : const Icon(Icons.person, size: 80, color: Colors.white),
                                  ),
                                ),
                                Positioned(
                                  right: 5,
                                  bottom: 5,
                                  child: GestureDetector(
                                    onTap: _pickImage,
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF0F3C33),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 24),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Form Fields
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                    child: Column(
                      children: [
                        ..._formFields.map((field) {
                          final isDate = field['type'] == 'date';
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
                                GestureDetector(
                                  onTap: isDate ? () => _selectDate(context) : null,
                                  child: AbsorbPointer(
                                    absorbing: isDate,
                                    child: TextField(
                                      controller: _controllers[field['key']],
                                      keyboardType: field['type'] == 'email' 
                                          ? TextInputType.emailAddress 
                                          : field['type'] == 'phone' 
                                              ? TextInputType.phone 
                                              : TextInputType.text,
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
                                        suffixIcon: isDate 
                                            ? const Icon(Icons.calendar_today, size: 18, color: primaryDark) 
                                            : null,
                                      ),
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
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
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
