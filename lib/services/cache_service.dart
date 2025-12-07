import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for caching homepage satellite analysis data.
/// 
/// Cache is invalidated when:
/// 1. New satellite image is available (checked via /latest-image-date)
/// 2. Manual refresh requested by user
class CacheService {
  static const String _cacheKeyPrefix = 'field_cache_';
  static const String _lastImageDateKey = 'last_image_date_';
  static const String _cacheTimestampKey = 'cache_timestamp_';

  /// Save analysis data to cache
  static Future<void> saveCache({
    required String fieldId,
    required Map<String, dynamic> sarData,
    required Map<String, dynamic>? sentinel2Data,
    required String imageDate,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    final cacheData = {
      'sar_data': sarData,
      'sentinel2_data': sentinel2Data,
      'image_date': imageDate,
      'cached_at': DateTime.now().toIso8601String(),
    };
    
    await prefs.setString(_cacheKeyPrefix + fieldId, jsonEncode(cacheData));
    await prefs.setString(_lastImageDateKey + fieldId, imageDate);
    await prefs.setString(_cacheTimestampKey + fieldId, DateTime.now().toIso8601String());
  }

  /// Load cached data for a field
  static Future<Map<String, dynamic>?> getCache(String fieldId) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheJson = prefs.getString(_cacheKeyPrefix + fieldId);
    
    if (cacheJson == null) return null;
    
    try {
      return jsonDecode(cacheJson) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  /// Get the image date for cached data
  static Future<String?> getCachedImageDate(String fieldId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastImageDateKey + fieldId);
  }

  /// Get when the cache was last updated
  static Future<DateTime?> getCacheTimestamp(String fieldId) async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getString(_cacheTimestampKey + fieldId);
    if (timestamp == null) return null;
    return DateTime.tryParse(timestamp);
  }

  /// Check if cache needs refresh based on new image availability
  static Future<bool> needsRefresh({
    required String fieldId,
    required String latestImageDate,
  }) async {
    final cachedDate = await getCachedImageDate(fieldId);
    if (cachedDate == null) return true; // No cache, needs refresh
    
    // Compare dates - if server has newer image, refresh
    return latestImageDate.compareTo(cachedDate) > 0;
  }

  /// Clear cache for a specific field
  static Future<void> clearCache(String fieldId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKeyPrefix + fieldId);
    await prefs.remove(_lastImageDateKey + fieldId);
    await prefs.remove(_cacheTimestampKey + fieldId);
  }

  /// Clear all field caches
  static Future<void> clearAllCaches() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    
    for (final key in keys) {
      if (key.startsWith(_cacheKeyPrefix) ||
          key.startsWith(_lastImageDateKey) ||
          key.startsWith(_cacheTimestampKey)) {
        await prefs.remove(key);
      }
    }
  }

  /// Format cache date for display (e.g., "07-12-2024")
  static String formatDateForDisplay(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
  }
}
