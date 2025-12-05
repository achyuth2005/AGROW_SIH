import 'dart:convert';
import 'package:http/http.dart' as http;

/// Service to fetch heatmaps from the AGROW Heatmap HF Space (v3.0.0)
/// Supports pixel-wise indices and CNN+LLM risk analysis
class HeatmapService {
  static const String _baseUrl = 'https://aniket2006-heatmap.hf.space';
  
  /// Pixel-wise metrics (fast)
  static const List<String> pixelwiseMetrics = [
    'soil_moisture',
    'soil_organic_matter', 
    'soil_fertility',
    'soil_salinity',
    'greenness',
    'nitrogen_level',
    'photosynthetic_capacity',
  ];
  
  /// LLM metrics (CNN+Clustering+LLM)
  static const List<String> llmMetrics = [
    'pest_risk',
    'disease_risk',
    'nutrient_stress',
    'stress_zones',
  ];
  
  /// All supported metrics
  static List<String> get allMetrics => [...pixelwiseMetrics, ...llmMetrics];
  
  /// Legacy index mapping for backward compatibility
  static const Map<String, String> indexToMetric = {
    'SMI': 'soil_moisture',
    'SOMI': 'soil_organic_matter',
    'SFI': 'soil_fertility',
    'SASI': 'soil_salinity',
    'NDVI': 'greenness',
    'NDRE': 'nitrogen_level',
    'PRI': 'photosynthetic_capacity',
    'EVI': 'greenness',  // Map EVI to greenness
    'NDWI': 'soil_moisture',  // Map NDWI to soil_moisture
  };

  /// Fetch heatmap for a given location and metric
  static Future<HeatmapResult> fetchHeatmap({
    required double centerLat,
    required double centerLon,
    required double fieldSizeHectares,
    required String metric,
    double gaussianSigma = 1.5,
    bool showFieldBoundary = true,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/generate-heatmap'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'center_lat': centerLat,
          'center_lon': centerLon,
          'field_size_hectares': fieldSizeHectares,
          'metric': metric,
          'gaussian_sigma': gaussianSigma,
          'show_field_boundary': showFieldBoundary,
        }),
      ).timeout(const Duration(seconds: 90));  // Longer timeout for LLM

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
  
  /// Legacy method for backward compatibility - converts indexType to metric
  static Future<HeatmapResult> fetchHeatmapByIndex({
    required double centerLat,
    required double centerLon,
    double fieldSizeHectares = 10.0,
    String indexType = 'NDVI',
    double gaussianSigma = 1.5,
    bool showFieldBoundary = true,
  }) async {
    // Convert index to metric
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

  /// Get direct URL for heatmap image
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

/// Result model for heatmap API response
class HeatmapResult {
  final bool success;
  final String metric;
  final String mode;  // "pixelwise" or "llm"
  final String indexUsed;
  final double minValue;
  final double maxValue;
  final double meanValue;
  final String imageBase64;
  final String timestamp;
  final String? imageDate;
  final String? imageSize;
  
  // Pixel-wise specific
  final int? numPatches;
  final Map<String, dynamic>? healthSummary;
  
  // LLM specific
  final String? level;
  final String? analysis;
  final double? stressScore;
  final Map<String, dynamic>? clusterDistribution;
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
    this.numPatches,
    this.healthSummary,
    this.level,
    this.analysis,
    this.stressScore,
    this.clusterDistribution,
    this.recommendations,
  });
  
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
      numPatches: json['num_patches'],
      healthSummary: json['health_summary'],
      level: json['level'],
      analysis: json['analysis'],
      stressScore: (json['stress_score'] as num?)?.toDouble(),
      clusterDistribution: json['cluster_distribution'],
      recommendations: (json['recommendations'] as List?)?.cast<String>(),
    );
  }

  /// Get image bytes from base64
  List<int> get imageBytes => base64Decode(imageBase64);
  
  /// Is this a LLM-analyzed result?
  bool get isLlmResult => mode == 'llm';
}
