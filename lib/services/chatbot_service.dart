/// ============================================================================
/// FILE: chatbot_service.dart
/// ============================================================================
/// PURPOSE: Handles all communication with the AGROW AI Chatbot backend.
///          The chatbot helps farmers by answering questions about their crops,
///          providing personalized advice based on satellite data analysis.
/// 
/// WHAT THIS FILE DOES:
///   1. Sends user messages to the AI chatbot backend (Hugging Face)
///   2. Receives and parses AI responses
///   3. Manages chat sessions (create, load, delete conversations)
///   4. Supports voice input via audio transcription
///   5. Provides real-time streaming for "typewriter" effect
/// 
/// ARCHITECTURE:
///   This service communicates with TWO backend services:
///   - Chatbot API: Handles text conversations with the AI
///   - Voice API: Transcribes spoken audio to text
/// 
/// HYBRID CHATBOT EXPLAINED:
///   The AI uses a "Fast Lane" / "Deep Dive" system:
///   - FAST_LANE: Quick answers for simple questions (e.g., "What is NDVI?")
///   - DEEP_DIVE: Detailed analysis for complex queries (e.g., "How is my crop?")
/// 
/// DEPENDENCIES:
///   - http: Makes network requests to backend APIs
///   - dart:convert: Parses JSON responses
///   - dart:async: Handles asynchronous streaming
/// ============================================================================

// For JSON encoding/decoding (converting objects to/from text)
import 'dart:convert';

// For async streams (real-time message streaming)
import 'dart:async';

// Flutter debugging utilities
import 'package:flutter/foundation.dart';

// HTTP client for making API requests
import 'package:http/http.dart' as http;

/// ============================================================================
/// ChatbotService CLASS
/// ============================================================================
/// A static service class (no instance needed) that provides methods to:
/// - Send messages to the AI chatbot
/// - Transcribe voice recordings
/// - Manage conversation sessions
/// 
/// WHY STATIC?
///   All methods are static because:
///   - No state needs to be stored in this class
///   - Can be called from anywhere without creating an instance
///   - Example: ChatbotService.sendMessage(...) instead of chatbot.sendMessage(...)
class ChatbotService {
  // ---------------------------------------------------------------------------
  // Backend URLs
  // ---------------------------------------------------------------------------
  
  /// URL of the main chatbot API (hosted on Hugging Face Spaces)
  /// This is where messages are sent and AI responses come from.
  static const String _baseUrl = 'https://Aniket2006-Chatbot.hf.space';
  
  /// URL of the voice transcription API (separate Hugging Face Space)
  /// This service converts spoken audio into text.
  static const String _voiceUrl = 'https://aniket2006-agrow-voice.hf.space';

  // ===========================================================================
  // CORE MESSAGING METHODS
  // ===========================================================================
  
  /// -------------------------------------------------------------------------
  /// sendMessage() - Send a message to the AI and get a response
  /// -------------------------------------------------------------------------
  /// PARAMETERS:
  ///   sessionId: Unique ID for this conversation (groups messages together)
  ///   message: The text the user typed or spoke
  ///   userId: Optional - identifies the user for personalization
  ///   fieldContext: Optional - satellite data about user's farm for context
  /// 
  /// RETURNS:
  ///   ChatResponse containing the AI's reply, confidence score, and metadata
  /// 
  /// EXAMPLE:
  ///   final response = await ChatbotService.sendMessage(
  ///     sessionId: 'abc123',
  ///     message: 'How is my crop health?',
  ///     fieldContext: sarAnalysisData,
  ///   );
  ///   print(response.response); // "Based on the satellite analysis..."
  static Future<ChatResponse> sendMessage({
    required String sessionId,
    required String message,
    String? userId,
    Map<String, dynamic>? fieldContext,
  }) async {
    try {
      // Make POST request to chatbot API
      final response = await http.post(
        Uri.parse('$_baseUrl/chat'),  // Endpoint: /chat
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'session_id': sessionId,      // Which conversation this belongs to
          'message': message,           // User's question
          'user_id': userId,            // Who is asking
          'field_context': fieldContext, // Farm data for personalized advice
        }),
      ).timeout(const Duration(seconds: 60)); // Wait max 60 seconds

      // Check if request was successful (status code 200 = OK)
      if (response.statusCode == 200) {
        // Parse JSON response and convert to ChatResponse object
        return ChatResponse.fromJson(jsonDecode(response.body));
      } else {
        // Server returned an error
        throw Exception('Chat failed: ${response.statusCode}');
      }
    } catch (e) {
      // Log error and re-throw so the UI can handle it
      debugPrint('ChatbotService error: $e');
      rethrow;
    }
  }

  /// -------------------------------------------------------------------------
  /// transcribeAudio() - Convert voice recording to text
  /// -------------------------------------------------------------------------
  /// Takes an audio file path and sends it to the Voice API for transcription.
  /// 
  /// PARAMETERS:
  ///   filePath: Path to the audio file on the device (e.g., .m4a, .wav)
  /// 
  /// RETURNS:
  ///   The transcribed text string
  /// 
  /// HOW IT WORKS:
  ///   1. Creates a multipart form request (special format for file uploads)
  ///   2. Sends the audio file to the transcription server
  ///   3. Server uses AI (Whisper model) to convert speech to text
  ///   4. Returns the recognized text
  /// 
  /// EXAMPLE:
  ///   final text = await ChatbotService.transcribeAudio('/path/to/recording.m4a');
  ///   print(text); // "How is my corn crop doing?"
  static Future<String> transcribeAudio(String filePath) async {
    try {
      debugPrint('[VoiceService] Starting transcription for: $filePath');
      
      // Create a multipart request (needed for file uploads)
      var request = http.MultipartRequest('POST', Uri.parse('$_voiceUrl/transcribe'));
      
      // Attach the audio file to the request
      request.files.add(await http.MultipartFile.fromPath('file', filePath));
      
      debugPrint('[VoiceService] Sending request to $_voiceUrl/transcribe');
      
      // Send the request and wait for response
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('Transcription timeout after 30s'),
      );
      
      // Convert streamed response to regular response
      final response = await http.Response.fromStream(streamedResponse);
      
      debugPrint('[VoiceService] Response status: ${response.statusCode}');
      debugPrint('[VoiceService] Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        // Parse JSON and extract transcription
        final data = jsonDecode(response.body);
        return data['transcription'] ?? '';
      } else {
        throw Exception('Transcription failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('[VoiceService] Transcription error: $e');
      rethrow;
    }
  }

  // ===========================================================================
  // SESSION MANAGEMENT METHODS
  // ===========================================================================
  
  /// -------------------------------------------------------------------------
  /// createSession() - Start a new conversation
  /// -------------------------------------------------------------------------
  /// Creates a new chat session in the backend database.
  /// 
  /// PARAMETERS:
  ///   userId: The user who owns this conversation
  ///   title: Optional title for the conversation (default: "New Conversation")
  /// 
  /// RETURNS:
  ///   ChatSession with the new session's ID and metadata
  /// 
  /// WHY SESSIONS?
  ///   Sessions keep conversations organized:
  ///   - User can have multiple conversations
  ///   - Messages are grouped by session
  ///   - AI remembers context within a session
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
  
  /// -------------------------------------------------------------------------
  /// getHistory() - Get all messages from a conversation
  /// -------------------------------------------------------------------------
  /// Retrieves the full message history for a specific session.
  /// 
  /// PARAMETERS:
  ///   sessionId: The conversation to get history for
  /// 
  /// RETURNS:
  ///   List of all ChatMessages in this conversation (in order)
  static Future<List<ChatMessage>> getHistory(String sessionId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/session/$sessionId/history'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Convert each JSON message to ChatMessage object
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
  
  /// -------------------------------------------------------------------------
  /// getSessions() - Get all conversations for a user
  /// -------------------------------------------------------------------------
  /// Retrieves a list of all chat sessions belonging to a user.
  /// Used to show the conversation history drawer.
  /// 
  /// PARAMETERS:
  ///   userId: The user whose sessions to fetch
  /// 
  /// RETURNS:
  ///   List of ChatSessionSummary objects (title, date, message count)
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
  
  /// -------------------------------------------------------------------------
  /// deleteSession() - Delete a conversation
  /// -------------------------------------------------------------------------
  /// Permanently deletes a chat session and all its messages.
  /// 
  /// PARAMETERS:
  ///   sessionId: The session to delete
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
  
  /// -------------------------------------------------------------------------
  /// isAvailable() - Check if chatbot service is online
  /// -------------------------------------------------------------------------
  /// Makes a quick health check to see if the backend is responding.
  /// 
  /// RETURNS:
  ///   true if the service is available, false otherwise
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
  
  // ===========================================================================
  // STREAMING METHODS (Real-time typewriter effect)
  // ===========================================================================
  
  /// -------------------------------------------------------------------------
  /// streamMessage() - Get AI response in real-time chunks
  /// -------------------------------------------------------------------------
  /// Instead of waiting for the full response, this streams text as it's generated.
  /// Creates a "typewriter" effect where text appears word by word.
  /// 
  /// TECHNICAL DETAILS:
  ///   Uses SSE (Server-Sent Events) to receive data in real-time.
  ///   SSE is a standard for pushing updates from server to client.
  /// 
  /// PARAMETERS:
  ///   Same as sendMessage()
  /// 
  /// YIELDS:
  ///   ChatStreamEvent objects:
  ///   - metadata: Session info, confidence, routing mode
  ///   - chunk: A piece of the response text
  ///   - done: Final complete text
  ///   - error: If something went wrong
  /// 
  /// EXAMPLE:
  ///   await for (final event in ChatbotService.streamMessage(...)) {
  ///     if (event.type == ChatStreamEventType.chunk) {
  ///       displayText += event.text!; // Add each chunk to display
  ///     }
  ///   }
  static Stream<ChatStreamEvent> streamMessage({
    required String sessionId,
    required String message,
    String? userId,
    Map<String, dynamic>? fieldContext,
  }) async* {
    // Create HTTP client (we'll close it when done)
    final client = http.Client();
    
    try {
      // Build the streaming request
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
      
      // Send request and get streaming response
      final streamedResponse = await client.send(request).timeout(
        const Duration(seconds: 90),
      );
      
      // Check for errors
      if (streamedResponse.statusCode != 200) {
        yield ChatStreamEvent.error('Stream failed: ${streamedResponse.statusCode}');
        return;
      }
      
      // Buffer to accumulate incomplete SSE data
      String buffer = '';
      
      // Process the stream chunk by chunk
      await for (final chunk in streamedResponse.stream.transform(utf8.decoder)) {
        buffer += chunk;
        
        // SSE events are separated by double newlines
        while (buffer.contains('\n\n')) {
          final eventEnd = buffer.indexOf('\n\n');
          final eventData = buffer.substring(0, eventEnd);
          buffer = buffer.substring(eventEnd + 2);
          
          // SSE data lines start with "data: "
          if (eventData.startsWith('data: ')) {
            final jsonStr = eventData.substring(6);
            try {
              final data = jsonDecode(jsonStr) as Map<String, dynamic>;
              final type = data['type'] as String?;
              
              // Yield appropriate event based on type
              if (type == 'metadata') {
                // Initial metadata about the response
                yield ChatStreamEvent.metadata(
                  sessionId: data['session_id'] ?? sessionId,
                  messageId: data['message_id'] ?? '',
                  confidence: (data['confidence'] ?? 0.0).toDouble(),
                  diagnosis: data['diagnosis'],
                  routingMode: data['routing_mode'], // FAST_LANE or DEEP_DIVE
                  suggestedFollowups: List<String>.from(data['suggested_followups'] ?? []),
                );
              } else if (type == 'chunk') {
                // A piece of the response text
                yield ChatStreamEvent.chunk(data['text'] ?? '');
              } else if (type == 'done') {
                // Streaming complete, full text available
                yield ChatStreamEvent.done(data['full_text'] ?? '');
              } else if (type == 'error') {
                // Something went wrong
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
      // Always close the client to free resources
      client.close();
    }
  }
}

// =============================================================================
// DATA MODELS
// =============================================================================
// These classes represent the data structures returned by the API.
// They convert JSON responses into typed Dart objects for easier use.

/// ============================================================================
/// ChatResponse - The AI's response to a message
/// ============================================================================
/// Contains the full response text and metadata about how it was generated.
class ChatResponse {
  /// The actual text response from the AI
  final String response;
  
  /// Which conversation session this belongs to
  final String sessionId;
  
  /// Unique ID for this specific message
  final String messageId;
  
  /// How confident the AI is in its response (0.0 to 1.0)
  final double confidence;
  
  /// If the AI detected an issue, what is it?
  final String? diagnosis;
  
  /// Which processing path was used: "FAST_LANE" or "DEEP_DIVE"
  /// - FAST_LANE: Quick answer for simple questions
  /// - DEEP_DIVE: Detailed analysis using satellite data
  final String? routingMode;
  
  /// Suggested follow-up questions for the user
  final List<String> suggestedFollowups;
  
  /// When this response was generated
  final String timestamp;
  
  /// Internal debugging info about how the AI reasoned
  final Map<String, dynamic>? reasoningTrace;

  ChatResponse({
    required this.response,
    required this.sessionId,
    required this.messageId,
    this.confidence = 0.0,
    this.diagnosis,
    this.routingMode,
    this.suggestedFollowups = const [],
    required this.timestamp,
    this.reasoningTrace,
  });

  /// Was this a Fast Lane (quick) response?
  bool get isFastLane => routingMode == 'FAST_LANE';
  
  /// Was this a Deep Dive (detailed) response?
  bool get isDeepDive => routingMode == 'DEEP_DIVE';

  /// Parse JSON from API into ChatResponse object
  factory ChatResponse.fromJson(Map<String, dynamic> json) {
    // API can return response in two formats - handle both
    String responseText = '';
    double confidence = 0.0;
    String? diagnosis;
    
    final rawResponse = json['response'];
    if (rawResponse is String) {
      // Old format: response is just a string
      responseText = rawResponse;
    } else if (rawResponse is Map<String, dynamic>) {
      // New format: response is an object with multiple fields
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
      routingMode: json['routing_mode'],
      suggestedFollowups: List<String>.from(json['suggested_followups'] ?? []),
      timestamp: json['timestamp'] ?? '',
      reasoningTrace: json['reasoning_trace'],
    );
  }
}

/// ============================================================================
/// ChatSession - A conversation container
/// ============================================================================
/// Represents a single conversation thread between user and AI.
class ChatSession {
  final String sessionId;  // Unique identifier
  final String title;      // Display name (e.g., "Crop Health Discussion")
  final String createdAt;  // When the session was started

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

/// ============================================================================
/// ChatMessage - A single message in a conversation
/// ============================================================================
/// Represents either a user message or an AI response.
class ChatMessage {
  final String id;         // Unique message ID
  final String role;       // "user" or "assistant"
  final String content;    // The message text
  final String createdAt;  // Timestamp

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
  
  /// Is this message from the user?
  bool get isUser => role == 'user';
  
  /// Is this message from the AI assistant?
  bool get isAssistant => role == 'assistant';
}

/// ============================================================================
/// ChatSessionSummary - Brief info about a conversation
/// ============================================================================
/// Used in the chat history drawer to show past conversations.
class ChatSessionSummary {
  final String id;           // Session ID
  final String title;        // Display title
  final String createdAt;    // When started
  final String updatedAt;    // Last activity
  final int messageCount;    // How many messages

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

/// ============================================================================
/// ChatStreamEventType - Types of streaming events
/// ============================================================================
/// When streaming a response, we receive different types of events.
enum ChatStreamEventType { 
  metadata,  // Initial info about the response
  chunk,     // A piece of text
  done,      // Streaming complete
  error      // Something went wrong
}

/// ============================================================================
/// ChatStreamEvent - A single event in the streaming response
/// ============================================================================
/// Used to build the "typewriter" effect in the UI.
class ChatStreamEvent {
  final ChatStreamEventType type;
  final String? text;               // For chunk events
  final String? fullText;           // For done events
  final String? error;              // For error events
  final String? sessionId;          // For metadata events
  final String? messageId;          // For metadata events
  final double? confidence;         // For metadata events
  final String? diagnosis;          // For metadata events
  final String? routingMode;        // "FAST_LANE" or "DEEP_DIVE"
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
    this.routingMode,
    this.suggestedFollowups,
  });

  /// Was this a Fast Lane response?
  bool get isFastLane => routingMode == 'FAST_LANE';
  
  /// Was this a Deep Dive response?
  bool get isDeepDive => routingMode == 'DEEP_DIVE';

  /// Create a metadata event (response info)
  factory ChatStreamEvent.metadata({
    required String sessionId,
    required String messageId,
    required double confidence,
    String? diagnosis,
    String? routingMode,
    List<String>? suggestedFollowups,
  }) {
    return ChatStreamEvent._(
      type: ChatStreamEventType.metadata,
      sessionId: sessionId,
      messageId: messageId,
      confidence: confidence,
      diagnosis: diagnosis,
      routingMode: routingMode,
      suggestedFollowups: suggestedFollowups,
    );
  }

  /// Create a text chunk event
  factory ChatStreamEvent.chunk(String text) {
    return ChatStreamEvent._(type: ChatStreamEventType.chunk, text: text);
  }

  /// Create a "streaming done" event with full text
  factory ChatStreamEvent.done(String fullText) {
    return ChatStreamEvent._(type: ChatStreamEventType.done, fullText: fullText);
  }

  /// Create an error event
  factory ChatStreamEvent.error(String error) {
    return ChatStreamEvent._(type: ChatStreamEventType.error, error: error);
  }
}
