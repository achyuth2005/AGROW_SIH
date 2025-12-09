import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Service for Take Action LLM reasoning
class TakeActionService {
  static const String _baseUrl = 'https://aniket2006-heatmap.hf.space';

  /// Fetch comprehensive LLM reasoning for Take Action pages
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
      final requestBody = {
        'center_lat': centerLat,
        'center_lon': centerLon,
        'field_size_hectares': fieldSizeHectares,
        'category': category,
      };

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
      
      final response = await http.post(
        Uri.parse('$_baseUrl/take-action-reasoning'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 90));

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

/// Result model for Take Action reasoning
class TakeActionResult {
  final bool success;
  final String category;
  final List<ZoneInfo> highZones;
  final List<ZoneInfo> lowZones;
  final String recommendations;
  final List<String> riskSuggestions;
  final String detailedAnalysis;
  final double stressScore;
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

/// Zone info model for stress/performance zones
class ZoneInfo {
  final double lat;
  final double lon;
  final double score;
  final String label;
  final String action; // Zone-specific action recommendation
  final String severity; // High, Moderate, Low

  ZoneInfo({
    required this.lat,
    required this.lon,
    required this.score,
    required this.label,
    this.action = '',
    this.severity = 'Moderate',
  });

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
