import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class Sentinel2Service {
  static const String _baseUrl = 'https://aniket2006-agrow-sentinel2.hf.space';

  Future<Map<String, dynamic>> analyzeField({
    required double centerLat,
    required double centerLon,
    required String cropType,
    required String analysisDate,
    required double fieldSizeHectares,
    required Map<String, dynamic> farmerContext,
  }) async {
    final url = Uri.parse('$_baseUrl/analyze');
    
    final body = {
      'center_lat': centerLat,
      'center_lon': centerLon,
      'crop_type': cropType,
      'analysis_date': analysisDate,
      'field_size_hectares': fieldSizeHectares,
      'farmer_context': farmerContext,
    };

    if (kDebugMode) {
      print('Sentinel-2 Request: $url');
      print('Body: ${jsonEncode(body)}');
    }

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (kDebugMode) {
          print('Sentinel-2 Response: $data');
        }
        return data;
      } else {
        throw Exception('Failed to analyze field: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Sentinel-2 Error: $e');
      }
      throw Exception('Error connecting to Sentinel-2 service: $e');
    }
  }

  List<List<double>> _generateMockGrid() {
    return List.generate(10, (i) => List.generate(10, (j) => (0.3 + (i + j) * 0.03) % 1.0));
  }

  List<Map<String, dynamic>> _generateMockTrend() {
    final now = DateTime.now();
    return List.generate(7, (index) {
      return {
        'date': now.subtract(Duration(days: (6 - index) * 5)).toIso8601String(),
        'value': 0.4 + (index * 0.05) % 0.4,
      };
    });
  }
}
