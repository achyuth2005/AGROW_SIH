/// ============================================================================
/// FILE: heatmap_service.dart
/// ============================================================================
/// PURPOSE: Fetches spatial heatmap visualizations for agricultural indices.
///          Heatmaps show how values vary ACROSS the field (spatial analysis),
///          unlike time series which show how values change OVER TIME.
/// 
/// WHAT THIS FILE DOES:
///   1. Fetches heatmap images from the Heatmap HuggingFace Space
///   2. Supports pixel-wise indices (fast computation)
///   3. Supports LLM-analyzed metrics (CNN + Clustering + AI insights)
///   4. Returns base64-encoded images for display
/// 
/// HEATMAP vs TIME SERIES:
///   ┌─────────────────────────────────────────────────────────────────┐
///   │  TIME SERIES          │  HEATMAP                               │
///   ├─────────────────────────────────────────────────────────────────┤
///   │  Shows change over    │  Shows variation across space          │
///   │  time (temporal)      │  (spatial)                             │
///   │  Line/area chart      │  Color-coded map image                 │
///   │  "Is crop improving?" │  "Where are the problem areas?"        │
///   └─────────────────────────────────────────────────────────────────┘
/// 
/// TWO PROCESSING MODES:
///   1. PIXEL-WISE (Fast): Direct index calculation per pixel
///      - Soil moisture, greenness, nitrogen, etc.
///      - Returns in ~5-10 seconds
///   
///   2. LLM-ANALYZED (Slow but Smart): CNN + Clustering + AI
///      - Pest risk, disease risk, stress zones
///      - Includes AI-generated analysis and recommendations
///      - Returns in ~30-60 seconds
/// 
/// DEPENDENCIES:
///   - http: HTTP client for API requests
///   - dart:convert: JSON and base64 handling
/// ============================================================================

// JSON encoding/decoding and base64 for image data
import 'dart:convert';

// HTTP client for API requests
import 'package:http/http.dart' as http;

/// ============================================================================
/// HeatmapService CLASS
/// ============================================================================
/// Provides methods to generate and fetch heatmap visualizations.
/// 
/// USAGE:
///   final result = await HeatmapService.fetchHeatmap(
///     centerLat: 19.0760,
///     centerLon: 72.8777,
///     fieldSizeHectares: 10.0,
///     metric: 'soil_moisture',
///   );
///   // Display result.imageBytes in an Image widget
class HeatmapService {
  // ---------------------------------------------------------------------------
  // Configuration
  // ---------------------------------------------------------------------------
  
  /// URL of the Heatmap generation API (Hugging Face Space v3.0.0)
  static const String _baseUrl = 'https://aniket2006-heatmap.hf.space';
  
  // ---------------------------------------------------------------------------
  // Supported Metrics
  // ---------------------------------------------------------------------------
  
  /// Pixel-wise metrics (fast computation, ~5-10 seconds)
  /// These are computed directly from satellite band data.
  static const List<String> pixelwiseMetrics = [
    'soil_moisture',          // Water content in soil
    'soil_organic_matter',    // Organic material content
    'soil_fertility',         // Combined fertility score
    'soil_salinity',          // Salt accumulation
    'greenness',              // Vegetation health (NDVI-based)
    'nitrogen_level',         // Plant nitrogen content
    'photosynthetic_capacity', // Photosynthesis efficiency
  ];
  
  /// LLM-analyzed metrics (CNN + Clustering + AI, ~30-60 seconds)
  /// These use deep learning and AI for complex pattern detection.
  static const List<String> llmMetrics = [
    'pest_risk',       // Likelihood of pest infestation
    'disease_risk',    // Likelihood of crop disease
    'nutrient_stress', // Areas with nutrient deficiency
    'stress_zones',    // General stress pattern detection
  ];
  
  /// All supported metrics combined
  static List<String> get allMetrics => [...pixelwiseMetrics, ...llmMetrics];
  
  /// -------------------------------------------------------------------------
  /// Legacy Index Mapping
  /// -------------------------------------------------------------------------
  /// Maps old index names (SMI, NDVI, etc.) to new metric names.
  /// Provides backward compatibility with older API consumers.
  static const Map<String, String> indexToMetric = {
    'SMI': 'soil_moisture',
    'SOMI': 'soil_organic_matter',
    'SFI': 'soil_fertility',
    'SASI': 'soil_salinity',
    'NDVI': 'greenness',
    'NDRE': 'nitrogen_level',
    'PRI': 'photosynthetic_capacity',
    'EVI': 'greenness',        // Map EVI to greenness
    'NDWI': 'soil_moisture',   // Map NDWI to soil_moisture
  };

  // ===========================================================================
  // MAIN FETCH METHOD
  // ===========================================================================
  
  /// -------------------------------------------------------------------------
  /// fetchHeatmap() - Generate a heatmap for a field
  /// -------------------------------------------------------------------------
  /// Fetches a heatmap visualization for the specified metric.
  /// 
  /// PARAMETERS:
  ///   centerLat/centerLon: Field center coordinates
  ///   fieldSizeHectares: Size of the field (affects resolution)
  ///   metric: Which metric to visualize (from pixelwiseMetrics or llmMetrics)
  ///   gaussianSigma: Smoothing factor (higher = smoother/blurrier)
  ///   showFieldBoundary: Draw the field boundary on the heatmap?
  ///   overlayMode: If true, returns clean image without colorbar/title
  ///   timeSeriesData: Optional context for LLM (historical trends)
  ///   weatherData: Optional context for LLM (weather conditions)
  /// 
  /// RETURNS:
  ///   HeatmapResult with base64 image, stats, and optional AI analysis
  /// 
  /// EXAMPLE:
  ///   final result = await HeatmapService.fetchHeatmap(
  ///     centerLat: 19.0760,
  ///     centerLon: 72.8777,
  ///     fieldSizeHectares: 10.0,
  ///     metric: 'soil_moisture',
  ///   );
  ///   final imageWidget = Image.memory(Uint8List.fromList(result.imageBytes));
  static Future<HeatmapResult> fetchHeatmap({
    required double centerLat,
    required double centerLon,
    required double fieldSizeHectares,
    required String metric,
    double gaussianSigma = 1.5,
    bool showFieldBoundary = true,
    bool overlayMode = false,
    Map<String, dynamic>? timeSeriesData,
    Map<String, dynamic>? weatherData,
  }) async {
    try {
      // Build request body
      final requestBody = {
        'center_lat': centerLat,
        'center_lon': centerLon,
        'field_size_hectares': fieldSizeHectares,
        'metric': metric,
        'gaussian_sigma': gaussianSigma,      // Smoothing amount
        'show_field_boundary': showFieldBoundary,
        'overlay_mode': overlayMode,          // Clean image for overlays
      };
      
      // Add time series context for LLM (if provided)
      // This helps the AI understand historical trends when analyzing
      if (timeSeriesData != null) {
        requestBody['time_series_data'] = timeSeriesData;
      }
      
      // Add weather context for LLM (if provided)
      // Weather affects interpretation (e.g., low moisture after rain = problem)
      if (weatherData != null) {
        requestBody['weather_data'] = weatherData;
      }
      
      // Make API request
      final response = await http.post(
        Uri.parse('$_baseUrl/generate-heatmap'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 90));  // Longer timeout for LLM metrics

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return HeatmapResult.fromJson(data);
      } else {
        throw Exception('Failed to fetch heatmap: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error connecting to Heatmap service: $e');
    }
  }
  
  /// -------------------------------------------------------------------------
  /// fetchHeatmapByIndex() - Legacy method using old index names
  /// -------------------------------------------------------------------------
  /// For backward compatibility with code using SMI, NDVI, etc.
  /// Converts index names to new metric names and calls fetchHeatmap.
  static Future<HeatmapResult> fetchHeatmapByIndex({
    required double centerLat,
    required double centerLon,
    double fieldSizeHectares = 10.0,
    String indexType = 'NDVI',
    double gaussianSigma = 1.5,
    bool showFieldBoundary = true,
  }) async {
    // Convert old index name to new metric name
    final metric = indexToMetric[indexType] ?? 'greenness';
    return fetchHeatmap(
      centerLat: centerLat,
      centerLon: centerLon,
      fieldSizeHectares: fieldSizeHectares,
      metric: metric,
      gaussianSigma: gaussianSigma,
      showFieldBoundary: showFieldBoundary,
    );
  }

  /// -------------------------------------------------------------------------
  /// getHeatmapImageUrl() - Get direct URL for heatmap image
  /// -------------------------------------------------------------------------
  /// Returns a URL that can be used directly in an Image.network widget.
  /// Useful when you just need the image without stats/analysis.
  static String getHeatmapImageUrl({
    required double centerLat,
    required double centerLon,
    required double fieldSizeHectares,
    required String metric,
  }) {
    return '$_baseUrl/generate-heatmap-image'
        '?center_lat=$centerLat'
        '&center_lon=$centerLon'
        '&field_size_hectares=$fieldSizeHectares'
        '&metric=$metric';
  }
}

// =============================================================================
// DATA MODELS
// =============================================================================

/// ============================================================================
/// HeatmapResult - Response from heatmap generation API
/// ============================================================================
/// Contains the heatmap image, statistics, and optional AI analysis.
class HeatmapResult {
  // ---------------------------------------------------------------------------
  // Common Fields (all heatmaps)
  // ---------------------------------------------------------------------------
  
  /// Whether the generation was successful
  final bool success;
  
  /// Which metric was visualized
  final String metric;
  
  /// Processing mode: "pixelwise" or "llm"
  final String mode;
  
  /// Which index was used internally (e.g., "NDVI" for greenness)
  final String indexUsed;
  
  /// Statistical values for the colorbar
  final double minValue;
  final double maxValue;
  final double meanValue;
  
  /// The heatmap image as base64-encoded PNG
  final String imageBase64;
  
  /// When this heatmap was generated
  final String timestamp;
  
  /// Date of the satellite image used
  final String? imageDate;
  
  /// Dimensions of the image (e.g., "512x512")
  final String? imageSize;
  
  /// Bounding box for geo-alignment [sw_lon, sw_lat, ne_lon, ne_lat]
  /// Used when overlaying on a map
  final List<double>? bbox;
  
  /// Separate colorbar image for UI display
  final String? colorbarBase64;
  
  // ---------------------------------------------------------------------------
  // Pixel-wise Specific Fields
  // ---------------------------------------------------------------------------
  
  /// Number of patches analyzed
  final int? numPatches;
  
  /// Summary health metrics
  final Map<String, dynamic>? healthSummary;
  
  // ---------------------------------------------------------------------------
  // LLM-Analyzed Specific Fields
  // ---------------------------------------------------------------------------
  
  /// Risk/stress level: "high", "moderate", "low"
  final String? level;
  
  /// Short AI-generated analysis
  final String? analysis;
  
  /// Detailed reasoning from the LLM
  final String? detailedAnalysis;
  
  /// Numeric stress score (0.0 = healthy, 1.0 = severe stress)
  final double? stressScore;
  
  /// Distribution of clusters (for stress zone analysis)
  final Map<String, dynamic>? clusterDistribution;
  
  /// AI-generated action recommendations
  final List<String>? recommendations;

  HeatmapResult({
    required this.success,
    required this.metric,
    required this.mode,
    required this.indexUsed,
    required this.minValue,
    required this.maxValue,
    required this.meanValue,
    required this.imageBase64,
    required this.timestamp,
    this.imageDate,
    this.imageSize,
    this.bbox,
    this.colorbarBase64,
    this.numPatches,
    this.healthSummary,
    this.level,
    this.analysis,
    this.detailedAnalysis,
    this.stressScore,
    this.clusterDistribution,
    this.recommendations,
  });
  
  /// Parse JSON response from API
  factory HeatmapResult.fromJson(Map<String, dynamic> json) {
    return HeatmapResult(
      success: json['success'] ?? true,
      metric: json['metric'] ?? '',
      mode: json['mode'] ?? 'pixelwise',
      indexUsed: json['index_used'] ?? '',
      minValue: (json['min_value'] as num?)?.toDouble() ?? 0.0,
      maxValue: (json['max_value'] as num?)?.toDouble() ?? 1.0,
      meanValue: (json['mean_value'] as num?)?.toDouble() ?? 0.5,
      imageBase64: json['image_base64'] ?? '',
      timestamp: json['timestamp'] ?? DateTime.now().toIso8601String(),
      imageDate: json['image_date'],
      imageSize: json['image_size'],
      bbox: (json['bbox'] as List?)?.map((e) => (e as num).toDouble()).toList(),
      colorbarBase64: json['colorbar_base64'],
      numPatches: json['num_patches'],
      healthSummary: json['health_summary'],
      level: json['level'],
      analysis: json['analysis'],
      detailedAnalysis: json['detailed_analysis'],
      stressScore: (json['stress_score'] as num?)?.toDouble(),
      clusterDistribution: json['cluster_distribution'],
      recommendations: (json['recommendations'] as List?)?.cast<String>(),
    );
  }

  // ---------------------------------------------------------------------------
  // Helper Methods
  // ---------------------------------------------------------------------------
  
  /// Convert base64 image to bytes for Image.memory widget
  List<int> get imageBytes => base64Decode(imageBase64);
  
  /// Get colorbar bytes (if available)
  List<int>? get colorbarBytes => colorbarBase64 != null ? base64Decode(colorbarBase64!) : null;
  
  /// Is this result from LLM analysis?
  bool get isLlmResult => mode == 'llm';
}
