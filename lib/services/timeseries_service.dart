import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'timeseries_cache_service.dart';

/// Service to fetch time series data from AGROW TimeSeries HF Space
class TimeSeriesService {
  static const String _baseUrl = 'https://Aniket2006-TimeSeries.hf.space';

  /// Supported metrics
  /// NOTE: The HF TimeSeries API supports computed indices (NDVI, NDRE, EVI, PRI) server-side.
  /// These are computed from cached Sentinel-2 band data on the server, so we can request them directly.
  static const List<String> sarMetrics = ['VV', 'VH'];
  static const List<String> opticalMetrics = ['B02', 'B03', 'B04', 'B05', 'B06', 'B07', 'B08', 'B8A', 'B09', 'B11', 'B12'];
  static const List<String> computedIndices = ['NDVI', 'NDRE', 'EVI', 'PRI', 'SMI', 'SOMI', 'SFI', 'SASI'];
  static List<String> get allMetrics => [...sarMetrics, ...opticalMetrics, ...computedIndices];
  
  /// Fetch with cache support
  /// Returns cached data immediately if available, then fetches fresh data
  /// ONLY if cache is older than 5 days or force refresh is requested.
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
    
    // Only fetch from API if:
    // 1. No cache exists, OR
    // 2. Cache is older than 5 days (needsRefresh), OR
    // 3. Force refresh requested
    final shouldFetch = forceRefresh || cached == null || cached.needsRefresh;
    
    if (shouldFetch) {
      print('[TimeSeries] ${cached == null ? "No cache" : "Cache expired (${cached.ageString})"} - fetching fresh data');
      _fetchAndCache(
        centerLat: centerLat,
        centerLon: centerLon,
        fieldSizeHectares: fieldSizeHectares,
        metric: metric,
        daysHistory: daysHistory,
        daysForecast: daysForecast,
        onSuccess: onFreshData,
      );
    } else {
      print('[TimeSeries] Using cached data (${cached.ageString}) - next refresh in ${5 - DateTime.now().difference(cached.cachedAt).inDays} days');
    }
    
    return CachedFetchResult(
      cached: cached,
      hasCachedData: cached != null,
      isFetching: shouldFetch,  // Tell widget if background fetch is running
    );
  }
  
  /// Background fetch and cache update
  /// NOTE: On failure, existing cache is PRESERVED (not deleted/nullified)
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
      print('[TimeSeries] Fetching $metric from API...');
      final result = await fetchTimeSeries(
        centerLat: centerLat,
        centerLon: centerLon,
        fieldSizeHectares: fieldSizeHectares,
        metric: metric,
        daysHistory: daysHistory,
        daysForecast: daysForecast,
      );
      
      // Only update cache on SUCCESS
      await TimeSeriesCacheService.saveToCache(
        centerLat,
        centerLon,
        metric,
        result,
      );
      print('[TimeSeries] Cache updated for $metric');
      
      // Notify caller of fresh data
      onSuccess?.call(result);
    } catch (e) {
      // IMPORTANT: On failure, we do NOT delete/clear existing cache
      // The old cached data remains valid and will be used
      print('[TimeSeries] Fetch failed for $metric: $e');
      print('[TimeSeries] Keeping previous cache - will retry after next 5-day cycle');
    }
  }

  /// Computed indices configuration: indexName -> [required bands]
  static const Map<String, List<String>> _indexBands = {
    'NDVI': ['B08', 'B04'],  // NDVI = (NIR - RED) / (NIR + RED)
    'NDRE': ['B08', 'B05'],  // NDRE = (NIR - RedEdge) / (NIR + RedEdge)
    'PRI':  ['B03', 'B04'],  // PRI = (Green - Red) / (Green + Red)
    'EVI':  ['B08', 'B04', 'B02'],  // EVI = 2.5 * (NIR - RED) / (NIR + 6*RED - 7.5*BLUE + 1)
    // SOIL INDICES
    'SMI':  ['B11', 'B12'],           // SMI = (SWIR1 - SWIR2) / (SWIR1 + SWIR2) - Soil Moisture
    'SOMI': ['B08', 'B04', 'B11', 'B12'], // SOMI = (NIR + RED) / (SWIR1 + SWIR2) - Soil Organic Matter
    'SASI': ['B11', 'B04'],           // SASI = sqrt(SWIR1 * RED) - Soil Salinity
    'SFI':  ['B08', 'B04', 'B11', 'B12'], // SFI = (NDVI * SOMI) / SASI - Soil Fertility
  };

  /// Check if metric is a computed index
  static bool isComputedIndex(String metric) => _indexBands.containsKey(metric);

  /// Track in-flight fetch requests to prevent duplicates
  static final Map<String, Future<TimeSeriesResult>> _inFlightRequests = {};

  /// Get unique key for in-flight tracking
  static String _getRequestKey(double lat, double lon, String metric) =>
      '${lat.toStringAsFixed(4)}_${lon.toStringAsFixed(4)}_$metric';

  /// Fetch time series data for a location
  /// For computed indices (NDVI, NDRE, EVI, PRI), computes locally from band data
  static Future<TimeSeriesResult> fetchTimeSeries({
    required double centerLat,
    required double centerLon,
    required double fieldSizeHectares,
    required String metric,
    int daysHistory = 365,
    int daysForecast = 30,
  }) async {
    // For computed indices, compute locally from band data
    if (_indexBands.containsKey(metric)) {
      // Check if there's already an in-flight request for this index
      final key = _getRequestKey(centerLat, centerLon, metric);
      if (_inFlightRequests.containsKey(key)) {
        print('[TimeSeries] ⏳ Reusing in-flight request for $metric');
        return _inFlightRequests[key]!;
      }
      
      // Start new computation and track it
      final future = _computeIndexLocally(
        centerLat: centerLat,
        centerLon: centerLon,
        fieldSizeHectares: fieldSizeHectares,
        indexName: metric,
        bands: _indexBands[metric]!,
        daysHistory: daysHistory,
        daysForecast: daysForecast,
      );
      
      _inFlightRequests[key] = future;
      try {
        final result = await future;
        // Cache the computed index result!
        await TimeSeriesCacheService.saveToCache(centerLat, centerLon, metric, result);
        print('[TimeSeries] 💾 Cached computed $metric');
        return result;
      } finally {
        _inFlightRequests.remove(key);
      }
    }
    
    // For direct bands/metrics, fetch from API with deduplication
    final key = _getRequestKey(centerLat, centerLon, metric);
    if (_inFlightRequests.containsKey(key)) {
      print('[TimeSeries] ⏳ Reusing in-flight request for $metric');
      return _inFlightRequests[key]!;
    }
    
    final future = _fetchFromAPI(
      centerLat: centerLat,
      centerLon: centerLon,
      fieldSizeHectares: fieldSizeHectares,
      metric: metric,
      daysHistory: daysHistory,
      daysForecast: daysForecast,
    );
    
    _inFlightRequests[key] = future;
    try {
      return await future;
    } finally {
      _inFlightRequests.remove(key);
    }
  }
  
  /// Compute vegetation index locally from band data (cached or fetched)
  static Future<TimeSeriesResult> _computeIndexLocally({
    required double centerLat,
    required double centerLon,
    required double fieldSizeHectares,
    required String indexName,
    required List<String> bands,
    int daysHistory = 365,
    int daysForecast = 30,
  }) async {
    print('[TimeSeries] Computing $indexName locally from bands: $bands');
    
    // Collect cached data and identify missing bands
    final bandResults = <String, TimeSeriesResult>{};
    final missingBands = <String>[];
    
    for (final band in bands) {
      final cached = await TimeSeriesCacheService.getCached(centerLat, centerLon, band);
      if (cached != null) {
        print('[TimeSeries] ✓ Using cached data for $band');
        bandResults[band] = cached.result;
      } else {
        print('[TimeSeries] ✗ Missing cache for $band - will fetch');
        missingBands.add(band);
      }
    }
    
    // Fetch ALL missing bands in PARALLEL (much faster than sequential!)
    if (missingBands.isNotEmpty) {
      print('[TimeSeries] Fetching ${missingBands.length} missing bands in parallel: $missingBands');
      
      final futures = missingBands.map((band) async {
        try {
          final result = await _fetchFromAPI(
            centerLat: centerLat,
            centerLon: centerLon,
            fieldSizeHectares: fieldSizeHectares,
            metric: band,
            daysHistory: daysHistory,
            daysForecast: daysForecast,
          );
          // Cache immediately
          await TimeSeriesCacheService.saveToCache(centerLat, centerLon, band, result);
          return MapEntry(band, result);
        } catch (e) {
          print('[TimeSeries] Failed to fetch $band: $e');
          throw Exception('Cannot compute $indexName: failed to get $band data');
        }
      });
      
      final fetchedResults = await Future.wait(futures);
      for (final entry in fetchedResults) {
        bandResults[entry.key] = entry.value;
      }
    }
    
    // Compute the index from band data
    print('[TimeSeries] Computing $indexName from ${bands.length} bands...');
    
    final firstBand = bandResults[bands[0]]!;
    final computedHistorical = <DataPoint>[];
    final computedForecast = <ForecastPoint>[];
    
    // Compute historical values
    for (int i = 0; i < firstBand.historical.length; i++) {
      final date = firstBand.historical[i].date;
      final values = <double>[];
      
      bool allValid = true;
      for (final band in bands) {
        if (i < bandResults[band]!.historical.length) {
          values.add(bandResults[band]!.historical[i].value);
        } else {
          allValid = false;
          break;
        }
      }
      
      if (allValid) {
        final computed = _applyFormula(indexName, values);
        computedHistorical.add(DataPoint(date: date, value: computed));
      }
    }
    
    // Compute forecast values
    for (int i = 0; i < firstBand.forecast.length; i++) {
      final date = firstBand.forecast[i].date;
      final values = <double>[];
      
      bool allValid = true;
      for (final band in bands) {
        if (i < bandResults[band]!.forecast.length) {
          values.add(bandResults[band]!.forecast[i].value);
        } else {
          allValid = false;
          break;
        }
      }
      
      if (allValid) {
        final computed = _applyFormula(indexName, values);
        computedForecast.add(ForecastPoint(
          date: date,
          value: computed,
          confidenceLow: computed - 0.02,
          confidenceHigh: computed + 0.02,
        ));
      }
    }
    
    // Calculate trend
    String trend = 'stable';
    if (computedHistorical.length >= 5) {
      final recent = computedHistorical.sublist(computedHistorical.length - 5);
      final first = recent.first.value;
      final last = recent.last.value;
      if (last - first > 0.01) trend = 'improving';
      else if (first - last > 0.01) trend = 'declining';
    }
    
    print('[TimeSeries] Computed $indexName: ${computedHistorical.length} historical, ${computedForecast.length} forecast points');
    
    return TimeSeriesResult(
      success: true,
      metric: indexName,
      historical: computedHistorical,
      forecast: computedForecast,
      trend: trend,
      stats: {
        'count': computedHistorical.length.toDouble(),
        'forecast_count': computedForecast.length.toDouble(),
      },
      timestamp: DateTime.now().toIso8601String(),
    );
  }
  
  /// Apply vegetation index formula
  static double _applyFormula(String indexName, List<double> values) {
    switch (indexName) {
      case 'NDVI':
        // NDVI = (NIR - RED) / (NIR + RED) where NIR=B08, RED=B04
        final nir = values[0];
        final red = values[1];
        final sum = nir + red;
        return sum != 0 ? ((nir - red) / sum).clamp(-1.0, 1.0) : 0.0;
        
      case 'NDRE':
        // NDRE = (NIR - RedEdge) / (NIR + RedEdge) where NIR=B08, RedEdge=B05
        final nir = values[0];
        final redEdge = values[1];
        final sum = nir + redEdge;
        return sum != 0 ? ((nir - redEdge) / sum).clamp(-1.0, 1.0) : 0.0;
        
      case 'PRI':
        // PRI = (Green - Red) / (Green + Red) where Green=B03, Red=B04
        final green = values[0];
        final red = values[1];
        final sum = green + red;
        return sum != 0 ? ((green - red) / sum).clamp(-1.0, 1.0) : 0.0;
        
      case 'EVI':
        // EVI = 2.5 * (NIR - RED) / (NIR + 6*RED - 7.5*BLUE + 1) where NIR=B08, RED=B04, BLUE=B02
        final nir = values[0];
        final red = values[1];
        final blue = values[2];
        final denom = nir + 6 * red - 7.5 * blue + 1;
        return denom != 0 ? (2.5 * (nir - red) / denom).clamp(-1.0, 1.0) : 0.0;
      
      // SOIL INDICES
      case 'SMI':
        // SMI (Soil Moisture Index) = (SWIR1 - SWIR2) / (SWIR1 + SWIR2) where SWIR1=B11, SWIR2=B12
        final b11 = values[0];
        final b12 = values[1];
        final smiSum = b11 + b12;
        return smiSum != 0 ? ((b11 - b12) / smiSum).clamp(-1.0, 1.0) : 0.0;
        
      case 'SOMI':
        // SOMI (Soil Organic Matter Index) = (NIR + RED) / (SWIR1 + SWIR2)
        final somNir = values[0];  // B08
        final somRed = values[1];  // B04
        final somSwir1 = values[2]; // B11
        final somSwir2 = values[3]; // B12
        final somiDenom = somSwir1 + somSwir2;
        return somiDenom != 0 ? ((somNir + somRed) / somiDenom).clamp(0.0, 5.0) : 0.0;
        
      case 'SASI':
        // SASI (Soil Salinity Index) = sqrt(SWIR1 * RED) where SWIR1=B11, RED=B04
        final sasiB11 = values[0];
        final sasiB04 = values[1];
        final product = sasiB11 * sasiB04;
        return product > 0 ? math.sqrt(product).clamp(0.0, 1.0) : 0.0;
        
      case 'SFI':
        // SFI (Soil Fertility Index) = (NDVI * SOMI) / SASI
        final sfiNir = values[0];   // B08
        final sfiRed = values[1];   // B04
        final sfiSwir1 = values[2]; // B11
        final sfiSwir2 = values[3]; // B12
        // Calculate NDVI
        final nirRedSum = sfiNir + sfiRed;
        final sfiNdvi = nirRedSum != 0 ? (sfiNir - sfiRed) / nirRedSum : 0.0;
        // Calculate SOMI
        final swirSum = sfiSwir1 + sfiSwir2;
        final sfiSomi = swirSum != 0 ? (sfiNir + sfiRed) / swirSum : 0.0;
        // Calculate SASI
        final sfiSasiProduct = sfiSwir1 * sfiRed;
        final sasiValue = sfiSasiProduct > 0 ? math.sqrt(sfiSasiProduct) : 0.001; // Avoid division by zero
        // SFI = (NDVI * SOMI) / SASI
        return ((sfiNdvi * sfiSomi) / sasiValue).clamp(-10.0, 10.0);
        
      default:
        return 0.0;
    }
  }
  
  /// Fetch data directly from the HF TimeSeries API (for raw bands)
  static Future<TimeSeriesResult> _fetchFromAPI({
    required double centerLat,
    required double centerLon,
    required double fieldSizeHectares,
    required String metric,
    int daysHistory = 365,
    int daysForecast = 30,
  }) async {
    try {
      print('[TimeSeries] Fetching $metric from API...');
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
      ).timeout(const Duration(minutes: 500)); // Long timeout as requested to avoid premature failures

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('[TimeSeries] Successfully received $metric data');
        return TimeSeriesResult.fromJson(data);
      } else {
        throw Exception('Failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Time series error for $metric: $e');
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
  final bool isFetching;  // Whether a background API fetch is in progress
  
  CachedFetchResult({
    this.cached,
    required this.hasCachedData,
    this.isFetching = false,
  });
  
  /// Get the cached result data (if available)
  TimeSeriesResult? get result => cached?.result;
  
  /// Get cache age string (e.g., "2h ago")
  String? get cacheAge => cached?.ageString;
  
  /// Check if cache is stale (older than 5 days)
  bool get isStale => cached?.isStale ?? true;
}
