/// ============================================================================
/// FILE: cache_service.dart
/// ============================================================================
/// PURPOSE: Caches satellite analysis data locally on the device to:
///   1. Instantly show previous results while new data loads
///   2. Reduce API calls and save bandwidth/battery
///   3. Work offline with previously fetched data
/// 
/// WHAT THIS FILE DOES:
///   - Saves SAR and Sentinel-2 analysis results to SharedPreferences
///   - Tracks which satellite image date the cached data is based on
///   - Checks if cache is stale (newer satellite image is available)
///   - Provides methods to clear cache (per field or all)
/// 
/// CACHE INVALIDATION (When to refresh):
///   - New satellite image is available from Copernicus
///   - User manually requests a refresh
///   - Cache age exceeds a threshold (if implemented)
/// 
/// DATA STORED:
///   For each field ID, we store:
///   - SAR analysis results (soil moisture, salinity, etc.)
///   - Sentinel-2 analysis results (vegetation indices)
///   - Image date (which satellite image was analyzed)
///   - Cache timestamp (when we saved this data)
/// 
/// DEPENDENCIES:
///   - shared_preferences: Local key-value storage on device
///   - dart:convert: JSON encoding/decoding
/// ============================================================================

// For JSON encoding/decoding
import 'dart:convert';

// SharedPreferences - stores data locally on the device
// Data persists across app restarts
import 'package:shared_preferences/shared_preferences.dart';

/// ============================================================================
/// CacheService CLASS
/// ============================================================================
/// A static utility class (no instance needed) for managing local data cache.
/// 
/// WHY CACHE?
///   Satellite analysis takes 30-60 seconds. Without caching:
///   - User waits every time they open the app
///   - Battery and data are wasted on repeated API calls
///   
///   With caching:
///   - Instant display of previous results
///   - New analysis runs in background
///   - UI updates when new data is ready
class CacheService {
  // ---------------------------------------------------------------------------
  // Cache Key Prefixes
  // ---------------------------------------------------------------------------
  // We store multiple pieces of data per field, so we use prefixes to organize.
  // Example: For field "abc123", we store:
  //   - "field_cache_abc123" -> The actual analysis data (JSON)
  //   - "last_image_date_abc123" -> Which satellite image date
  //   - "cache_timestamp_abc123" -> When we cached this
  
  /// Prefix for main cache data (contains SAR + Sentinel-2 results)
  static const String _cacheKeyPrefix = 'field_cache_';
  
  /// Prefix for storing which satellite image date the cache is based on
  static const String _lastImageDateKey = 'last_image_date_';
  
  /// Prefix for storing when the cache was created
  static const String _cacheTimestampKey = 'cache_timestamp_';

  // ===========================================================================
  // SAVE METHODS
  // ===========================================================================
  
  /// -------------------------------------------------------------------------
  /// saveCache() - Save analysis results to local storage
  /// -------------------------------------------------------------------------
  /// Stores the analysis data for a specific field.
  /// 
  /// PARAMETERS:
  ///   fieldId: Unique identifier for the farm field
  ///   sarData: Results from SAR (radar) analysis - soil health
  ///   sentinel2Data: Results from Sentinel-2 analysis - crop health (optional)
  ///   imageDate: The date of the satellite image that was analyzed
  /// 
  /// WHAT IT SAVES:
  ///   {
  ///     "sar_data": {...},           // Soil moisture, salinity, etc.
  ///     "sentinel2_data": {...},      // NDVI, crop stress, etc.
  ///     "image_date": "2024-12-07",   // Which satellite pass
  ///     "cached_at": "2024-12-07T10:30:00Z" // When we saved this
  ///   }
  static Future<void> saveCache({
    required String fieldId,
    required Map<String, dynamic> sarData,
    required Map<String, dynamic>? sentinel2Data,
    required String imageDate,
  }) async {
    // Get SharedPreferences instance (local storage)
    final prefs = await SharedPreferences.getInstance();
    
    // Build the cache object with all data
    final cacheData = {
      'sar_data': sarData,
      'sentinel2_data': sentinel2Data,
      'image_date': imageDate,
      'cached_at': DateTime.now().toIso8601String(),
    };
    
    // Save the main cache data as JSON string
    await prefs.setString(_cacheKeyPrefix + fieldId, jsonEncode(cacheData));
    
    // Save image date separately (for quick comparison without loading full cache)
    await prefs.setString(_lastImageDateKey + fieldId, imageDate);
    
    // Save timestamp separately (to check cache age)
    await prefs.setString(_cacheTimestampKey + fieldId, DateTime.now().toIso8601String());
  }

  // ===========================================================================
  // LOAD METHODS
  // ===========================================================================
  
  /// -------------------------------------------------------------------------
  /// getCache() - Load cached data for a field
  /// -------------------------------------------------------------------------
  /// Retrieves previously saved analysis data.
  /// 
  /// PARAMETERS:
  ///   fieldId: The field to get cache for
  /// 
  /// RETURNS:
  ///   The cached data as a Map, or null if:
  ///   - No cache exists for this field
  ///   - Cache is corrupted/invalid JSON
  /// 
  /// EXAMPLE:
  ///   final cache = await CacheService.getCache('field123');
  ///   if (cache != null) {
  ///     final sarData = cache['sar_data'];
  ///     displayInstantly(sarData); // Show while loading fresh data
  ///   }
  static Future<Map<String, dynamic>?> getCache(String fieldId) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheJson = prefs.getString(_cacheKeyPrefix + fieldId);
    
    // No cache found
    if (cacheJson == null) return null;
    
    try {
      // Parse and return the cached data
      return jsonDecode(cacheJson) as Map<String, dynamic>;
    } catch (e) {
      // JSON was corrupted, return null (cache miss)
      return null;
    }
  }

  /// -------------------------------------------------------------------------
  /// getCachedImageDate() - Get the satellite image date for cached data
  /// -------------------------------------------------------------------------
  /// Returns the date string of the satellite image that was used
  /// to generate the cached analysis.
  /// 
  /// USED FOR:
  ///   - Displaying "Data from: 07-12-2024" in UI
  ///   - Comparing with latest available image to check staleness
  static Future<String?> getCachedImageDate(String fieldId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastImageDateKey + fieldId);
  }

  /// -------------------------------------------------------------------------
  /// getCacheTimestamp() - Get when the cache was last updated
  /// -------------------------------------------------------------------------
  /// Returns the DateTime when we last saved cache for this field.
  /// 
  /// USED FOR:
  ///   - Displaying "Last updated: 2 hours ago" in UI
  ///   - Implementing time-based cache expiration
  static Future<DateTime?> getCacheTimestamp(String fieldId) async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getString(_cacheTimestampKey + fieldId);
    if (timestamp == null) return null;
    return DateTime.tryParse(timestamp);
  }

  // ===========================================================================
  // CACHE VALIDATION METHODS
  // ===========================================================================
  
  /// -------------------------------------------------------------------------
  /// needsRefresh() - Check if cache is stale
  /// -------------------------------------------------------------------------
  /// Compares the cached image date with the latest available image date
  /// from the satellite API.
  /// 
  /// PARAMETERS:
  ///   fieldId: The field to check
  ///   latestImageDate: The newest available satellite image date (from API)
  /// 
  /// RETURNS:
  ///   true if:
  ///     - No cache exists (first time)
  ///     - A newer satellite image is available
  ///   false if:
  ///     - Cache is based on the latest available image
  /// 
  /// EXAMPLE:
  ///   final needsNew = await CacheService.needsRefresh(
  ///     fieldId: 'abc123',
  ///     latestImageDate: '2024-12-10', // From /latest-image-date API
  ///   );
  ///   if (needsNew) {
  ///     // Fetch fresh analysis
  ///   } else {
  ///     // Use cached data, it's still current
  ///   }
  static Future<bool> needsRefresh({
    required String fieldId,
    required String latestImageDate,
  }) async {
    final cachedDate = await getCachedImageDate(fieldId);
    
    // No cache exists - definitely needs refresh
    if (cachedDate == null) return true;
    
    // Compare dates alphabetically (works for YYYY-MM-DD format)
    // If latest > cached, we have a newer image available
    return latestImageDate.compareTo(cachedDate) > 0;
  }

  // ===========================================================================
  // CACHE CLEARING METHODS
  // ===========================================================================
  
  /// -------------------------------------------------------------------------
  /// clearCache() - Remove cache for a specific field
  /// -------------------------------------------------------------------------
  /// Call this when user manually refreshes or field is deleted.
  static Future<void> clearCache(String fieldId) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Remove all three cache keys for this field
    await prefs.remove(_cacheKeyPrefix + fieldId);
    await prefs.remove(_lastImageDateKey + fieldId);
    await prefs.remove(_cacheTimestampKey + fieldId);
  }

  /// -------------------------------------------------------------------------
  /// clearAllCaches() - Remove ALL field caches
  /// -------------------------------------------------------------------------
  /// Call this during logout or when user clears app data.
  /// 
  /// NOTE: This only clears field caches, not other app preferences.
  static Future<void> clearAllCaches() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    
    // Find and remove all keys related to field caches
    for (final key in keys) {
      if (key.startsWith(_cacheKeyPrefix) ||
          key.startsWith(_lastImageDateKey) ||
          key.startsWith(_cacheTimestampKey)) {
        await prefs.remove(key);
      }
    }
  }

  // ===========================================================================
  // UTILITY METHODS
  // ===========================================================================
  
  /// -------------------------------------------------------------------------
  /// formatDateForDisplay() - Format a date nicely for UI
  /// -------------------------------------------------------------------------
  /// Converts DateTime to "DD-MM-YYYY" format for user display.
  /// 
  /// EXAMPLE:
  ///   formatDateForDisplay(DateTime(2024, 12, 7))
  ///   // Returns: "07-12-2024"
  static String formatDateForDisplay(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}-'
           '${date.month.toString().padLeft(2, '0')}-'
           '${date.year}';
  }
}
