import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Cache service for heatmap results (per field+metric)
/// Stores: mean_value, analysis, level, recommendations, image_base64
class HeatmapCacheService {
  static const String _cacheKeyPrefix = 'heatmap_cache_';
  static const String _timestampPrefix = 'heatmap_ts_';

  /// Generate cache key for field+metric
  static String _getCacheKey(double lat, double lon, String metric) {
    final latKey = lat.toStringAsFixed(4).replaceAll('.', '_');
    final lonKey = lon.toStringAsFixed(4).replaceAll('.', '_');
    return '$_cacheKeyPrefix${latKey}_${lonKey}_$metric';
  }

  /// Save heatmap result to cache
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
    
    await prefs.setString(key, jsonEncode(data));
    await prefs.setString('$_timestampPrefix$key', DateTime.now().toIso8601String());
    print('[HeatmapCache] Saved $metric for ($lat, $lon)');
  }

  /// Get cached heatmap result
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

  /// Check if cache exists
  static Future<bool> hasCache({
    required double lat,
    required double lon,
    required String metric,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getCacheKey(lat, lon, metric);
    return prefs.containsKey(key);
  }

  /// Clear cache for specific field+metric
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

  /// Clear all heatmap caches for a field (all metrics)
  static Future<void> clearFieldCache({
    required double lat,
    required double lon,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final latKey = lat.toStringAsFixed(4).replaceAll('.', '_');
    final lonKey = lon.toStringAsFixed(4).replaceAll('.', '_');
    final prefix = '$_cacheKeyPrefix${latKey}_${lonKey}_';
    
    final allKeys = prefs.getKeys();
    for (final key in allKeys) {
      if (key.startsWith(prefix)) {
        await prefs.remove(key);
      }
    }
    print('[HeatmapCache] Cleared all caches for ($lat, $lon)');
  }

  /// Clear all heatmap caches
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

/// Cached heatmap result wrapper
class CachedHeatmapResult {
  final double lat;
  final double lon;
  final String metric;
  final double meanValue;
  final double minValue;
  final double maxValue;
  final String imageBase64;
  final String? analysis;
  final String? detailedAnalysis;
  final String? level;
  final List<String>? recommendations;
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

  /// Get age as human-readable string
  String get ageString {
    final diff = DateTime.now().difference(cachedAt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
