import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'timeseries_service.dart';

/// Local cache service for time series data
/// Stores data as JSON files per field (keyed by lat/lon/metric)
class TimeSeriesCacheService {
  static const String _cacheDir = 'timeseries_cache';
  
  /// Generate unique cache key for a field+metric combination
  static String _getCacheKey(double lat, double lon, String metric) {
    // Round to 4 decimal places to avoid floating point issues
    final latKey = lat.toStringAsFixed(4).replaceAll('.', '_');
    final lonKey = lon.toStringAsFixed(4).replaceAll('.', '_');
    return '${latKey}_${lonKey}_$metric.json';
  }
  
  /// Get cache directory path
  static Future<Directory> _getCacheDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${appDir.path}/$_cacheDir');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }
  
  /// Get cache file for a specific field+metric
  static Future<File> _getCacheFile(double lat, double lon, String metric) async {
    final dir = await _getCacheDirectory();
    return File('${dir.path}/${_getCacheKey(lat, lon, metric)}');
  }
  
  /// Check if cache exists for a field+metric
  static Future<bool> hasCache(double lat, double lon, String metric) async {
    final file = await _getCacheFile(lat, lon, metric);
    return file.exists();
  }
  
  /// Get cached data for a field+metric
  /// Returns null if no cache exists
  static Future<CachedTimeSeriesResult?> getCached(
    double lat, 
    double lon, 
    String metric
  ) async {
    try {
      final file = await _getCacheFile(lat, lon, metric);
      if (!await file.exists()) return null;
      
      final contents = await file.readAsString();
      final json = jsonDecode(contents) as Map<String, dynamic>;
      return CachedTimeSeriesResult.fromJson(json);
    } catch (e) {
      print('Cache read error: $e');
      return null;
    }
  }
  
  /// Save data to cache
  static Future<void> saveToCache(
    double lat,
    double lon,
    String metric,
    TimeSeriesResult result,
  ) async {
    try {
      final file = await _getCacheFile(lat, lon, metric);
      final cached = CachedTimeSeriesResult(
        result: result,
        cachedAt: DateTime.now(),
        lat: lat,
        lon: lon,
        metric: metric,
      );
      await file.writeAsString(jsonEncode(cached.toJson()));
    } catch (e) {
      print('Cache write error: $e');
    }
  }
  
  /// Clear cache for a specific field+metric
  static Future<void> clearCache(double lat, double lon, String metric) async {
    try {
      final file = await _getCacheFile(lat, lon, metric);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      print('Cache clear error: $e');
    }
  }
  
  /// Clear all cached time series data
  static Future<void> clearAllCache() async {
    try {
      final dir = await _getCacheDirectory();
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (e) {
      print('Cache clear all error: $e');
    }
  }
  
  /// Get cache age as human-readable string
  static String getCacheAgeString(DateTime cachedAt) {
    final now = DateTime.now();
    final diff = now.difference(cachedAt);
    
    if (diff.inMinutes < 1) {
      return 'just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }
  
  /// List all cached fields
  static Future<List<CacheInfo>> listCachedFields() async {
    try {
      final dir = await _getCacheDirectory();
      if (!await dir.exists()) return [];
      
      final files = await dir.list().where((f) => f.path.endsWith('.json')).toList();
      final results = <CacheInfo>[];
      
      for (final file in files) {
        try {
          final contents = await (file as File).readAsString();
          final json = jsonDecode(contents) as Map<String, dynamic>;
          final cached = CachedTimeSeriesResult.fromJson(json);
          results.add(CacheInfo(
            lat: cached.lat,
            lon: cached.lon,
            metric: cached.metric,
            cachedAt: cached.cachedAt,
            filePath: file.path,
          ));
        } catch (_) {
          // Skip invalid files
        }
      }
      return results;
    } catch (e) {
      print('List cache error: $e');
      return [];
    }
  }
}

/// Wrapper for cached result with metadata
class CachedTimeSeriesResult {
  final TimeSeriesResult result;
  final DateTime cachedAt;
  final double lat;
  final double lon;
  final String metric;
  
  CachedTimeSeriesResult({
    required this.result,
    required this.cachedAt,
    required this.lat,
    required this.lon,
    required this.metric,
  });
  
  /// Age of cache in human-readable format
  String get ageString => TimeSeriesCacheService.getCacheAgeString(cachedAt);
  
  /// Check if cache is stale (older than 24 hours)
  bool get isStale => DateTime.now().difference(cachedAt).inHours > 24;
  
  factory CachedTimeSeriesResult.fromJson(Map<String, dynamic> json) {
    return CachedTimeSeriesResult(
      result: TimeSeriesResult.fromJson(json['result']),
      cachedAt: DateTime.parse(json['cached_at']),
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
      metric: json['metric'],
    );
  }
  
  Map<String, dynamic> toJson() => {
    'result': _resultToJson(result),
    'cached_at': cachedAt.toIso8601String(),
    'lat': lat,
    'lon': lon,
    'metric': metric,
  };
  
  /// Convert TimeSeriesResult to JSON (for caching)
  static Map<String, dynamic> _resultToJson(TimeSeriesResult result) => {
    'success': result.success,
    'metric': result.metric,
    'historical': result.historical.map((p) => {
      'date': p.date.toIso8601String(),
      'value': p.value,
    }).toList(),
    'forecast': result.forecast.map((p) => {
      'date': p.date.toIso8601String(),
      'value': p.value,
      'confidence_low': p.confidenceLow,
      'confidence_high': p.confidenceHigh,
    }).toList(),
    'trend': result.trend,
    'stats': result.stats,
    'timestamp': result.timestamp,
  };
}

/// Info about a cached field
class CacheInfo {
  final double lat;
  final double lon;
  final String metric;
  final DateTime cachedAt;
  final String filePath;
  
  CacheInfo({
    required this.lat,
    required this.lon,
    required this.metric,
    required this.cachedAt,
    required this.filePath,
  });
  
  String get ageString => TimeSeriesCacheService.getCacheAgeString(cachedAt);
}
