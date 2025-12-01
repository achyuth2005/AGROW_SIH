import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class ImageService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Upload image to Supabase Storage and return public URL
  Future<String?> uploadImage(File file, String userId) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = '$userId/$fileName';

      await _supabase.storage.from('map_images').upload(
            path,
            file,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );

      final publicUrl = _supabase.storage.from('map_images').getPublicUrl(path);
      return publicUrl;
    } catch (e) {
      // ignore: avoid_print
      print('Error uploading image: $e');
      return null;
    }
  }

  // Save image metadata to Supabase Database
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

  // Fetch user's uploaded images
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
