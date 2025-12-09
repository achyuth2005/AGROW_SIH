import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class SarAnalysisService {
  // Original working backend URL
  static const String _baseUrl = "https://aniket2006-agrow-backend-v2.hf.space";
  
  // Retry configuration
  static const int _maxRetries = 3;
  static const Duration _initialBackoff = Duration(seconds: 2);
  static const Duration _requestTimeout = Duration(seconds: 120);

  Future<Map<String, dynamic>> analyzeField({
    required List<double> coordinates,
    required String date,
    required String cropType,
    Map<String, dynamic>? context,
  }) async {
    Exception? lastError;
    
    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        final url = Uri.parse('$_baseUrl/analyze');
        
        // Original request format expected by agrow-backend-v2
        final body = {
          "coordinates": coordinates,
          "date": date,
          "crop_type": cropType,
          "farmer_context": context,
        };

        debugPrint("[SAR] Attempt $attempt/$_maxRetries: POST $url");
        
        final response = await http.post(
          url,
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(body),
        ).timeout(_requestTimeout);

        debugPrint("[SAR] Response status: ${response.statusCode}");
        
        if (response.statusCode == 200) {
          debugPrint("[SAR] Success!");
          return jsonDecode(response.body);
        } else if (response.statusCode == 429) {
          debugPrint("[SAR] Rate limited, waiting...");
          await Future.delayed(_initialBackoff * attempt * 2);
          lastError = Exception("Rate limit reached");
          continue;
        } else {
          lastError = Exception("API error: ${response.statusCode}");
          debugPrint("[SAR] Error: ${response.body}");
        }
      } catch (e) {
        debugPrint("[SAR] Attempt $attempt failed: $e");
        lastError = e is Exception ? e : Exception(e.toString());
        
        if (attempt < _maxRetries) {
          await Future.delayed(_initialBackoff * attempt);
        }
      }
    }
    
    throw lastError ?? Exception("Failed after $_maxRetries attempts");
  }
}
