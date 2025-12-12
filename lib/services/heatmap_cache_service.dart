/// ============================================================================
/// FILE: heatmap_cache_service.dart
/// ============================================================================
/// PURPOSE: Caches heatmap results (images + analysis) using SharedPreferences.
///          Unlike time series data which uses files, heatmaps use SharedPrefs
///          because we only store the most recent result per field+metric.
/// 
/// WHAT IS CACHED:
///   - Base64-encoded heatmap image
///   - Statistical values (min, max, mean)
///   - AI analysis text (for LLM-analyzed metrics)
///   - Recommendations list
///   - Timestamp for cache age
/// 
/// CACHE KEY FORMAT:
///   "heatmap_cache_19_0760_72_8777_soil_moisture"
///   └────prefix────┴──lat───┴──lon──┴──metric───┘
/// 
/// DEPENDENCIES:
///   - dart:convert: JSON serialization
///   - shared_preferences: Key-value storage
/// ============================================================================

// JSON encoding/decoding for cache serialization
import 'dart:convert';

// Local key-value storage
import 'package:shared_preferences/shared_preferences.dart';

/// ============================================================================
/// HeatmapCacheService CLASS
/// ============================================================================
/// Manages caching of heatmap images and analysis results.
/// Uses SharedPreferences for quick access to cached data.
class HeatmapCacheService {
  /// Prefix for cache keys (to identify heatmap cache entries)
  static const String _cacheKeyPrefix = 'heatmap_cache_';
  
  /// Prefix for timestamp entries (separate for easy expiry checking)
  static const String _timestampPrefix = 'heatmap_ts_';

  /// -------------------------------------------------------------------------
  /// _getCacheKey() - Generate unique key for field+metric
  /// -------------------------------------------------------------------------
  /// Converts coordinates to safe key format by replacing . with _
  /// Example: (19.0760, 72.8777, "soil_moisture") 
  ///          → "heatmap_cache_19_0760_72_8777_soil_moisture"
  static String _getCacheKey(double lat, double lon, String metric) {
    final latKey = lat.toStringAsFixed(4).replaceAll('.', '_');
    final lonKey = lon.toStringAsFixed(4).replaceAll('.', '_');
    return '$_cacheKeyPrefix${latKey}_${lonKey}_$metric';
  }

  // ===========================================================================
  // SAVE OPERATIONS
  // ===========================================================================
  
  /// -------------------------------------------------------------------------
  /// saveToCache() - Store heatmap result
  /// -------------------------------------------------------------------------
  /// Saves all heatmap data including the base64 image.
  /// 
  /// PARAMETERS:
  ///   lat, lon: Field coordinates
  ///   metric: Which metric (e.g., "soil_moisture", "pest_risk")
  ///   meanValue, minValue, maxValue: Statistical values
  ///   imageBase64: The heatmap image encoded as base64 string
  ///   analysis: Short AI analysis (optional, for LLM metrics)
  ///   detailedAnalysis: Extended AI reasoning (optional)
  ///   level: Risk level like "high", "moderate", "low" (optional)
  ///   recommendations: List of action items (optional)
  static Future<void> saveToCache({
    required double lat,
    required double lon,
    required String metric,
    required double meanValue,
    required double minValue,
    required double maxValue,
    required String imageBase64,
    String? analysis,
    String? detailedAnalysis,
    String? level,
    List<String>? recommendations,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getCacheKey(lat, lon, metric);
    
    // Build the cache data object
    final data = {
      'lat': lat,
      'lon': lon,
      'metric': metric,
      'mean_value': meanValue,
      'min_value': minValue,
      'max_value': maxValue,
      'image_base64': imageBase64,
      'analysis': analysis,
      'detailed_analysis': detailedAnalysis,
      'level': level,
      'recommendations': recommendations,
      'cached_at': DateTime.now().toIso8601String(),
    };
    
    // Save data and timestamp separately
    await prefs.setString(key, jsonEncode(data));
    await prefs.setString('$_timestampPrefix$key', DateTime.now().toIso8601String());
    print('[HeatmapCache] Saved $metric for ($lat, $lon)');
  }

  // ===========================================================================
  // READ OPERATIONS
  // ===========================================================================
  
  /// -------------------------------------------------------------------------
  /// getFromCache() - Retrieve cached heatmap result
  /// -------------------------------------------------------------------------
  /// Returns null if no cache exists or if cache is corrupted.
  static Future<CachedHeatmapResult?> getFromCache({
    required double lat,
    required double lon,
    required String metric,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getCacheKey(lat, lon, metric);
      final jsonStr = prefs.getString(key);
      
      if (jsonStr == null) {
        print('[HeatmapCache] No cache for $metric at ($lat, $lon)');
        return null;
      }
      
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      print('[HeatmapCache] Found cache for $metric at ($lat, $lon)');
      return CachedHeatmapResult.fromJson(data);
    } catch (e) {
      print('[HeatmapCache] Error reading cache: $e');
      return null;
    }
  }

  /// Check if cache exists for a field+metric.
  static Future<bool> hasCache({
    required double lat,
    required double lon,
    required String metric,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getCacheKey(lat, lon, metric);
    return prefs.containsKey(key);
  }

  // ===========================================================================
  // DELETE OPERATIONS
  // ===========================================================================
  
  /// Clear cache for a specific field+metric.
  static Future<void> clearCache({
    required double lat,
    required double lon,
    required String metric,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getCacheKey(lat, lon, metric);
    await prefs.remove(key);
    await prefs.remove('$_timestampPrefix$key');
    print('[HeatmapCache] Cleared $metric for ($lat, $lon)');
  }

  /// Clear all heatmap caches for a specific field (all metrics).
  static Future<void> clearFieldCache({
    required double lat,
    required double lon,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final latKey = lat.toStringAsFixed(4).replaceAll('.', '_');
    final lonKey = lon.toStringAsFixed(4).replaceAll('.', '_');
    final prefix = '$_cacheKeyPrefix${latKey}_${lonKey}_';
    
    // Find and remove all keys matching this field
    final allKeys = prefs.getKeys();
    for (final key in allKeys) {
      if (key.startsWith(prefix)) {
        await prefs.remove(key);
      }
    }
    print('[HeatmapCache] Cleared all caches for ($lat, $lon)');
  }

  /// Clear ALL heatmap caches (all fields, all metrics).
  /// Use with caution!
  static Future<void> clearAllCaches() async {
    final prefs = await SharedPreferences.getInstance();
    final allKeys = prefs.getKeys();
    for (final key in allKeys) {
      if (key.startsWith(_cacheKeyPrefix) || key.startsWith(_timestampPrefix)) {
        await prefs.remove(key);
      }
    }
    print('[HeatmapCache] Cleared all caches');
  }
}

// =============================================================================
// DATA MODELS
// =============================================================================

/// ============================================================================
/// CachedHeatmapResult - Wrapper for cached heatmap data
/// ============================================================================
/// Contains all cached heatmap data including the image and analysis.
class CachedHeatmapResult {
  /// Original coordinates
  final double lat;
  final double lon;
  
  /// Which metric this heatmap represents
  final String metric;
  
  /// Statistical values
  final double meanValue;
  final double minValue;
  final double maxValue;
  
  /// The heatmap image as base64-encoded PNG
  final String imageBase64;
  
  /// AI-generated analysis (for LLM metrics)
  final String? analysis;
  final String? detailedAnalysis;
  
  /// Risk level: "high", "moderate", "low"
  final String? level;
  
  /// AI-generated recommendations
  final List<String>? recommendations;
  
  /// When this was cached
  final DateTime cachedAt;

  CachedHeatmapResult({
    required this.lat,
    required this.lon,
    required this.metric,
    required this.meanValue,
    required this.minValue,
    required this.maxValue,
    required this.imageBase64,
    this.analysis,
    this.detailedAnalysis,
    this.level,
    this.recommendations,
    required this.cachedAt,
  });

  /// Parse from JSON
  factory CachedHeatmapResult.fromJson(Map<String, dynamic> json) {
    return CachedHeatmapResult(
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
      metric: json['metric'] as String,
      meanValue: (json['mean_value'] as num).toDouble(),
      minValue: (json['min_value'] as num).toDouble(),
      maxValue: (json['max_value'] as num).toDouble(),
      imageBase64: json['image_base64'] as String,
      analysis: json['analysis'] as String?,
      detailedAnalysis: json['detailed_analysis'] as String?,
      level: json['level'] as String?,
      recommendations: (json['recommendations'] as List<dynamic>?)?.cast<String>(),
      cachedAt: DateTime.parse(json['cached_at'] as String),
    );
  }

  /// Get human-readable cache age
  String get ageString {
    final diff = DateTime.now().difference(cachedAt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
