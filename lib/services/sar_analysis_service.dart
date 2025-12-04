import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class SarAnalysisService {
  // HF Space URL
  // Local testing - comment out for HF deployment
  // static const String _baseUrl = "http://localhost:7860";
  static const String _baseUrl = "https://aniket2006-agrow-backend-v2.hf.space"; 

  Future<Map<String, dynamic>> analyzeField({
    required List<double> coordinates,
    required String date,
    required String cropType,
    Map<String, dynamic>? context,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/analyze');
      
      final body = {
        "coordinates": coordinates,
        "date": date,
        "crop_type": cropType,
        "farmer_context": context,
      };

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception("Failed to analyze field: ${response.body}");
      }
    } catch (e) {
      debugPrint("Error in SAR Analysis: $e");
      rethrow;
    }
  }
}
