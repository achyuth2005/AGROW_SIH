/// ============================================================================
/// FILE: sentinel2_service.dart
/// ============================================================================
/// PURPOSE: Communicates with the Sentinel-2 satellite analysis backend.
///          Sentinel-2 is a European Space Agency satellite that captures
///          multi-spectral images of Earth - perfect for vegetation analysis.
/// 
/// WHAT THIS FILE DOES:
///   - Sends field coordinates to the Sentinel-2 analysis API
///   - Receives vegetation indices (NDVI, EVI) and crop health data
///   - Provides AI-generated insights about crop conditions
/// 
/// SATELLITE DATA EXPLAINED:
///   Sentinel-2 captures light in 13 different spectral bands:
///   - Visible light (red, green, blue) - what our eyes see
///   - Near-infrared (NIR) - healthy plants reflect strongly
///   - Short-wave infrared (SWIR) - moisture detection
///   
///   By combining these bands, we calculate vegetation indices:
///   - NDVI: Normalized Difference Vegetation Index (plant health)
///   - EVI: Enhanced Vegetation Index (biomass)
///   - NDRE: Nitrogen status
/// 
/// DEPENDENCIES:
///   - http: Makes HTTP requests to the backend API
///   - dart:convert: JSON encoding/decoding
/// ============================================================================

// For JSON encoding/decoding
import 'dart:convert';

// HTTP client for making API requests
import 'package:http/http.dart' as http;

// Flutter debugging utilities
import 'package:flutter/foundation.dart';

/// ============================================================================
/// Sentinel2Service CLASS
/// ============================================================================
/// Provides methods to analyze farm fields using Sentinel-2 satellite imagery.
/// 
/// THE ANALYSIS PIPELINE:
///   1. App sends field coordinates to Hugging Face Space
///   2. Backend queries Sentinel Hub API for latest imagery
///   3. Backend calculates vegetation indices (NDVI, EVI, etc.)
///   4. LLM generates human-readable insights
///   5. Results returned to app for display
class Sentinel2Service {
  // ---------------------------------------------------------------------------
  // Configuration
  // ---------------------------------------------------------------------------
  
  /// URL of the Sentinel-2 analysis API (Hugging Face Space)
  /// This backend handles all satellite data processing.
  static const String _baseUrl = 'https://aniket2006-agrow-sentinel2.hf.space';

  // ===========================================================================
  // ANALYSIS METHODS
  // ===========================================================================
  
  /// -------------------------------------------------------------------------
  /// analyzeField() - Analyze a farm field using Sentinel-2 imagery
  /// -------------------------------------------------------------------------
  /// Sends field information to the backend and receives crop health analysis.
  /// 
  /// PARAMETERS:
  ///   centerLat: Latitude of field center (e.g., 19.0760)
  ///   centerLon: Longitude of field center (e.g., 72.8777)
  ///   cropType: What's planted - "wheat", "rice", "cotton", etc.
  ///   analysisDate: Date to analyze (usually today or recent past)
  ///   fieldSizeHectares: Size of the field for scaling calculations
  ///   farmerContext: Additional info (soil type, irrigation, etc.)
  /// 
  /// RETURNS:
  ///   Map containing:
  ///   - Vegetation indices (NDVI values for grid squares)
  ///   - Health status (good/moderate/stressed)
  ///   - AI-generated recommendations
  ///   - Trend data (how health changed over time)
  /// 
  /// EXAMPLE RESPONSE:
  ///   {
  ///     "ndvi_grid": [[0.6, 0.7], [0.5, 0.65]],  // 2x2 grid of NDVI values
  ///     "mean_ndvi": 0.61,
  ///     "health_status": "moderate",
  ///     "recommendations": "Consider increasing nitrogen...",
  ///     "trend": [...] // Last 30 days of NDVI
  ///   }
  Future<Map<String, dynamic>> analyzeField({
    required double centerLat,
    required double centerLon,
    required String cropType,
    required String analysisDate,
    required double fieldSizeHectares,
    required Map<String, dynamic> farmerContext,
  }) async {
    // Build the API URL
    final url = Uri.parse('$_baseUrl/analyze');
    
    // Build request body with all field information
    final body = {
      'center_lat': centerLat,           // Field center latitude
      'center_lon': centerLon,           // Field center longitude
      'crop_type': cropType,             // What crop is growing
      'analysis_date': analysisDate,     // When to analyze
      'field_size_hectares': fieldSizeHectares, // Field size for calculations
      'farmer_context': farmerContext,   // Extra context for AI
    };

    // Debug logging (only in development builds)
    if (kDebugMode) {
      print('Sentinel-2 Request: $url');
      print('Body: ${jsonEncode(body)}');
    }

    try {
      // Make POST request to the analysis API
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      // Check if request was successful
      if (response.statusCode == 200) {
        // Parse JSON response
        final data = jsonDecode(response.body);
        
        if (kDebugMode) {
          print('Sentinel-2 Response: $data');
        }
        
        return data;
      } else {
        // Server returned an error
        throw Exception('Failed to analyze field: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Sentinel-2 Error: $e');
      }
      throw Exception('Error connecting to Sentinel-2 service: $e');
    }
  }

  // ===========================================================================
  // MOCK DATA GENERATORS (for testing/fallback)
  // ===========================================================================
  
  /// -------------------------------------------------------------------------
  /// _generateMockGrid() - Create fake NDVI grid for testing
  /// -------------------------------------------------------------------------
  /// Generates a 10x10 grid of realistic-looking NDVI values.
  /// NDVI ranges from -1 to 1, with healthy vegetation around 0.6-0.8.
  /// 
  /// USED WHEN:
  ///   - Backend is unavailable
  ///   - Running in demo mode
  ///   - Testing UI without network
  List<List<double>> _generateMockGrid() {
    return List.generate(10, (i) => 
      List.generate(10, (j) => 
        (0.3 + (i + j) * 0.03) % 1.0  // Values between 0.3 and 1.0
      )
    );
  }

  /// -------------------------------------------------------------------------
  /// _generateMockTrend() - Create fake time series data for testing
  /// -------------------------------------------------------------------------
  /// Generates 7 data points representing NDVI over 35 days.
  /// Shows a slight upward trend (typical for growing season).
  List<Map<String, dynamic>> _generateMockTrend() {
    final now = DateTime.now();
    return List.generate(7, (index) {
      return {
        // Each point is 5 days apart, going back 30 days
        'date': now.subtract(Duration(days: (6 - index) * 5)).toIso8601String(),
        // NDVI values with slight upward trend
        'value': 0.4 + (index * 0.05) % 0.4,
      };
    });
  }
}
