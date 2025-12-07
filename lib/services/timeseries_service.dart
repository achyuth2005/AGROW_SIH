import 'dart:convert';
import 'package:http/http.dart' as http;
import 'timeseries_cache_service.dart';

/// Service to fetch time series data from AGROW TimeSeries HF Space
class TimeSeriesService {
  static const String _baseUrl = 'https://Aniket2006-TimeSeries.hf.space';

  /// Supported metrics
  static const List<String> sarMetrics = ['VV', 'VH'];
  static const List<String> opticalMetrics = ['B02', 'B03', 'B04', 'B08', 'B8A', 'B11', 'B12'];
  static List<String> get allMetrics => [...sarMetrics, ...opticalMetrics];
  
  /// Fetch with cache support
  /// Returns cached data immediately if available, then fetches fresh data
  /// The onFreshData callback is called when new data arrives from API
  static Future<CachedFetchResult> fetchWithCache({
    required double centerLat,
    required double centerLon,
    required double fieldSizeHectares,
    required String metric,
    int daysHistory = 365,
    int daysForecast = 30,
    bool forceRefresh = false,
    void Function(TimeSeriesResult freshData)? onFreshData,
  }) async {
    // Try to get cached data first
    CachedTimeSeriesResult? cached;
    if (!forceRefresh) {
      cached = await TimeSeriesCacheService.getCached(centerLat, centerLon, metric);
    }
    
    // Start background fetch
    _fetchAndCache(
      centerLat: centerLat,
      centerLon: centerLon,
      fieldSizeHectares: fieldSizeHectares,
      metric: metric,
      daysHistory: daysHistory,
      daysForecast: daysForecast,
      onSuccess: onFreshData,
    );
    
    return CachedFetchResult(
      cached: cached,
      hasCachedData: cached != null,
    );
  }
  
  /// Background fetch and cache update
  static Future<void> _fetchAndCache({
    required double centerLat,
    required double centerLon,
    required double fieldSizeHectares,
    required String metric,
    int daysHistory = 365,
    int daysForecast = 30,
    void Function(TimeSeriesResult)? onSuccess,
  }) async {
    try {
      final result = await fetchTimeSeries(
        centerLat: centerLat,
        centerLon: centerLon,
        fieldSizeHectares: fieldSizeHectares,
        metric: metric,
        daysHistory: daysHistory,
        daysForecast: daysForecast,
      );
      
      // Save to cache
      await TimeSeriesCacheService.saveToCache(
        centerLat,
        centerLon,
        metric,
        result,
      );
      
      // Notify caller of fresh data
      onSuccess?.call(result);
    } catch (e) {
      print('Background fetch error: $e');
      // Silently fail - we already have cached data (hopefully)
    }
  }

  /// Fetch time series data for a location
  static Future<TimeSeriesResult> fetchTimeSeries({
    required double centerLat,
    required double centerLon,
    required double fieldSizeHectares,
    required String metric,
    int daysHistory = 365,
    int daysForecast = 30,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/timeseries'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'center_lat': centerLat,
          'center_lon': centerLon,
          'field_size_hectares': fieldSizeHectares,
          'metric': metric,
          'days_history': daysHistory,
          'days_forecast': daysForecast,
        }),
      ).timeout(const Duration(minutes: 200));  // Long timeout for ML processing

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return TimeSeriesResult.fromJson(data);
      } else {
        throw Exception('Failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Time series error: $e');
    }
  }
}

/// Data point model
class DataPoint {
  final DateTime date;
  final double value;

  DataPoint({required this.date, required this.value});

  factory DataPoint.fromJson(Map<String, dynamic> json) {
    return DataPoint(
      date: DateTime.parse(json['date']),
      value: (json['value'] as num).toDouble(),
    );
  }
}

/// Forecast point with confidence band
class ForecastPoint {
  final DateTime date;
  final double value;
  final double? confidenceLow;
  final double? confidenceHigh;

  ForecastPoint({
    required this.date,
    required this.value,
    this.confidenceLow,
    this.confidenceHigh,
  });

  factory ForecastPoint.fromJson(Map<String, dynamic> json) {
    return ForecastPoint(
      date: DateTime.parse(json['date']),
      value: (json['value'] as num).toDouble(),
      confidenceLow: (json['confidence_low'] as num?)?.toDouble(),
      confidenceHigh: (json['confidence_high'] as num?)?.toDouble(),
    );
  }
}

/// Time series result
class TimeSeriesResult {
  final bool success;
  final String metric;
  final List<DataPoint> historical;
  final List<ForecastPoint> forecast;
  final String trend;
  final Map<String, double> stats;
  final String timestamp;

  TimeSeriesResult({
    required this.success,
    required this.metric,
    required this.historical,
    required this.forecast,
    required this.trend,
    required this.stats,
    required this.timestamp,
  });

  factory TimeSeriesResult.fromJson(Map<String, dynamic> json) {
    return TimeSeriesResult(
      success: json['success'] ?? false,
      metric: json['metric'] ?? '',
      historical: (json['historical'] as List? ?? [])
          .map((e) => DataPoint.fromJson(e))
          .toList(),
      forecast: (json['forecast'] as List? ?? [])
          .map((e) => ForecastPoint.fromJson(e))
          .toList(),
      trend: json['trend'] ?? 'stable',
      stats: Map<String, double>.from(
        (json['stats'] as Map? ?? {}).map((k, v) => MapEntry(k, (v as num).toDouble()))
      ),
      timestamp: json['timestamp'] ?? '',
    );
  }

  /// Get all data points for charting (historical + forecast)
  List<DataPoint> get allPoints {
    final all = [...historical];
    for (final f in forecast) {
      all.add(DataPoint(date: f.date, value: f.value));
    }
    return all;
  }
  
  /// Get trend icon
  String get trendIcon {
    switch (trend) {
      case 'improving': return '📈';
      case 'declining': return '📉';
      default: return '➡️';
    }
  }
}

/// Result of a cache-aware fetch operation
class CachedFetchResult {
  final CachedTimeSeriesResult? cached;
  final bool hasCachedData;
  
  CachedFetchResult({
    this.cached,
    required this.hasCachedData,
  });
  
  /// Get the cached result data (if available)
  TimeSeriesResult? get result => cached?.result;
  
  /// Get cache age string (e.g., "2h ago")
  String? get cacheAge => cached?.ageString;
  
  /// Check if cache is stale (older than 24 hours)
  bool get isStale => cached?.isStale ?? true;
}
