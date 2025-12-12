/// ============================================================================
/// FILE: timeseries_service.dart
/// ============================================================================
/// PURPOSE: Fetches and computes time series data for vegetation and soil indices.
///          This enables the app to show historical trends and predictions for
///          metrics like NDVI (plant health), soil moisture, nitrogen levels, etc.
/// 
/// WHAT THIS FILE DOES:
///   1. Fetches raw satellite band data from the TimeSeries HuggingFace Space
///   2. Computes vegetation indices (NDVI, EVI, NDRE, PRI) from band data
///   3. Computes soil indices (SMI, SOMI, SFI, SASI) from band data
///   4. Implements smart caching (refreshes only every 5 days)
///   5. Parallel band fetching for faster index computation
///   6. Request deduplication (prevents duplicate API calls)
/// 
/// KEY CONCEPTS:
/// 
///   SPECTRAL INDICES EXPLAINED:
///   Satellites capture reflected light in different wavelengths (bands).
///   By combining bands mathematically, we derive meaningful indices:
///   
///   VEGETATION INDICES:
///   - NDVI = (NIR - RED) / (NIR + RED)  → Plant greenness/health
///   - EVI = Enhanced Vegetation Index   → Biomass (works better in dense vegetation)
///   - NDRE = (NIR - RedEdge) / sum      → Nitrogen content
///   - PRI = (Green - Red) / sum         → Photosynthesis efficiency
///   
///   SOIL INDICES:
///   - SMI = Soil Moisture Index         → Water content in soil
///   - SOMI = Soil Organic Matter Index  → Organic content
///   - SASI = Soil Salinity Index        → Salt content
///   - SFI = Soil Fertility Index        → Combined fertility score
/// 
/// CACHING STRATEGY:
///   - Satellite images update approximately every 5 days
///   - We cache results and only refresh when cache is >5 days old
///   - Background refresh: Show cached data immediately, update in background
///   - Preserves cache on fetch failures (never shows empty data)
/// 
/// DEPENDENCIES:
///   - http: HTTP client for API requests
///   - timeseries_cache_service.dart: Local caching
/// ============================================================================

// JSON encoding/decoding for API communication
import 'dart:convert';

// Math functions (sqrt for soil salinity calculation)
import 'dart:math' as math;

// HTTP client for making API requests
import 'package:http/http.dart' as http;

// Local caching service for time series data
import 'timeseries_cache_service.dart';

/// ============================================================================
/// TimeSeriesService CLASS
/// ============================================================================
/// Provides methods to fetch and compute time series data for agricultural indices.
/// 
/// ARCHITECTURE:
///   ┌─────────────────────────────────────────────────────────────────┐
///   │                    TimeSeriesService                            │
///   ├─────────────────────────────────────────────────────────────────┤
///   │  fetchWithCache()  → Smart caching layer                        │
///   │       ↓                                                         │
///   │  fetchTimeSeries() → Routes to correct method                   │
///   │       ↓                                                         │
///   │  ┌─────────────────────┐  ┌──────────────────────────────────┐  │
///   │  │ _fetchFromAPI()    │  │ _computeIndexLocally()           │  │
///   │  │ For raw bands:     │  │ For computed indices:            │  │
///   │  │ B02, B04, VV, etc. │  │ NDVI, EVI, SMI, etc.             │  │
///   │  └─────────────────────┘  └──────────────────────────────────┘  │
///   └─────────────────────────────────────────────────────────────────┘
class TimeSeriesService {
  // ---------------------------------------------------------------------------
  // Configuration
  // ---------------------------------------------------------------------------
  
  /// URL of the TimeSeries analysis API (Hugging Face Space)
  static const String _baseUrl = 'https://Aniket2006-TimeSeries.hf.space';

  // ---------------------------------------------------------------------------
  // Supported Metrics
  // ---------------------------------------------------------------------------
  
  /// SAR (radar) metrics - work through clouds, measure soil/structure
  static const List<String> sarMetrics = ['VV', 'VH'];
  
  /// Optical (light) band metrics - direct satellite bands from Sentinel-2
  /// B02=Blue, B03=Green, B04=Red, B08=NIR, B11/B12=SWIR
  static const List<String> opticalMetrics = ['B02', 'B03', 'B04', 'B05', 'B06', 'B07', 'B08', 'B8A', 'B09', 'B11', 'B12'];
  
  /// Computed indices - calculated from band combinations
  static const List<String> computedIndices = ['NDVI', 'NDRE', 'EVI', 'PRI', 'SMI', 'SOMI', 'SFI', 'SASI'];
  
  /// All available metrics
  static List<String> get allMetrics => [...sarMetrics, ...opticalMetrics, ...computedIndices];
  
  // ===========================================================================
  // CACHE-AWARE FETCHING (Primary Entry Point)
  // ===========================================================================
  
  /// -------------------------------------------------------------------------
  /// fetchWithCache() - Smart caching layer for time series data
  /// -------------------------------------------------------------------------
  /// This is the main entry point for fetching time series data.
  /// 
  /// STRATEGY:
  ///   1. Check if cached data exists
  ///   2. If cache is fresh (<5 days old): Return cached data, skip API
  ///   3. If cache is stale (>5 days old): Return cached data, refresh in background
  ///   4. If no cache: Fetch from API
  /// 
  /// PARAMETERS:
  ///   centerLat/centerLon: Field center coordinates
  ///   fieldSizeHectares: Size of the field
  ///   metric: Which index to fetch (e.g., 'NDVI', 'SMI')
  ///   daysHistory: How many days of historical data (default: 365)
  ///   daysForecast: How many days to predict (default: 30)
  ///   forceRefresh: If true, always fetch from API (ignore cache)
  ///   onFreshData: Callback when new data arrives from background fetch
  /// 
  /// RETURNS:
  ///   CachedFetchResult with cached data (if any) and fetch status
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
    
    // Decide if we need to fetch new data
    // Refresh if: forced, no cache, or cache older than 5 days
    final shouldFetch = forceRefresh || cached == null || cached.needsRefresh;
    
    if (shouldFetch) {
      print('[TimeSeries] ${cached == null ? "No cache" : "Cache expired (${cached.ageString})"} - fetching fresh data');
      // Start background fetch (doesn't block UI)
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
    
    // Return immediately with whatever cached data we have
    return CachedFetchResult(
      cached: cached,
      hasCachedData: cached != null,
      isFetching: shouldFetch,  // Tells widget if background fetch is running
    );
  }
  
  /// -------------------------------------------------------------------------
  /// _fetchAndCache() - Background fetch with automatic caching
  /// -------------------------------------------------------------------------
  /// Runs in the background to fetch fresh data and update cache.
  /// IMPORTANT: On failure, existing cache is PRESERVED (not deleted).
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
      
      // Notify caller of fresh data (for UI update)
      onSuccess?.call(result);
    } catch (e) {
      // IMPORTANT: On failure, we keep the old cache intact
      // User sees stale data rather than no data
      print('[TimeSeries] Fetch failed for $metric: $e');
      print('[TimeSeries] Keeping previous cache - will retry after next 5-day cycle');
    }
  }

  // ===========================================================================
  // INDEX CONFIGURATION
  // ===========================================================================
  
  /// -------------------------------------------------------------------------
  /// Index Band Requirements
  /// -------------------------------------------------------------------------
  /// Maps each computed index to the satellite bands needed to calculate it.
  /// 
  /// SENTINEL-2 BANDS:
  ///   B02 = Blue (490nm)     B08 = NIR (842nm)
  ///   B03 = Green (560nm)    B11 = SWIR1 (1610nm)  
  ///   B04 = Red (665nm)      B12 = SWIR2 (2190nm)
  ///   B05 = RedEdge (705nm)
  static const Map<String, List<String>> _indexBands = {
    // Vegetation indices
    'NDVI': ['B08', 'B04'],           // NIR, Red
    'NDRE': ['B08', 'B05'],           // NIR, RedEdge
    'PRI':  ['B03', 'B04'],           // Green, Red
    'EVI':  ['B08', 'B04', 'B02'],    // NIR, Red, Blue
    
    // Soil indices
    'SMI':  ['B11', 'B12'],                    // SWIR1, SWIR2
    'SOMI': ['B08', 'B04', 'B11', 'B12'],      // NIR, Red, SWIR1, SWIR2
    'SASI': ['B11', 'B04'],                    // SWIR1, Red
    'SFI':  ['B08', 'B04', 'B11', 'B12'],      // Combined
  };

  /// Check if a metric is a computed index (vs raw band)
  static bool isComputedIndex(String metric) => _indexBands.containsKey(metric);

  // ===========================================================================
  // REQUEST DEDUPLICATION
  // ===========================================================================
  
  /// Track in-flight requests to prevent duplicate API calls
  /// Key: "lat_lon_metric" → Value: pending Future
  static final Map<String, Future<TimeSeriesResult>> _inFlightRequests = {};

  /// Generate unique key for request tracking
  static String _getRequestKey(double lat, double lon, String metric) =>
      '${lat.toStringAsFixed(4)}_${lon.toStringAsFixed(4)}_$metric';

  // ===========================================================================
  // MAIN FETCH METHOD
  // ===========================================================================
  
  /// -------------------------------------------------------------------------
  /// fetchTimeSeries() - Fetch or compute time series data
  /// -------------------------------------------------------------------------
  /// Routes to appropriate method based on metric type:
  ///   - Computed indices (NDVI, EVI, etc.): Computed locally from bands
  ///   - Raw bands (B04, VV, etc.): Fetched directly from API
  /// 
  /// Includes request deduplication to prevent duplicate API calls.
  static Future<TimeSeriesResult> fetchTimeSeries({
    required double centerLat,
    required double centerLon,
    required double fieldSizeHectares,
    required String metric,
    int daysHistory = 365,
    int daysForecast = 30,
  }) async {
    // Route to local computation for computed indices
    if (_indexBands.containsKey(metric)) {
      // Check for existing in-flight request
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
        // Cache the computed result
        await TimeSeriesCacheService.saveToCache(centerLat, centerLon, metric, result);
        print('[TimeSeries] 💾 Cached computed $metric');
        return result;
      } finally {
        _inFlightRequests.remove(key);
      }
    }
    
    // For raw bands, fetch from API with deduplication
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
  
  // ===========================================================================
  // LOCAL INDEX COMPUTATION
  // ===========================================================================
  
  /// -------------------------------------------------------------------------
  /// _computeIndexLocally() - Compute index from cached/fetched band data
  /// -------------------------------------------------------------------------
  /// For computed indices like NDVI, we:
  ///   1. Check cache for required bands
  ///   2. Fetch any missing bands in PARALLEL (fast!)
  ///   3. Apply the mathematical formula to each data point
  ///   4. Return computed time series
  /// 
  /// PARALLEL FETCHING:
  ///   If we need B04 and B08 for NDVI, and both are missing,
  ///   we fetch them simultaneously rather than one after another.
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
    
    // Check cache for each required band
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
          // Cache immediately for future use
          await TimeSeriesCacheService.saveToCache(centerLat, centerLon, band, result);
          return MapEntry(band, result);
        } catch (e) {
          print('[TimeSeries] Failed to fetch $band: $e');
          throw Exception('Cannot compute $indexName: failed to get $band data');
        }
      });
      
      // Wait for all parallel fetches to complete
      final fetchedResults = await Future.wait(futures);
      for (final entry in fetchedResults) {
        bandResults[entry.key] = entry.value;
      }
    }
    
    // Apply formula to compute the index
    print('[TimeSeries] Computing $indexName from ${bands.length} bands...');
    
    final firstBand = bandResults[bands[0]]!;
    final computedHistorical = <DataPoint>[];
    final computedForecast = <ForecastPoint>[];
    
    // Compute historical values (point by point)
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
          confidenceLow: computed - 0.02,  // Simple confidence band
          confidenceHigh: computed + 0.02,
        ));
      }
    }
    
    // Determine trend from recent data
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
  
  // ===========================================================================
  // INDEX FORMULAS
  // ===========================================================================
  
  /// -------------------------------------------------------------------------
  /// _applyFormula() - Calculate index value from band values
  /// -------------------------------------------------------------------------
  /// Each vegetation/soil index has a specific mathematical formula.
  /// Values are clamped to valid ranges to handle edge cases.
  /// 
  /// VEGETATION FORMULAS:
  ///   NDVI = (NIR - RED) / (NIR + RED)     Range: -1 to 1
  ///   NDRE = (NIR - RedEdge) / sum         Range: -1 to 1
  ///   PRI  = (Green - Red) / sum           Range: -1 to 1
  ///   EVI  = 2.5 * (NIR-R) / (NIR+6R-7.5B+1)  Range: -1 to 1
  /// 
  /// SOIL FORMULAS:
  ///   SMI  = (SWIR1 - SWIR2) / sum         Range: -1 to 1
  ///   SOMI = (NIR + RED) / (SWIR1 + SWIR2) Range: 0 to 5
  ///   SASI = sqrt(SWIR1 * RED)             Range: 0 to 1
  ///   SFI  = (NDVI * SOMI) / SASI          Range: -10 to 10
  static double _applyFormula(String indexName, List<double> values) {
    switch (indexName) {
      // -----------------------------------------------------------------------
      // VEGETATION INDICES
      // -----------------------------------------------------------------------
      case 'NDVI':
        // Normalized Difference Vegetation Index
        // Higher values = more/healthier vegetation
        final nir = values[0];  // B08
        final red = values[1];  // B04
        final sum = nir + red;
        return sum != 0 ? ((nir - red) / sum).clamp(-1.0, 1.0) : 0.0;
        
      case 'NDRE':
        // Normalized Difference Red Edge
        // Correlates with nitrogen content in plants
        final nir = values[0];  // B08
        final redEdge = values[1];  // B05
        final sum = nir + redEdge;
        return sum != 0 ? ((nir - redEdge) / sum).clamp(-1.0, 1.0) : 0.0;
        
      case 'PRI':
        // Photochemical Reflectance Index
        // Measures photosynthetic efficiency
        final green = values[0];  // B03
        final red = values[1];    // B04
        final sum = green + red;
        return sum != 0 ? ((green - red) / sum).clamp(-1.0, 1.0) : 0.0;
        
      case 'EVI':
        // Enhanced Vegetation Index
        // Better than NDVI for high-biomass areas
        final nir = values[0];   // B08
        final red = values[1];   // B04
        final blue = values[2];  // B02
        final denom = nir + 6 * red - 7.5 * blue + 1;
        return denom != 0 ? (2.5 * (nir - red) / denom).clamp(-1.0, 1.0) : 0.0;
      
      // -----------------------------------------------------------------------
      // SOIL INDICES
      // -----------------------------------------------------------------------
      case 'SMI':
        // Soil Moisture Index
        // Uses shortwave infrared to detect water content
        final b11 = values[0];  // SWIR1
        final b12 = values[1];  // SWIR2
        final smiSum = b11 + b12;
        return smiSum != 0 ? ((b11 - b12) / smiSum).clamp(-1.0, 1.0) : 0.0;
        
      case 'SOMI':
        // Soil Organic Matter Index
        // Higher values = more organic matter
        final somNir = values[0];   // B08
        final somRed = values[1];   // B04
        final somSwir1 = values[2]; // B11
        final somSwir2 = values[3]; // B12
        final somiDenom = somSwir1 + somSwir2;
        return somiDenom != 0 ? ((somNir + somRed) / somiDenom).clamp(0.0, 5.0) : 0.0;
        
      case 'SASI':
        // Soil Salinity Index
        // High values indicate salt accumulation
        final sasiB11 = values[0];  // SWIR1
        final sasiB04 = values[1];  // RED
        final product = sasiB11 * sasiB04;
        return product > 0 ? math.sqrt(product).clamp(0.0, 1.0) : 0.0;
        
      case 'SFI':
        // Soil Fertility Index (composite)
        // Combines NDVI, SOMI, and SASI
        final sfiNir = values[0];    // B08
        final sfiRed = values[1];    // B04
        final sfiSwir1 = values[2];  // B11
        final sfiSwir2 = values[3];  // B12
        // Calculate component indices
        final nirRedSum = sfiNir + sfiRed;
        final sfiNdvi = nirRedSum != 0 ? (sfiNir - sfiRed) / nirRedSum : 0.0;
        final swirSum = sfiSwir1 + sfiSwir2;
        final sfiSomi = swirSum != 0 ? (sfiNir + sfiRed) / swirSum : 0.0;
        final sfiSasiProduct = sfiSwir1 * sfiRed;
        final sasiValue = sfiSasiProduct > 0 ? math.sqrt(sfiSasiProduct) : 0.001;
        // Combined fertility score
        return ((sfiNdvi * sfiSomi) / sasiValue).clamp(-10.0, 10.0);
        
      default:
        return 0.0;
    }
  }
  
  // ===========================================================================
  // API COMMUNICATION
  // ===========================================================================
  
  /// -------------------------------------------------------------------------
  /// _fetchFromAPI() - Fetch raw band data from HuggingFace Space
  /// -------------------------------------------------------------------------
  /// Makes HTTP request to the TimeSeries API to get historical and
  /// predicted values for a specific satellite band or metric.
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
      ).timeout(const Duration(minutes: 500)); // Long timeout for satellite data

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

// =============================================================================
// DATA MODELS
// =============================================================================

/// ============================================================================
/// DataPoint - A single historical data point
/// ============================================================================
/// Represents one measurement: date + value.
/// Used for historical data where we have actual satellite observations.
class DataPoint {
  /// Date of the measurement
  final DateTime date;
  
  /// The measured value (e.g., NDVI of 0.65)
  final double value;

  DataPoint({required this.date, required this.value});

  factory DataPoint.fromJson(Map<String, dynamic> json) {
    return DataPoint(
      date: DateTime.parse(json['date']),
      value: (json['value'] as num).toDouble(),
    );
  }
}

/// ============================================================================
/// ForecastPoint - A predicted future data point with confidence
/// ============================================================================
/// Includes confidence bounds because predictions have uncertainty.
class ForecastPoint {
  final DateTime date;
  final double value;
  
  /// Lower bound of prediction (95% confidence)
  final double? confidenceLow;
  
  /// Upper bound of prediction (95% confidence)
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

/// ============================================================================
/// TimeSeriesResult - Complete time series response
/// ============================================================================
/// Contains historical data, predictions, and analysis.
class TimeSeriesResult {
  final bool success;
  
  /// Which metric this data represents (e.g., "NDVI", "SMI")
  final String metric;
  
  /// Historical observations (past data)
  final List<DataPoint> historical;
  
  /// Predicted future values
  final List<ForecastPoint> forecast;
  
  /// Overall trend: "improving", "declining", or "stable"
  final String trend;
  
  /// Additional statistics (count, min, max, etc.)
  final Map<String, double> stats;
  
  /// When this data was fetched
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

  /// Get all data points combined (for charting)
  List<DataPoint> get allPoints {
    final all = [...historical];
    for (final f in forecast) {
      all.add(DataPoint(date: f.date, value: f.value));
    }
    return all;
  }
  
  /// Get emoji icon for trend
  String get trendIcon {
    switch (trend) {
      case 'improving': return '📈';
      case 'declining': return '📉';
      default: return '➡️';
    }
  }
}

/// ============================================================================
/// CachedFetchResult - Result of a cache-aware fetch
/// ============================================================================
/// Tells the UI what data is available and if a background fetch is running.
class CachedFetchResult {
  /// Cached data (if any)
  final CachedTimeSeriesResult? cached;
  
  /// Whether cached data is available
  final bool hasCachedData;
  
  /// Whether a background API fetch is in progress
  final bool isFetching;
  
  CachedFetchResult({
    this.cached,
    required this.hasCachedData,
    this.isFetching = false,
  });
  
  /// Get the cached result data
  TimeSeriesResult? get result => cached?.result;
  
  /// Get cache age string (e.g., "2h ago")
  String? get cacheAge => cached?.ageString;
  
  /// Check if cache is stale (older than 5 days)
  bool get isStale => cached?.isStale ?? true;
}
