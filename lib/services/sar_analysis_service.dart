/// ============================================================================
/// FILE: sar_analysis_service.dart
/// ============================================================================
/// PURPOSE: Communicates with the SAR (Synthetic Aperture Radar) analysis backend.
///          SAR uses radar waves to analyze soil and surface conditions,
///          working even through clouds and at night.
/// 
/// WHAT THIS FILE DOES:
///   - Sends field coordinates to the SAR analysis API
///   - Receives soil health data (moisture, salinity, roughness)
///   - Handles retry logic for resilient API communication
/// 
/// SAR vs OPTICAL SATELLITES:
///   ┌─────────────────┬─────────────────────┬─────────────────────┐
///   │ Feature         │ SAR (Radar)         │ Optical (Sentinel-2)│
///   ├─────────────────┼─────────────────────┼─────────────────────┤
///   │ Works at night  │ ✅ Yes              │ ❌ No               │
///   │ Works in clouds │ ✅ Yes              │ ❌ No               │
///   │ Sees soil       │ ✅ Excellent        │ ⚠️ Limited          │
///   │ Sees vegetation │ ⚠️ Limited          │ ✅ Excellent        │
///   └─────────────────┴─────────────────────┴─────────────────────┘
///   
///   By combining BOTH, we get complete field analysis!
/// 
/// DATA PROVIDED:
///   - Soil Moisture Index (SMI): How wet is the soil?
///   - Soil Salinity: Salt content affecting crop growth
///   - Surface Roughness: Tillage and field preparation
///   - Flooding Risk: Based on water accumulation patterns
/// 
/// DEPENDENCIES:
///   - http: Makes HTTP requests to backend API
///   - dart:convert: JSON encoding/decoding
/// ============================================================================

// For JSON encoding/decoding
import 'dart:convert';

// HTTP client for making API requests
import 'package:http/http.dart' as http;

// Flutter debugging utilities
import 'package:flutter/foundation.dart';

/// ============================================================================
/// SarAnalysisService CLASS
/// ============================================================================
/// Provides methods to analyze farm fields using SAR (radar) satellite imagery.
/// 
/// KEY FEATURE: RETRY LOGIC
///   Satellite analysis APIs can be slow or temporarily unavailable.
///   This service automatically retries failed requests with exponential backoff:
///   - 1st failure: Wait 2 seconds, try again
///   - 2nd failure: Wait 4 seconds, try again
///   - 3rd failure: Give up and report error
class SarAnalysisService {
  // ---------------------------------------------------------------------------
  // Configuration
  // ---------------------------------------------------------------------------
  
  /// URL of the SAR analysis API (Hugging Face Space)
  /// This backend processes radar data from Sentinel-1 satellite.
  static const String _baseUrl = "https://aniket2006-agrow-backend-v2.hf.space";
  
  /// Maximum number of times to retry a failed request
  /// After 3 failures, we give up and throw an error.
  static const int _maxRetries = 3;
  
  /// Initial wait time between retries (doubles each attempt)
  /// Attempt 1 failure: wait 2s, Attempt 2 failure: wait 4s
  static const Duration _initialBackoff = Duration(seconds: 2);
  
  /// Maximum time to wait for a response before timing out
  /// SAR analysis can take a while - we wait up to 2 minutes.
  static const Duration _requestTimeout = Duration(seconds: 120);

  // ===========================================================================
  // ANALYSIS METHODS
  // ===========================================================================
  
  /// -------------------------------------------------------------------------
  /// analyzeField() - Analyze soil conditions using SAR imagery
  /// -------------------------------------------------------------------------
  /// Sends field coordinates to the backend and receives soil health analysis.
  /// 
  /// PARAMETERS:
  ///   coordinates: List of 4 floats [lat_SW, lon_SW, lat_NE, lon_NE]
  ///                representing the bounding box of the field
  ///   date: Analysis date in "YYYY-MM-DD" format
  ///   cropType: What's planted - used for interpretation
  ///   context: Optional farmer/field context for AI analysis
  /// 
  /// RETURNS:
  ///   Map containing:
  ///   - Soil moisture data (grid and mean values)
  ///   - Soil salinity analysis
  ///   - Weather data integration
  ///   - AI-generated recommendations
  /// 
  /// EXAMPLE RESPONSE:
  ///   {
  ///     "soil_analysis": {
  ///       "moisture_level": "moderate",
  ///       "salinity_level": "low",
  ///       "recommendation": "Optimal moisture levels..."
  ///     },
  ///     "weather_data": {
  ///       "temperature": 28.5,
  ///       "humidity": 65
  ///     }
  ///   }
  /// 
  /// ERROR HANDLING:
  ///   - Automatically retries on network failures
  ///   - Handles rate limiting (429 responses) with longer waits
  ///   - Throws exception after all retries exhausted
  Future<Map<String, dynamic>> analyzeField({
    required List<double> coordinates,
    required String date,
    required String cropType,
    Map<String, dynamic>? context,
  }) async {
    // Track the last error for reporting if all retries fail
    Exception? lastError;
    
    // Retry loop - try up to _maxRetries times
    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        // Build the API URL
        final url = Uri.parse('$_baseUrl/analyze');
        
        // Build request body with field information
        // This format is expected by the agrow-backend-v2 API
        final body = {
          "coordinates": coordinates,    // Bounding box of field
          "date": date,                  // Analysis date
          "crop_type": cropType,         // For crop-specific insights
          "farmer_context": context,     // Additional context for AI
        };

        // Log the attempt (helpful for debugging)
        debugPrint("[SAR] Attempt $attempt/$_maxRetries: POST $url");
        
        // Make the POST request with timeout
        final response = await http.post(
          url,
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(body),
        ).timeout(_requestTimeout);

        debugPrint("[SAR] Response status: ${response.statusCode}");
        
        // Handle different response codes
        if (response.statusCode == 200) {
          // SUCCESS! Parse and return the data
          debugPrint("[SAR] Success!");
          return jsonDecode(response.body);
          
        } else if (response.statusCode == 429) {
          // RATE LIMITED - the API is receiving too many requests
          // Wait longer before next retry (double the normal backoff)
          debugPrint("[SAR] Rate limited, waiting...");
          await Future.delayed(_initialBackoff * attempt * 2);
          lastError = Exception("Rate limit reached");
          continue; // Try again
          
        } else {
          // OTHER ERROR - log and save for reporting
          lastError = Exception("API error: ${response.statusCode}");
          debugPrint("[SAR] Error: ${response.body}");
        }
        
      } catch (e) {
        // NETWORK/TIMEOUT ERROR - log and retry
        debugPrint("[SAR] Attempt $attempt failed: $e");
        lastError = e is Exception ? e : Exception(e.toString());
        
        // Wait before retrying (unless this was the last attempt)
        if (attempt < _maxRetries) {
          // Exponential backoff: 2s, 4s, 6s...
          await Future.delayed(_initialBackoff * attempt);
        }
      }
    }
    
    // All retries exhausted - throw the last error
    throw lastError ?? Exception("Failed after $_maxRetries attempts");
  }
}
