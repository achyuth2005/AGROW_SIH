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
  /// Uses fuzzy matching if exact file is not found (handles FP precision issues)
  static Future<CachedTimeSeriesResult?> getCached(
    double lat, 
    double lon, 
    String metric
  ) async {
    try {
      // 1. Try exact match first
      final file = await _getCacheFile(lat, lon, metric);
      if (await file.exists()) {
        try {
          final contents = await file.readAsString();
          final json = jsonDecode(contents) as Map<String, dynamic>;
          print('[Cache] Found exact match for $metric at $lat, $lon');
          return CachedTimeSeriesResult.fromJson(json);
        } catch (e) {
          print('[Cache] Error reading exact match: $e');
        }
      }
      
      // 2. Fuzzy match: Find closest file within ~11 meters (0.0001 degrees)
      print('[Cache] Exact match failed, trying fuzzy search for $metric near $lat, $lon');
      final dir = await _getCacheDirectory();
      if (!await dir.exists()) return null;
      
      final files = dir.listSync().where((f) => f.path.endsWith('.json'));
      File? closestFile;
      double minDist = 0.0001; // Threshold ~11m
      
      for (final f in files) {
        final filename = f.uri.pathSegments.last;
        // Expected format: lat_lon_metric.json (with underscores for decimal points)
        // e.g. 26_1234_91_5678_NDVI.json
        if (!filename.contains(metric)) continue;
        
        try {
          final parts = filename.split('_');
          if (parts.length < 5) continue;
          
          // Reconstruct lat/lon from "26_1234" -> 26.1234
          // Logic: Find the metric part index, everything before is lat/lon
          // This parsing is tricky with underscores. 
          // Alternative: Parse the JSON content directly? Slower but safer.
          // Let's rely on JSON content for safety as filename parsing is fragile.
          
          final content = await (f as File).readAsString();
          final json = jsonDecode(content) as Map<String, dynamic>;
          
          if (json['metric'] != metric) continue;
          
          final fLat = (json['lat'] as num).toDouble();
          final fLon = (json['lon'] as num).toDouble();
          
          final dist = (fLat - lat).abs() + (fLon - lon).abs(); // Manhattan dist is sufficient here
          
          if (dist < minDist) {
            minDist = dist;
            closestFile = f as File;
          }
        } catch (_) {
          continue;
        }
      }
      
      if (closestFile != null) {
        print('[Cache] Found fuzzy match: ${closestFile.path} (dist: $minDist component-sum)');
        final contents = await closestFile.readAsString();
        return CachedTimeSeriesResult.fromJson(jsonDecode(contents));
      }

      print('[Cache] No cache found for $metric at $lat, $lon');
      return null;
    } catch (e) {
      print('[Cache] Read error: $e');
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
  
  /// Check if cache is stale (older than 5 days)
  bool get isStale => DateTime.now().difference(cachedAt).inDays >= 5;
  
  /// Check if refresh is needed (older than 5 days)
  /// Industry standard: Satellite data updates ~5 days for Sentinel-2
  bool get needsRefresh => DateTime.now().difference(cachedAt).inDays >= 5;
  
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
