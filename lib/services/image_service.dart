/// ============================================================================
/// FILE: image_service.dart
/// ============================================================================
/// PURPOSE: Handles image upload and storage using Supabase Storage.
///          Used for storing field photos, maps, and other user uploads.
/// 
/// SUPABASE STORAGE:
///   - Images stored in 'map_images' bucket
///   - Organized by user_id subdirectories
///   - Returns public URLs for display
/// ============================================================================

import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for uploading and managing images in Supabase Storage
class ImageService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Upload image to Supabase Storage and return public URL
  /// 
  /// PARAMETERS:
  ///   file: The image file to upload
  ///   userId: User's ID (used as subdirectory)
  /// 
  /// RETURNS: Public URL of uploaded image, or null on error
  Future<String?> uploadImage(File file, String userId) async {
    try {
      // Generate unique filename using timestamp
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = '$userId/$fileName';

      // Upload to 'map_images' bucket
      await _supabase.storage.from('map_images').upload(
            path,
            file,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );

      // Get the public URL for displaying
      final publicUrl = _supabase.storage.from('map_images').getPublicUrl(path);
      return publicUrl;
    } catch (e) {
      // ignore: avoid_print
      print('Error uploading image: $e');
      return null;
    }
  }

  /// Save image metadata to database
  /// 
  /// PARAMETERS:
  ///   userId: User's ID
  ///   imageUrl: Public URL of the uploaded image
  /// 
  /// RETURNS: true on success, false on error
  Future<bool> saveImageRecord(String userId, String imageUrl) async {
    try {
      await _supabase.from('user_uploads').insert({
        'user_id': userId,
        'image_url': imageUrl,
      });
      return true;
    } catch (e) {
      // ignore: avoid_print
      print('Error saving image record: $e');
      return false;
    }
  }

  /// Fetch user's uploaded images
  /// 
  /// RETURNS: List of image records with URLs and metadata
  Future<List<Map<String, dynamic>>> getUserImages(String userId) async {
    try {
      final response = await _supabase
          .from('user_uploads')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      // ignore: avoid_print
      print('Error fetching images: $e');
      return [];
    }
  }
}
