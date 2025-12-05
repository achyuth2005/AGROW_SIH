import 'dart:convert';
import 'package:http/http.dart' as http;

/// Service to fetch heatmap images from the AGROW Heatmap HF Space
class HeatmapService {
  static const String _baseUrl = 'https://aniket2006-heatmap.hf.space';
  
  /// Supported vegetation indices
  static const List<String> supportedIndices = ['NDVI', 'EVI', 'NDWI', 'NDRE', 'SMI'];

  /// Fetch heatmap data for a given location and index type
  /// Returns a HeatmapResult with base64 image and statistics
  static Future<HeatmapResult> fetchHeatmap({
    required double centerLat,
    required double centerLon,
    double fieldSizeHectares = 10.0,
    String indexType = 'NDVI',
    double gaussianSigma = 1.5,  // Gaussian smoothing (0 = no smoothing)
    bool showFieldBoundary = true,  // Show field boundary overlay
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/generate-heatmap'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'center_lat': centerLat,
          'center_lon': centerLon,
          'field_size_hectares': fieldSizeHectares,
          'index_type': indexType,
          'gaussian_sigma': gaussianSigma,
          'show_field_boundary': showFieldBoundary,
        }),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return HeatmapResult(
          success: data['success'] ?? true,
          indexType: data['index_type'] ?? indexType,
          minValue: (data['min_value'] as num?)?.toDouble() ?? 0.0,
          maxValue: (data['max_value'] as num?)?.toDouble() ?? 1.0,
          meanValue: (data['mean_value'] as num?)?.toDouble() ?? 0.5,
          imageBase64: data['image_base64'] ?? '',
          timestamp: data['timestamp'] ?? DateTime.now().toIso8601String(),
        );
      } else {
        throw Exception('Failed to fetch heatmap: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error connecting to Heatmap service: $e');
    }
  }

  /// Get direct URL for heatmap image (for Image.network)
  static String getHeatmapImageUrl({
    required double centerLat,
    required double centerLon,
    double fieldSizeHectares = 10.0,
    String indexType = 'NDVI',
  }) {
    return '$_baseUrl/generate-heatmap-image'
        '?center_lat=$centerLat'
        '&center_lon=$centerLon'
        '&field_size_hectares=$fieldSizeHectares'
        '&index_type=$indexType';
  }
}

/// Result model for heatmap API response
class HeatmapResult {
  final bool success;
  final String indexType;
  final double minValue;
  final double maxValue;
  final double meanValue;
  final String imageBase64;
  final String timestamp;

  HeatmapResult({
    required this.success,
    required this.indexType,
    required this.minValue,
    required this.maxValue,
    required this.meanValue,
    required this.imageBase64,
    required this.timestamp,
  });

  /// Get image bytes from base64
  List<int> get imageBytes => base64Decode(imageBase64);
}
