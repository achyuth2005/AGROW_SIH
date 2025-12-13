/// ============================================================================
/// FILE: timeseries_cache_service.dart
/// ============================================================================
/// PURPOSE: Provides persistent local storage for time series data using JSON
///          files. This enables offline access and faster app startup by
///          avoiding redundant API calls for data that hasn't changed.
/// 
/// WHY FILE-BASED CACHE (vs SharedPreferences)?
///   - SharedPreferences has size limits (~500KB on Android)
///   - Time series data can be large (365 days × multiple metrics)
///   - Files allow better organization (one file per field+metric)
///   - Easier to manage individually (clear old data, inspect for debugging)
/// 
/// CACHE STRUCTURE:
///   App Documents Directory/
///   └── timeseries_cache/
///       ├── 19_0760_72_8777_NDVI.json  ← Field at (19.076, 72.8777), NDVI
///       ├── 19_0760_72_8777_SMI.json   ← Same field, Soil Moisture
///       └── 20_5937_78_9629_NDVI.json  ← Different field
/// 
/// FUZZY MATCHING:
///   GPS coordinates have floating-point precision issues. A location might
///   be stored as 19.0760 but requested as 19.07599999. The fuzzy matching
///   algorithm finds cached data within ~11 meters of the requested location.
/// 
/// CACHE EXPIRY:
///   Satellite data updates every ~5 days (Sentinel-2 revisit time).
///   Cache older than 5 days is considered "stale" and triggers a refresh.
/// 
/// DEPENDENCIES:
///   - dart:io: File system access
///   - dart:convert: JSON serialization
///   - path_provider: App documents directory
///   - timeseries_service.dart: TimeSeriesResult model
/// ============================================================================

// JSON encoding/decoding
import 'dart:convert';

// File system operations
import 'dart:io';

// App documents directory access
import 'package:path_provider/path_provider.dart';

// Import the result model from timeseries service
import 'timeseries_service.dart';

/// ============================================================================
/// TimeSeriesCacheService CLASS
/// ============================================================================
/// Manages file-based caching for time series data.
/// All methods are static for easy access throughout the app.
class TimeSeriesCacheService {
  /// Name of the cache subdirectory
  static const String _cacheDir = 'timeseries_cache';
  
  /// Maximum number of backup versions to keep (for fallback)
  static const int _maxVersions = 3;
  
  // ===========================================================================
  // CACHE KEY GENERATION
  // ===========================================================================
  
  /// Generate a unique filename for a field+metric combination.
  /// Converts coordinates to safe filename format by replacing . with _
  /// Example: (19.0760, 72.8777, "NDVI") → "19_0760_72_8777_NDVI.json"
  /// Version 0 = current, 1-3 = backup versions
  static String _getCacheKey(double lat, double lon, String metric, {int version = 0}) {
    // Round to 4 decimal places for consistency (~11m precision)
    final latKey = lat.toStringAsFixed(4).replaceAll('.', '_');
    final lonKey = lon.toStringAsFixed(4).replaceAll('.', '_');
    final versionSuffix = version == 0 ? '' : '_v$version';
    return '${latKey}_${lonKey}_$metric$versionSuffix.json';
  }
  
  // ===========================================================================
  // DIRECTORY MANAGEMENT
  // ===========================================================================
  
  /// Get or create the cache directory.
  /// Creates the directory if it doesn't exist.
  static Future<Directory> _getCacheDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${appDir.path}/$_cacheDir');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }
  
  /// Get the cache file path for a specific field+metric and version.
  static Future<File> _getCacheFile(double lat, double lon, String metric, {int version = 0}) async {
    final dir = await _getCacheDirectory();
    return File('${dir.path}/${_getCacheKey(lat, lon, metric, version: version)}');
  }
  
  /// Rotate cache versions before saving new data.
  /// Current → v1 → v2 → v3 → deleted
  static Future<void> _rotateVersions(double lat, double lon, String metric) async {
    try {
      final dir = await _getCacheDirectory();
      
      // Delete oldest version (v3 if exists)
      final v3File = File('${dir.path}/${_getCacheKey(lat, lon, metric, version: 3)}');
      if (await v3File.exists()) {
        await v3File.delete();
        print('[Cache] Deleted oldest backup v3 for $metric');
      }
      
      // Rotate v2 → v3
      final v2File = File('${dir.path}/${_getCacheKey(lat, lon, metric, version: 2)}');
      if (await v2File.exists()) {
        await v2File.rename(v3File.path);
      }
      
      // Rotate v1 → v2
      final v1File = File('${dir.path}/${_getCacheKey(lat, lon, metric, version: 1)}');
      if (await v1File.exists()) {
        await v1File.rename(v2File.path);
      }
      
      // Rotate current → v1
      final currentFile = await _getCacheFile(lat, lon, metric);
      if (await currentFile.exists()) {
        await currentFile.rename(v1File.path);
        print('[Cache] Rotated current cache to v1 for $metric');
      }
    } catch (e) {
      print('[Cache] Version rotation error: $e');
    }
  }
  
  // ===========================================================================
  // CACHE OPERATIONS
  // ===========================================================================
  
  /// Check if cache exists for a field+metric combination.
  static Future<bool> hasCache(double lat, double lon, String metric) async {
    final file = await _getCacheFile(lat, lon, metric);
    return file.exists();
  }
  
  /// -------------------------------------------------------------------------
  /// getCached() - Retrieve cached data with fuzzy coordinate matching
  /// -------------------------------------------------------------------------
  /// Returns cached data if found, null otherwise.
  /// 
  /// FUZZY MATCHING ALGORITHM:
  /// 1. First try exact filename match (fastest)
  /// 2. If not found, scan directory for files within ~11 meters
  /// 3. Return the closest match if found
  /// 
  /// This handles GPS precision issues where a location might be
  /// stored as 19.0760 but later requested as 19.0759999.
  static Future<CachedTimeSeriesResult?> getCached(
    double lat, 
    double lon, 
    String metric
  ) async {
    try {
      // -----------------------------------------------------------------------
      // Step 1: Try all versions (current, v1, v2, v3) until one works
      // -----------------------------------------------------------------------
      for (int version = 0; version <= _maxVersions; version++) {
        final file = await _getCacheFile(lat, lon, metric, version: version);
        if (await file.exists()) {
          try {
            final contents = await file.readAsString();
            final json = jsonDecode(contents) as Map<String, dynamic>;
            if (version == 0) {
              print('[Cache] Found current cache for $metric at $lat, $lon');
            } else {
              print('[Cache] Using fallback v$version for $metric (current was corrupt)');
            }
            return CachedTimeSeriesResult.fromJson(json);
          } catch (e) {
            print('[Cache] Version $version corrupt for $metric: $e');
            continue; // Try next version
          }
        }
      }
      
      // -----------------------------------------------------------------------
      // Step 2: Fuzzy search within ~11 meters (0.0001 degrees)
      // -----------------------------------------------------------------------
      print('[Cache] Exact match failed, trying fuzzy search for $metric near $lat, $lon');
      final dir = await _getCacheDirectory();
      if (!await dir.exists()) return null;
      
      final files = dir.listSync().where((f) => f.path.endsWith('.json'));
      File? closestFile;
      double minDist = 0.0001; // Threshold: ~11 meters
      
      for (final f in files) {
        final filename = f.uri.pathSegments.last;
        // Skip files for different metrics
        if (!filename.contains(metric)) continue;
        
        try {
          // Parse the cached file to extract coordinates
          final content = await (f as File).readAsString();
          final json = jsonDecode(content) as Map<String, dynamic>;
          
          if (json['metric'] != metric) continue;
          
          final fLat = (json['lat'] as num).toDouble();
          final fLon = (json['lon'] as num).toDouble();
          
          // Manhattan distance (good enough for small distances)
          final dist = (fLat - lat).abs() + (fLon - lon).abs();
          
          if (dist < minDist) {
            minDist = dist;
            closestFile = f as File;
          }
        } catch (_) {
          continue; // Skip invalid files
        }
      }
      
      // -----------------------------------------------------------------------
      // Step 3: Return closest match if found
      // -----------------------------------------------------------------------
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
  
  /// -------------------------------------------------------------------------
  /// saveToCache() - Store time series data to a file
  /// -------------------------------------------------------------------------
  /// Saves the result along with metadata (coordinates, timestamp).
  static Future<void> saveToCache(
    double lat,
    double lon,
    String metric,
    TimeSeriesResult result,
  ) async {
    try {
      // Rotate existing versions before saving new data
      await _rotateVersions(lat, lon, metric);
      
      final file = await _getCacheFile(lat, lon, metric);
      final cached = CachedTimeSeriesResult(
        result: result,
        cachedAt: DateTime.now(),
        lat: lat,
        lon: lon,
        metric: metric,
      );
      await file.writeAsString(jsonEncode(cached.toJson()));
      print('[Cache] Saved new version for $metric (kept ${_maxVersions} backups)');
    } catch (e) {
      print('[Cache] Write error: $e');
    }
  }
  
  /// Clear cache for a specific field+metric.
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
  
  /// Clear ALL cached time series data.
  /// Use with caution - this deletes everything!
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
  
  // ===========================================================================
  // UTILITY METHODS
  // ===========================================================================
  
  /// Convert cache age to human-readable string.
  /// Examples: "just now", "5m ago", "2h ago", "3d ago"
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
  
  /// List all cached fields (for debugging/management).
  /// Returns info about each cached file.
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

// =============================================================================
// DATA MODELS
// =============================================================================

/// ============================================================================
/// CachedTimeSeriesResult - Wrapper with cache metadata
/// ============================================================================
/// Wraps the TimeSeriesResult with additional metadata needed for caching:
/// - When it was cached (for expiry checking)
/// - Original coordinates (for fuzzy matching)
/// - Which metric it represents
class CachedTimeSeriesResult {
  /// The actual time series data
  final TimeSeriesResult result;
  
  /// When this data was cached
  final DateTime cachedAt;
  
  /// Original coordinates (for fuzzy matching)
  final double lat;
  final double lon;
  
  /// Which metric this cache represents
  final String metric;
  
  CachedTimeSeriesResult({
    required this.result,
    required this.cachedAt,
    required this.lat,
    required this.lon,
    required this.metric,
  });
  
  /// Get human-readable cache age
  String get ageString => TimeSeriesCacheService.getCacheAgeString(cachedAt);
  
  /// Check if cache is stale (older than 5 days)
  bool get isStale => DateTime.now().difference(cachedAt).inDays >= 5;
  
  /// Check if refresh is needed.
  /// Based on Sentinel-2 revisit time (~5 days).
  bool get needsRefresh => DateTime.now().difference(cachedAt).inDays >= 5;
  
  /// Parse from JSON (when reading cache file)
  factory CachedTimeSeriesResult.fromJson(Map<String, dynamic> json) {
    return CachedTimeSeriesResult(
      result: TimeSeriesResult.fromJson(json['result']),
      cachedAt: DateTime.parse(json['cached_at']),
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
      metric: json['metric'],
    );
  }
  
  /// Convert to JSON (when writing cache file)
  Map<String, dynamic> toJson() => {
    'result': _resultToJson(result),
    'cached_at': cachedAt.toIso8601String(),
    'lat': lat,
    'lon': lon,
    'metric': metric,
  };
  
  /// Helper to convert TimeSeriesResult to JSON
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

/// ============================================================================
/// CacheInfo - Metadata about a cached file
/// ============================================================================
/// Used by listCachedFields() for cache management/debugging.
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
