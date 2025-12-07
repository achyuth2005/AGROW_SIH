import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Service for AI chatbot with Supabase conversation storage
class ChatbotService {
  static const String _baseUrl = 'https://Aniket2006-Chatbot.hf.space';
  
  /// Send a message and get AI response
  static Future<ChatResponse> sendMessage({
    required String sessionId,
    required String message,
    String? userId,
    Map<String, dynamic>? fieldContext,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'session_id': sessionId,
          'message': message,
          'user_id': userId,
          'field_context': fieldContext,
        }),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        return ChatResponse.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Chat failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('ChatbotService error: $e');
      rethrow;
    }
  }
  
  /// Create a new chat session
  static Future<ChatSession> createSession({
    required String userId,
    String? title,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/session/new'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'title': title ?? 'New Conversation',
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return ChatSession.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Create session failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Create session error: $e');
      rethrow;
    }
  }
  
  /// Get conversation history for a session
  static Future<List<ChatMessage>> getHistory(String sessionId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/session/$sessionId/history'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['messages'] as List)
            .map((m) => ChatMessage.fromJson(m))
            .toList();
      } else {
        throw Exception('Get history failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Get history error: $e');
      rethrow;
    }
  }
  
  /// Get all sessions for a user
  static Future<List<ChatSessionSummary>> getSessions(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/sessions/$userId'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['sessions'] as List)
            .map((s) => ChatSessionSummary.fromJson(s))
            .toList();
      } else {
        throw Exception('Get sessions failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Get sessions error: $e');
      rethrow;
    }
  }
  
  /// Delete a session
  static Future<void> deleteSession(String sessionId) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/session/$sessionId'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('Delete session failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Delete session error: $e');
      rethrow;
    }
  }
  
  /// Check if service is available
  static Future<bool> isAvailable() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/health'),
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}

// ============================================================================
// MODELS
// ============================================================================

class ChatResponse {
  final String response;
  final String sessionId;
  final String messageId;
  final double confidence;
  final String? diagnosis;
  final List<String> suggestedFollowups;
  final String timestamp;
  final Map<String, dynamic>? reasoningTrace;

  ChatResponse({
    required this.response,
    required this.sessionId,
    required this.messageId,
    this.confidence = 0.0,
    this.diagnosis,
    this.suggestedFollowups = const [],
    required this.timestamp,
    this.reasoningTrace,
  });

  factory ChatResponse.fromJson(Map<String, dynamic> json) {
    // Handle both old (response as string) and new (response as object) formats
    String responseText = '';
    double confidence = 0.0;
    String? diagnosis;
    
    final rawResponse = json['response'];
    if (rawResponse is String) {
      // Old format: response is a plain string
      responseText = rawResponse;
    } else if (rawResponse is Map<String, dynamic>) {
      // New format: response is an object with message, confidence, diagnosis
      responseText = rawResponse['message'] ?? '';
      confidence = (rawResponse['confidence'] ?? 0.0).toDouble();
      diagnosis = rawResponse['diagnosis'];
    }
    
    return ChatResponse(
      response: responseText,
      sessionId: json['session_id'] ?? '',
      messageId: json['message_id'] ?? '',
      confidence: confidence,
      diagnosis: diagnosis,
      suggestedFollowups: List<String>.from(json['suggested_followups'] ?? []),
      timestamp: json['timestamp'] ?? '',
      reasoningTrace: json['reasoning_trace'],
    );
  }
}

class ChatSession {
  final String sessionId;
  final String title;
  final String createdAt;

  ChatSession({
    required this.sessionId,
    required this.title,
    required this.createdAt,
  });

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    return ChatSession(
      sessionId: json['session_id'] ?? '',
      title: json['title'] ?? 'New Conversation',
      createdAt: json['created_at'] ?? '',
    );
  }
}

class ChatMessage {
  final String id;
  final String role;
  final String content;
  final String createdAt;

  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] ?? '',
      role: json['role'] ?? 'user',
      content: json['content'] ?? '',
      createdAt: json['created_at'] ?? '',
    );
  }
  
  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';
}

class ChatSessionSummary {
  final String id;
  final String title;
  final String createdAt;
  final String updatedAt;
  final int messageCount;

  ChatSessionSummary({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.messageCount,
  });

  factory ChatSessionSummary.fromJson(Map<String, dynamic> json) {
    return ChatSessionSummary(
      id: json['id'] ?? '',
      title: json['title'] ?? 'Conversation',
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
      messageCount: json['message_count'] ?? 0,
    );
  }
}
