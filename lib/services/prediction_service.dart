import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Service for persistent prediction pipeline API
class PredictionService {
  static const String _baseUrl = 'https://Aniket2006-TimeSeries.hf.space';
  
  /// Start prediction for a field's polygon coordinates
  /// Returns job info including field_hash for tracking
  static Future<PredictResponse> startPrediction({
    required List<List<double>> polygonCoords,
    String? fieldName,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/predict'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'polygon_coords': polygonCoords,
          'field_name': fieldName,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return PredictResponse.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Prediction start error: $e');
    }
  }
  
  /// Check status of a prediction job
  static Future<StatusResponse> checkStatus(String fieldHash) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/predict/status/$fieldHash'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return StatusResponse.fromJson(jsonDecode(response.body));
      } else if (response.statusCode == 404) {
        throw Exception('Job not found');
      } else {
        throw Exception('Status check failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Status check error: $e');
    }
  }
  
  /// Get all prediction data for a completed field
  static Future<PredictionData> getData(String fieldHash) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/predict/data/$fieldHash'),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return PredictionData.fromJson(jsonDecode(response.body));
      } else if (response.statusCode == 404) {
        throw Exception('Data not found');
      } else if (response.statusCode == 400) {
        throw Exception('Job not complete');
      } else {
        throw Exception('Data fetch failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Data fetch error: $e');
    }
  }
  
  /// List all processed fields
  static Future<List<FieldInfo>> listFields() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/predict/fields'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['fields'] as List)
            .map((f) => FieldInfo.fromJson(f))
            .toList();
      } else {
        throw Exception('List fields failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('List fields error: $e');
    }
  }
  
  /// Poll status until complete or error
  static Stream<StatusResponse> pollStatus(String fieldHash, {
    Duration interval = const Duration(seconds: 5),
    Duration timeout = const Duration(minutes: 30),
  }) async* {
    final stopTime = DateTime.now().add(timeout);
    
    while (DateTime.now().isBefore(stopTime)) {
      try {
        final status = await checkStatus(fieldHash);
        yield status;
        
        if (status.status == 'complete' || status.status == 'error') {
          break;
        }
        
        await Future.delayed(interval);
      } catch (e) {
        debugPrint('Poll error: $e');
        await Future.delayed(interval);
      }
    }
  }
}

// ============================================================================
// MODELS
// ============================================================================

class PredictResponse {
  final String jobId;
  final String fieldHash;
  final String status;
  final String message;
  final String? createdAt;

  PredictResponse({
    required this.jobId,
    required this.fieldHash,
    required this.status,
    required this.message,
    this.createdAt,
  });

  factory PredictResponse.fromJson(Map<String, dynamic> json) {
    return PredictResponse(
      jobId: json['job_id'] ?? '',
      fieldHash: json['field_hash'] ?? '',
      status: json['status'] ?? 'unknown',
      message: json['message'] ?? '',
      createdAt: json['created_at'],
    );
  }
  
  bool get isComplete => status == 'complete';
  bool get isProcessing => status == 'processing';
}

class StatusResponse {
  final String fieldHash;
  final String status;
  final int progress;
  final String step;
  final String? message;
  final String? createdAt;
  final String? completedAt;

  StatusResponse({
    required this.fieldHash,
    required this.status,
    required this.progress,
    required this.step,
    this.message,
    this.createdAt,
    this.completedAt,
  });

  factory StatusResponse.fromJson(Map<String, dynamic> json) {
    return StatusResponse(
      fieldHash: json['field_hash'] ?? '',
      status: json['status'] ?? 'unknown',
      progress: json['progress'] ?? 0,
      step: json['step'] ?? 'Unknown',
      message: json['message'],
      createdAt: json['created_at'],
      completedAt: json['completed_at'],
    );
  }
  
  bool get isComplete => status == 'complete';
  bool get isError => status == 'error';
  bool get isProcessing => !isComplete && !isError;
}

class PredictionData {
  final bool success;
  final String fieldHash;
  final Map<String, dynamic> metadata;
  final List<Map<String, dynamic>>? sarData;
  final List<Map<String, dynamic>>? sentinel2Data;
  final List<Map<String, dynamic>>? sarPredictions;
  final List<Map<String, dynamic>>? sentinel2Predictions;
  final List<Map<String, dynamic>>? indices;

  PredictionData({
    required this.success,
    required this.fieldHash,
    required this.metadata,
    this.sarData,
    this.sentinel2Data,
    this.sarPredictions,
    this.sentinel2Predictions,
    this.indices,
  });

  factory PredictionData.fromJson(Map<String, dynamic> json) {
    return PredictionData(
      success: json['success'] ?? false,
      fieldHash: json['field_hash'] ?? '',
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
      sarData: (json['sar_data'] as List?)?.cast<Map<String, dynamic>>(),
      sentinel2Data: (json['sentinel2_data'] as List?)?.cast<Map<String, dynamic>>(),
      sarPredictions: (json['sar_predictions'] as List?)?.cast<Map<String, dynamic>>(),
      sentinel2Predictions: (json['sentinel2_predictions'] as List?)?.cast<Map<String, dynamic>>(),
      indices: (json['indices'] as List?)?.cast<Map<String, dynamic>>(),
    );
  }
  
  /// Get time series for a specific metric
  List<Map<String, dynamic>> getTimeSeriesFor(String metric) {
    List<Map<String, dynamic>> result = [];
    
    // Check SAR data
    if (metric == 'VV' || metric == 'VH') {
      final col = '${metric}_mean_dB';
      if (sarData != null) {
        for (final row in sarData!) {
          if (row.containsKey(col)) {
            result.add({'ds': row['ds'], 'value': row[col], 'type': 'historical'});
          }
        }
      }
      if (sarPredictions != null) {
        for (final row in sarPredictions!) {
          if (row.containsKey(col)) {
            result.add({'ds': row['ds'], 'value': row[col], 'type': 'forecast'});
          }
        }
      }
    } else {
      // Sentinel-2 data
      if (sentinel2Data != null) {
        for (final row in sentinel2Data!) {
          if (row.containsKey(metric)) {
            result.add({'ds': row['ds'], 'value': row[metric], 'type': 'historical'});
          }
        }
      }
      if (sentinel2Predictions != null) {
        for (final row in sentinel2Predictions!) {
          if (row.containsKey(metric)) {
            result.add({'ds': row['ds'], 'value': row[metric], 'type': 'forecast'});
          }
        }
      }
    }
    
    return result;
  }
  
  /// Get computed indices time series
  List<Map<String, dynamic>> getIndicesFor(String indexName) {
    if (indices == null) return [];
    
    return indices!
        .where((row) => row.containsKey(indexName))
        .map((row) => {
          'ds': row['ds'],
          'value': row[indexName],
          'type': row['type'] ?? 'historical'
        })
        .toList();
  }
}

class FieldInfo {
  final String hash;
  final String? fieldName;
  final String status;
  final String? createdAt;

  FieldInfo({
    required this.hash,
    this.fieldName,
    required this.status,
    this.createdAt,
  });

  factory FieldInfo.fromJson(Map<String, dynamic> json) {
    return FieldInfo(
      hash: json['hash'] ?? '',
      fieldName: json['field_name'],
      status: json['status'] ?? 'unknown',
      createdAt: json['created_at'],
    );
  }
}
