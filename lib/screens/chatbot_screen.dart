import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../services/chatbot_service.dart';
import 'chat_history_drawer.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, dynamic>> _messages = []; 
  final ScrollController _scrollController = ScrollController();
  String _userName = "User";
  String? _sessionId;
  String? _userId;
  bool _isLoading = false;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadUserInfo();
    await _initSession();
    setState(() => _isInitializing = false);
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    // Use Firebase Auth (your app's auth system) instead of Supabase Auth
    final user = FirebaseAuth.instance.currentUser;
    setState(() {
      _userName = prefs.getString('user_full_name') ?? user?.displayName ?? "User";
      _userId = user?.uid;
    });
  }

  Future<void> _initSession() async {
    if (_userId == null) {
      // Generate anonymous ID if not logged in
      _userId = 'anon_${DateTime.now().millisecondsSinceEpoch}';
    }
    
    try {
      // Create new session
      final session = await ChatbotService.createSession(
        userId: _userId!,
        title: 'Chat ${DateTime.now().toString().split(' ')[0]}',
      );
      setState(() {
        _sessionId = session.sessionId;
      });
    } catch (e) {
      debugPrint('Failed to create session: $e');
      // Use local session ID as fallback
      setState(() {
        _sessionId = 'local_${DateTime.now().millisecondsSinceEpoch}';
      });
    }
  }

  Future<void> _loadSession(String sessionId) async {
    setState(() {
      _isLoading = true;
      _messages.clear();
    });

    try {
      final history = await ChatbotService.getHistory(sessionId);
      setState(() {
        _sessionId = sessionId;
        _messages.addAll(history.map((msg) => {
          'text': msg.content,
          'isUser': msg.isUser,
          'id': msg.id,
        }));
      });
    } catch (e) {
      debugPrint('Failed to load history: $e');
    } finally {
      setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  void _sendMessage() async {
    if (_controller.text.trim().isEmpty || _sessionId == null) return;
    
    final userText = _controller.text.trim();
    setState(() {
      _messages.add({"text": userText, "isUser": true});
      _controller.clear();
      _isLoading = true;
      // Add empty AI message placeholder for streaming
      _messages.add({
        "text": "",
        "isUser": false,
        "isStreaming": true,
      });
    });
    _scrollToBottom();

    try {
      // Get current field context if available
      final prefs = await SharedPreferences.getInstance();
      final fieldContext = <String, dynamic>{};
      
      // Add any available context from preferences or state
      final fieldName = prefs.getString('current_field_name');
      if (fieldName != null) fieldContext['field_name'] = fieldName;
      
      // Use streaming API for typewriter effect
      String? messageId;
      double? confidence;
      String? diagnosis;
      List<String>? suggestedFollowups;
      
      await for (final event in ChatbotService.streamMessage(
        sessionId: _sessionId!,
        message: userText,
        userId: _userId,
        fieldContext: fieldContext.isNotEmpty ? fieldContext : null,
      )) {
        if (!mounted) break;
        
        switch (event.type) {
          case ChatStreamEventType.metadata:
            // Store metadata for final message
            messageId = event.messageId;
            confidence = event.confidence;
            diagnosis = event.diagnosis;
            suggestedFollowups = event.suggestedFollowups;
            break;
            
          case ChatStreamEventType.chunk:
            // Append chunk to the streaming message
            setState(() {
              final lastIndex = _messages.length - 1;
              _messages[lastIndex] = {
                ..._messages[lastIndex],
                "text": (_messages[lastIndex]["text"] as String) + (event.text ?? ""),
              };
            });
            _scrollToBottom();
            break;
            
          case ChatStreamEventType.done:
            // Finalize the message with metadata
            setState(() {
              final lastIndex = _messages.length - 1;
              _messages[lastIndex] = {
                "text": event.fullText ?? _messages[lastIndex]["text"],
                "isUser": false,
                "isStreaming": false,
                "id": messageId,
                "confidence": confidence,
                "diagnosis": diagnosis,
                "suggestedFollowups": suggestedFollowups,
              };
              _isLoading = false;
            });
            break;
            
          case ChatStreamEventType.error:
            setState(() {
              final lastIndex = _messages.length - 1;
              _messages[lastIndex] = {
                "text": event.error ?? "An error occurred. Please try again.",
                "isUser": false,
                "isError": true,
                "isStreaming": false,
              };
              _isLoading = false;
            });
            break;
        }
      }
      
      // Ensure loading state is cleared
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          // Update the streaming message to show error
          if (_messages.isNotEmpty && _messages.last["isStreaming"] == true) {
            final lastIndex = _messages.length - 1;
            _messages[lastIndex] = {
              "text": "I'm having trouble connecting. Please try again.",
              "isUser": false,
              "isError": true,
              "isStreaming": false,
            };
          } else {
            _messages.add({
              "text": "I'm having trouble connecting. Please try again.",
              "isUser": false,
              "isError": true,
            });
          }
          _isLoading = false;
        });
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _startNewChat() async {
    setState(() {
      _messages.clear();
      _isLoading = true;
    });
    
    try {
      final session = await ChatbotService.createSession(
        userId: _userId!,
        title: 'Chat ${DateTime.now().toString().split(' ')[0]}',
      );
      setState(() {
        _sessionId = session.sessionId;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F5F3),
      drawer: ChatHistoryDrawer(
        userId: _userId,
        onSessionSelected: _loadSession,
        onNewChat: _startNewChat,
      ),
      body: Builder(
        builder: (context) => Stack(
          children: [
            // Background Image (Header)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Image.asset(
                'assets/backsmall.png',
                fit: BoxFit.fitWidth,
                alignment: Alignment.topCenter,
              ),
            ),

            // Content
            Column(
              children: [
                // Custom AppBar
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 0.0),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.menu, color: Colors.white),
                          onPressed: () {
                            Scaffold.of(context).openDrawer();
                          },
                        ),
                        const Expanded(
                          child: Text(
                            "AGROW AI",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_comment_outlined, color: Colors.white),
                          onPressed: _startNewChat,
                        ),
                      ],
                    ),
                  ),
                ),

                // Chat Area
                Expanded(
                  child: _isInitializing
                      ? const Center(child: CircularProgressIndicator())
                      : _messages.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.agriculture,
                                    size: 48,
                                    color: Color(0xFF167339),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    "Hi $_userName!",
                                    style: const TextStyle(
                                      fontSize: 18,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    "How can I help you today?",
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  // Quick suggestions
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    alignment: WrapAlignment.center,
                                    children: [
                                      _buildSuggestionChip("What's my crop health?"),
                                      _buildSuggestionChip("Irrigation advice"),
                                      _buildSuggestionChip("Pest management tips"),
                                    ],
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.fromLTRB(16, 40, 16, 20),
                              itemCount: _messages.length + (_isLoading ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index == _messages.length && _isLoading) {
                                  return _buildTypingIndicator();
                                }
                                final msg = _messages[index];
                                final isUser = msg['isUser'] as bool;
                                final isError = msg['isError'] == true;
                                return _buildMessageBubble(msg, isUser, isError);
                              },
                            ),
                ),

                // Input Area
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.transparent, 
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _controller,
                            enabled: !_isLoading,
                            decoration: InputDecoration(
                              hintText: _isLoading ? "Thinking..." : "Ask anything...",
                              hintStyle: const TextStyle(color: Colors.grey),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              suffixIcon: const Icon(Icons.mic, color: Color(0xFF0F3C33)),
                            ),
                            onSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: _isLoading ? null : _sendMessage,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _isLoading ? Colors.grey.shade200 : Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.send,
                            color: _isLoading ? Colors.grey : const Color(0xFF0F3C33),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Bottom Nav Bar
                Container(
                  height: 80,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildNavItem(Icons.home_outlined, false),
                      _buildNavItem(Icons.grid_view, false),
                      _buildNavItem(Icons.calendar_today_outlined, false),
                      _buildNavItem(Icons.chat_bubble, true),
                      _buildNavItem(Icons.person_outline, false),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg, bool isUser, bool isError) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isUser 
              ? const Color(0xFF0F3C33) 
              : isError 
                  ? Colors.red.shade50 
                  : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: isUser ? const Radius.circular(16) : Radius.zero,
            topRight: isUser ? Radius.zero : const Radius.circular(16),
            bottomLeft: const Radius.circular(16),
            bottomRight: const Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Use Markdown for AI responses, plain Text for user messages
            if (isUser)
              Text(
                msg['text'],
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              )
            else
              MarkdownBody(
                data: msg['text'],
                styleSheet: MarkdownStyleSheet(
                  p: TextStyle(
                    color: isError ? Colors.red.shade700 : Colors.black87,
                    fontSize: 16,
                  ),
                  strong: TextStyle(
                    color: isError ? Colors.red.shade700 : Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  em: TextStyle(
                    color: isError ? Colors.red.shade700 : Colors.black87,
                    fontStyle: FontStyle.italic,
                    fontSize: 16,
                  ),
                  listBullet: TextStyle(
                    color: isError ? Colors.red.shade700 : Colors.black87,
                    fontSize: 16,
                  ),
                  h1: const TextStyle(
                    color: Colors.black87,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  h2: const TextStyle(
                    color: Colors.black87,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  h3: const TextStyle(
                    color: Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  blockSpacing: 8,
                ),
                selectable: true,
              ),
            if (!isUser && msg['contextUsed'] != null && (msg['contextUsed'] as List).isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 4,
                  children: (msg['contextUsed'] as List).map((ctx) => 
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF167339).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        ctx.toString(),
                        style: const TextStyle(fontSize: 10, color: Color(0xFF167339)),
                      ),
                    ),
                  ).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDot(0),
            _buildDot(1),
            _buildDot(2),
          ],
        ),
      ),
    );
  }

  Widget _buildDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 600 + (index * 200)),
      builder: (context, value, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: Color.lerp(
              Colors.grey.shade300,
              const Color(0xFF167339),
              (value * 2 > 1 ? 2 - value * 2 : value * 2),
            ),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }

  Widget _buildSuggestionChip(String text) {
    return ActionChip(
      label: Text(text),
      backgroundColor: Colors.white,
      side: const BorderSide(color: Color(0xFF167339)),
      onPressed: () {
        _controller.text = text;
        _sendMessage();
      },
    );
  }

  Widget _buildNavItem(IconData icon, bool isSelected) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: isSelected
          ? const BoxDecoration(
              color: Color(0xFF0F3C33),
              shape: BoxShape.circle,
            )
          : null,
      child: Icon(
        icon,
        color: isSelected ? const Color(0xFFAEF051) : Colors.grey[400],
        size: 28,
      ),
    );
  }
}
