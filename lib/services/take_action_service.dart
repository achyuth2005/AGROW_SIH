/// ============================================================================
/// FILE: take_action_service.dart
/// ============================================================================
/// PURPOSE: Fetches AI-powered actionable recommendations for specific farming
///          issues (irrigation, pest management, nutrient deficiency, etc.).
///          Used by the "Take Action" screens to provide targeted advice.
/// 
/// WHAT THIS SERVICE DOES:
///   1. Sends field data and context to the Heatmap AI service
///   2. Receives zone-specific analysis (high/low stress areas)
///   3. Returns AI-generated recommendations and risk assessments
/// 
/// SUPPORTED CATEGORIES:
///   - "irrigation": Water management recommendations
///   - "nutrient": Fertilizer and nutrient deficiency advice
///   - "pest": Pest control suggestions
///   - "disease": Disease prevention and treatment
///   - "yield": Yield optimization tips
/// 
/// RESPONSE STRUCTURE:
///   - High/Low stress zones with coordinates and labels
///   - Overall stress score (0-1)
///   - Detailed AI analysis
///   - List of actionable recommendations
/// 
/// DEPENDENCIES:
///   - http: HTTP client for API requests
///   - dart:convert: JSON handling
/// ============================================================================

// JSON encoding/decoding
import 'dart:convert';

// Debug logging
import 'package:flutter/material.dart';

// HTTP client
import 'package:http/http.dart' as http;

/// ============================================================================
/// TakeActionService CLASS
/// ============================================================================
/// Provides AI-powered recommendations for the Take Action screens.
class TakeActionService {
  /// URL of the Heatmap service (which also handles Take Action reasoning)
  static const String _baseUrl = 'https://aniket2006-heatmap.hf.space';

  /// -------------------------------------------------------------------------
  /// fetchReasoning() - Get AI recommendations for a specific issue
  /// -------------------------------------------------------------------------
  /// Fetches comprehensive LLM reasoning for Take Action pages.
  /// 
  /// PARAMETERS:
  ///   centerLat/centerLon: Field center coordinates
  ///   fieldSizeHectares: Size of the field
  ///   category: Issue type ("irrigation", "nutrient", "pest", etc.)
  ///   stressClusters: Optional pre-computed stress zone data
  ///   indicesTimeseries: Optional historical index data for context
  ///   farmerProfile: Optional farmer context (experience, equipment, etc.)
  ///   weatherData: Optional weather data for more accurate recommendations
  /// 
  /// RETURNS:
  ///   TakeActionResult with zones, recommendations, and analysis
  ///   Returns null on error
  static Future<TakeActionResult?> fetchReasoning({
    required double centerLat,
    required double centerLon,
    required double fieldSizeHectares,
    required String category,
    Map<String, dynamic>? stressClusters,
    Map<String, dynamic>? indicesTimeseries,
    Map<String, dynamic>? farmerProfile,
    Map<String, dynamic>? weatherData,
  }) async {
    try {
      // Build request body with required parameters
      final requestBody = {
        'center_lat': centerLat,
        'center_lon': centerLon,
        'field_size_hectares': fieldSizeHectares,
        'category': category,
      };

      // Add optional context data if provided
      // More context = more accurate recommendations
      if (stressClusters != null) {
        requestBody['stress_clusters'] = stressClusters;
      }
      if (indicesTimeseries != null) {
        requestBody['indices_timeseries'] = indicesTimeseries;
      }
      if (farmerProfile != null) {
        requestBody['farmer_profile'] = farmerProfile;
      }
      if (weatherData != null) {
        requestBody['weather_data'] = weatherData;
      }

      debugPrint('[TakeAction] Fetching reasoning for $category');
      
      // Make API request
      final response = await http.post(
        Uri.parse('$_baseUrl/take-action-reasoning'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 90));  // Longer timeout for LLM

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('[TakeAction] Success: ${data['category']}');
        return TakeActionResult.fromJson(data);
      } else {
        debugPrint('[TakeAction] Error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('[TakeAction] Exception: $e');
      return null;
    }
  }
}

// =============================================================================
// DATA MODELS
// =============================================================================

/// ============================================================================
/// TakeActionResult - AI response for take action screens
/// ============================================================================
/// Contains zone analysis, recommendations, and stress assessment.
class TakeActionResult {
  /// Whether the API call was successful
  final bool success;
  
  /// Which category this response is for
  final String category;
  
  /// High stress/priority zones (need immediate attention)
  final List<ZoneInfo> highZones;
  
  /// Low stress zones (performing well)
  final List<ZoneInfo> lowZones;
  
  /// AI-generated recommendations text
  final String recommendations;
  
  /// List of specific risk-related suggestions
  final List<String> riskSuggestions;
  
  /// Extended AI analysis/reasoning
  final String detailedAnalysis;
  
  /// Overall stress score (0.0 = healthy, 1.0 = severe stress)
  final double stressScore;
  
  /// Distribution of zones by cluster type
  /// e.g., {"high_stress": 3, "moderate": 5, "low_stress": 12}
  final Map<String, int> clusterDistribution;

  TakeActionResult({
    required this.success,
    required this.category,
    required this.highZones,
    required this.lowZones,
    required this.recommendations,
    required this.riskSuggestions,
    required this.detailedAnalysis,
    required this.stressScore,
    required this.clusterDistribution,
  });

  /// Parse from JSON response
  factory TakeActionResult.fromJson(Map<String, dynamic> json) {
    return TakeActionResult(
      success: json['success'] ?? true,
      category: json['category'] ?? '',
      highZones: (json['high_zones'] as List?)
          ?.map((z) => ZoneInfo.fromJson(z))
          .toList() ?? [],
      lowZones: (json['low_zones'] as List?)
          ?.map((z) => ZoneInfo.fromJson(z))
          .toList() ?? [],
      recommendations: json['recommendations'] ?? '',
      riskSuggestions: (json['risk_suggestions'] as List?)?.cast<String>() ?? [],
      detailedAnalysis: json['detailed_analysis'] ?? '',
      stressScore: (json['stress_score'] as num?)?.toDouble() ?? 0.0,
      clusterDistribution: (json['cluster_distribution'] as Map?)
          ?.map((k, v) => MapEntry(k.toString(), (v as num).toInt())) ?? {},
    );
  }
}

/// ============================================================================
/// ZoneInfo - Information about a specific stress/performance zone
/// ============================================================================
/// Represents a specific area within the field with its status and action.
class ZoneInfo {
  /// Location coordinates of the zone center
  final double lat;
  final double lon;
  
  /// Stress/performance score for this zone
  final double score;
  
  /// Human-readable label (e.g., "Northeast corner")
  final String label;
  
  /// Recommended action for this specific zone
  final String action;
  
  /// Severity level: "High", "Moderate", "Low"
  final String severity;

  ZoneInfo({
    required this.lat,
    required this.lon,
    required this.score,
    required this.label,
    this.action = '',
    this.severity = 'Moderate',
  });

  /// Parse from JSON
  factory ZoneInfo.fromJson(Map<String, dynamic> json) {
    return ZoneInfo(
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lon: (json['lon'] as num?)?.toDouble() ?? 0.0,
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      label: json['label'] ?? '',
      action: json['action'] ?? '',
      severity: json['severity'] ?? 'Moderate',
    );
  }
}
