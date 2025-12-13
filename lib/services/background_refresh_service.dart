/// ============================================================================
/// FILE: background_refresh_service.dart
/// ============================================================================
/// PURPOSE: Background service that refreshes time series cache for ALL fields
///          every 5 days. Runs on app startup and periodically thereafter.
/// 
/// WHY BACKGROUND REFRESH?
///   - Users may not visit every field's time series chart regularly
///   - Satellite data updates every ~5 days (Sentinel-2 revisit time)
///   - Pre-fetching keeps cache fresh for instant display
///   - Prevents stale data accumulation across multiple fields
/// 
/// BEHAVIOR:
///   1. On app startup: Check all cached fields, refresh any older than 5 days
///   2. While running: Schedule periodic check every 5 days
///   3. Refresh runs in background, doesn't block UI
///   4. Existing cache is preserved until new data is fully fetched
/// 
/// DEPENDENCIES:
///   - timeseries_cache_service.dart: List cached fields
///   - timeseries_service.dart: Fetch fresh data
/// ============================================================================

import 'dart:async';
import 'timeseries_cache_service.dart';
import 'timeseries_service.dart';

/// Service for background refresh of all cached time series data.
class BackgroundRefreshService {
  /// How often to check for stale cache (5 days)
  static const Duration _refreshInterval = Duration(days: 5);
  
  /// Timer for periodic refresh
  static Timer? _timer;
  
  /// Flag to prevent concurrent refresh runs
  static bool _isRefreshing = false;
  
  // ===========================================================================
  // INITIALIZATION
  // ===========================================================================
  
  /// Initialize the background refresh service.
  /// Call this once on app startup (in main.dart).
  static Future<void> init() async {
    print('[BackgroundRefresh] Initializing...');
    
    // Check for stale fields immediately on startup
    await refreshStaleFields();
    
    // Schedule periodic refresh every 5 days
    _timer?.cancel();
    _timer = Timer.periodic(_refreshInterval, (_) => refreshStaleFields());
    
    print('[BackgroundRefresh] Initialized. Will check for stale cache every ${_refreshInterval.inDays} days.');
  }
  
  /// Stop the background refresh service.
  /// Call this on app dispose if needed.
  static void dispose() {
    _timer?.cancel();
    _timer = null;
    print('[BackgroundRefresh] Disposed.');
  }
  
  // ===========================================================================
  // REFRESH LOGIC
  // ===========================================================================
  
  /// Refresh all stale fields (older than 5 days).
  /// This is safe to call multiple times - it prevents concurrent runs.
  static Future<void> refreshStaleFields() async {
    // Prevent concurrent refresh runs
    if (_isRefreshing) {
      print('[BackgroundRefresh] Already refreshing, skipping...');
      return;
    }
    
    _isRefreshing = true;
    print('[BackgroundRefresh] Checking for stale cache...');
    
    try {
      // Get all cached fields
      final cachedFields = await TimeSeriesCacheService.listCachedFields();
      
      if (cachedFields.isEmpty) {
        print('[BackgroundRefresh] No cached fields found.');
        _isRefreshing = false;
        return;
      }
      
      // Find stale fields (older than 5 days)
      final now = DateTime.now();
      final staleFields = cachedFields.where((field) => 
        now.difference(field.cachedAt).inDays >= 5
      ).toList();
      
      if (staleFields.isEmpty) {
        print('[BackgroundRefresh] All ${cachedFields.length} cached fields are fresh.');
        _isRefreshing = false;
        return;
      }
      
      print('[BackgroundRefresh] Found ${staleFields.length} stale fields to refresh...');
      
      // Refresh each stale field
      int successCount = 0;
      int failCount = 0;
      
      for (final field in staleFields) {
        try {
          print('[BackgroundRefresh] Refreshing ${field.metric} at (${field.lat}, ${field.lon})...');
          
          // Fetch fresh data (this will automatically save to cache)
          final result = await TimeSeriesService.fetchTimeSeries(
            centerLat: field.lat,
            centerLon: field.lon,
            fieldSizeHectares: 10.0, // Default size
            metric: field.metric,
          );
          
          // Save to cache (rotation happens automatically)
          await TimeSeriesCacheService.saveToCache(
            field.lat,
            field.lon,
            field.metric,
            result,
          );
          
          successCount++;
          print('[BackgroundRefresh] ✓ Refreshed ${field.metric}');
        } catch (e) {
          failCount++;
          print('[BackgroundRefresh] ✗ Failed to refresh ${field.metric}: $e');
          // Continue with other fields even if one fails
        }
        
        // Small delay between requests to avoid overwhelming the server
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      print('[BackgroundRefresh] Completed: $successCount refreshed, $failCount failed.');
    } catch (e) {
      print('[BackgroundRefresh] Error during refresh: $e');
    } finally {
      _isRefreshing = false;
    }
  }
  
  // ===========================================================================
  // STATUS METHODS
  // ===========================================================================
  
  /// Check if background refresh is currently running.
  static bool get isRefreshing => _isRefreshing;
  
  /// Get the refresh interval.
  static Duration get refreshInterval => _refreshInterval;
}
