import 'dart:convert';
import 'dart:async';
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
  
  /// Stream a message response via SSE for typewriter effect
  /// Returns a Stream of ChatStreamEvent (metadata, chunks, done, error)
  static Stream<ChatStreamEvent> streamMessage({
    required String sessionId,
    required String message,
    String? userId,
    Map<String, dynamic>? fieldContext,
  }) async* {
    final client = http.Client();
    
    try {
      final request = http.Request(
        'POST',
        Uri.parse('$_baseUrl/chat/stream'),
      );
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode({
        'session_id': sessionId,
        'message': message,
        'user_id': userId,
        'field_context': fieldContext,
      });
      
      final streamedResponse = await client.send(request).timeout(
        const Duration(seconds: 90),
      );
      
      if (streamedResponse.statusCode != 200) {
        yield ChatStreamEvent.error('Stream failed: ${streamedResponse.statusCode}');
        return;
      }
      
      // Buffer for incomplete SSE lines
      String buffer = '';
      
      await for (final chunk in streamedResponse.stream.transform(utf8.decoder)) {
        buffer += chunk;
        
        // Process complete lines
        while (buffer.contains('\n\n')) {
          final eventEnd = buffer.indexOf('\n\n');
          final eventData = buffer.substring(0, eventEnd);
          buffer = buffer.substring(eventEnd + 2);
          
          // Parse SSE data line
          if (eventData.startsWith('data: ')) {
            final jsonStr = eventData.substring(6);
            try {
              final data = jsonDecode(jsonStr) as Map<String, dynamic>;
              final type = data['type'] as String?;
              
              if (type == 'metadata') {
                yield ChatStreamEvent.metadata(
                  sessionId: data['session_id'] ?? sessionId,
                  messageId: data['message_id'] ?? '',
                  confidence: (data['confidence'] ?? 0.0).toDouble(),
                  diagnosis: data['diagnosis'],
                  suggestedFollowups: List<String>.from(data['suggested_followups'] ?? []),
                );
              } else if (type == 'chunk') {
                yield ChatStreamEvent.chunk(data['text'] ?? '');
              } else if (type == 'done') {
                yield ChatStreamEvent.done(data['full_text'] ?? '');
              } else if (type == 'error') {
                yield ChatStreamEvent.error(data['message'] ?? 'Unknown error');
              }
            } catch (e) {
              debugPrint('SSE parse error: $e for data: $jsonStr');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Stream error: $e');
      yield ChatStreamEvent.error(e.toString());
    } finally {
      client.close();
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

/// Event types for streaming chat responses
enum ChatStreamEventType { metadata, chunk, done, error }

/// Streaming chat event for SSE responses
class ChatStreamEvent {
  final ChatStreamEventType type;
  final String? text;
  final String? fullText;
  final String? error;
  final String? sessionId;
  final String? messageId;
  final double? confidence;
  final String? diagnosis;
  final List<String>? suggestedFollowups;

  ChatStreamEvent._({
    required this.type,
    this.text,
    this.fullText,
    this.error,
    this.sessionId,
    this.messageId,
    this.confidence,
    this.diagnosis,
    this.suggestedFollowups,
  });

  /// Metadata event with response info
  factory ChatStreamEvent.metadata({
    required String sessionId,
    required String messageId,
    required double confidence,
    String? diagnosis,
    List<String>? suggestedFollowups,
  }) {
    return ChatStreamEvent._(
      type: ChatStreamEventType.metadata,
      sessionId: sessionId,
      messageId: messageId,
      confidence: confidence,
      diagnosis: diagnosis,
      suggestedFollowups: suggestedFollowups,
    );
  }

  /// Text chunk event
  factory ChatStreamEvent.chunk(String text) {
    return ChatStreamEvent._(type: ChatStreamEventType.chunk, text: text);
  }

  /// Stream complete event
  factory ChatStreamEvent.done(String fullText) {
    return ChatStreamEvent._(type: ChatStreamEventType.done, fullText: fullText);
  }

  /// Error event
  factory ChatStreamEvent.error(String error) {
    return ChatStreamEvent._(type: ChatStreamEventType.error, error: error);
  }
}
