/// ===========================================================================
/// CAMERA SCREEN
/// ===========================================================================
///
/// PURPOSE: Capture or upload field images for documentation.
///          Images are stored in Supabase Storage.
///
/// KEY FEATURES:
///   - Camera capture via ImagePicker
///   - Gallery upload option
///   - Retake/Confirm workflow
///   - Upload to Supabase Storage with user_id path
///
/// IMAGE FLOW:
///   1. User captures photo or picks from gallery
///   2. Preview with Retake/Confirm options
///   3. Upload to Supabase Storage bucket
///   4. Save record to field_images table
///
/// DEPENDENCIES:
///   - image_picker: Camera/gallery access
///   - ImageService: Supabase upload helper
///   - firebase_auth: User identification
/// ===========================================================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/image_service.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  XFile? _capturedImage;
  bool _isUploading = false;
  final ImageService _imageService = ImageService();
  final ImagePicker _picker = ImagePicker();

  Future<void> _takePhoto() async {
    try {
      final image = await _picker.pickImage(source: ImageSource.camera);
      if (image != null) {
        setState(() {
          _capturedImage = image;
        });
      }
    } catch (e) {
      debugPrint('Error taking photo: $e');
    }
  }

  Future<void> _pickImage() async {
    try {
      final image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _capturedImage = image;
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  void _retake() {
    setState(() {
      _capturedImage = null;
    });
  }

  Future<void> _uploadImage() async {
    if (_capturedImage == null) return;

    setState(() {
      _isUploading = true;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login to upload images')),
        );
        setState(() => _isUploading = false);
      }
      return;
    }

    final file = File(_capturedImage!.path);
    final url = await _imageService.uploadImage(file, user.uid);

    if (url != null) {
      final success = await _imageService.saveImageRecord(user.uid, url);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image uploaded successfully!')),
        );
        _retake(); // Clear image after upload
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save image record')),
        );
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to upload image')),
      );
    }

    if (mounted) {
      setState(() {
        _isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F5F3), // Light mint background
      body: Column(
        children: [
          // Header Section
          Stack(
            children: [
              Image.asset(
                'assets/backsmall.png',
                width: double.infinity,
                fit: BoxFit.fitWidth,
                alignment: Alignment.topCenter,
              ),
              Positioned(
                top: 50,
                left: 20,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                  ),
                ),
              ),
              const Positioned(
                top: 50,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    "Camera",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Main Content Area
          Expanded(
            child: FractionallySizedBox(
              widthFactor: 0.85,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: const Color(0xFF167339), width: 8),
                  color: Colors.black,
                ),
                clipBehavior: Clip.hardEdge,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Image Display or Placeholder
                    if (_capturedImage != null)
                      Image.file(
                        File(_capturedImage!.path),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      )
                    else
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.camera_alt_outlined, size: 80, color: Colors.white54),
                          const SizedBox(height: 16),
                          const Text(
                            "Tap below to take a photo",
                            style: TextStyle(color: Colors.white54, fontSize: 16),
                          ),
                        ],
                      ),

                    // Capture Button (Only if no image captured)
                    if (_capturedImage == null)
                      Positioned(
                        bottom: 30,
                        child: GestureDetector(
                          onTap: _takePhoto,
                          child: Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              color: const Color(0xFF167339),
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFFAEF051), width: 3),
                            ),
                            child: const Icon(Icons.camera_alt, color: Colors.white, size: 30),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Action Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: _capturedImage == null
                ? SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _pickImage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF167339),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text(
                        "Upload from Gallery",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFAEF051),
                        ),
                      ),
                    ),
                  )
                : Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 55,
                          child: ElevatedButton(
                            onPressed: _isUploading ? null : _retake,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                                side: const BorderSide(color: Color(0xFF167339), width: 2),
                              ),
                            ),
                            child: const Text(
                              "Retake",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF167339),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: SizedBox(
                          height: 55,
                          child: ElevatedButton(
                            onPressed: _isUploading ? null : _uploadImage,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF167339),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: _isUploading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Color(0xFFAEF051),
                                      strokeWidth: 3,
                                    ),
                                  )
                                : const Text(
                                    "Confirm",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFAEF051),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
          
          // Bottom Navigation Placeholder
          Container(
            height: 80,
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(40),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNavItem(Icons.home_outlined),
                _buildNavItem(Icons.grid_view),
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFF167339),
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                _buildNavItem(Icons.chat_bubble_outline),
                _buildNavItem(Icons.person_outline),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon) {
    return Icon(icon, color: Colors.grey[400], size: 30);
  }
}
