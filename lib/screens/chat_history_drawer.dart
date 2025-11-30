import 'package:flutter/material.dart';

class ChatHistoryDrawer extends StatelessWidget {
  const ChatHistoryDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    const Color primaryDark = Color(0xFF0F3C33);
    const Color backgroundLight = Color(0xFFE8F5F3); // Light mint

    return Drawer(
      backgroundColor: backgroundLight,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Back Arrow + Search Bar
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, color: primaryDark, size: 24),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const TextField(
                        textAlignVertical: TextAlignVertical.center,
                        decoration: InputDecoration(
                          hintText: "Search for chats",
                          hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                          prefixIcon: Icon(Icons.search, color: Colors.grey, size: 20),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 10), // Removed vertical padding, handled by alignment
                          isDense: true,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              // New Chat Button
              InkWell(
                onTap: () {
                  // TODO: Handle new chat
                  Navigator.pop(context);
                },
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        border: Border.all(color: primaryDark, width: 1.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.edit_outlined, color: primaryDark, size: 20),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      "New chat",
                      style: TextStyle(
                        color: primaryDark,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // Chats Header
              const Text(
                "Chats",
                style: TextStyle(
                  color: primaryDark,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 20),

              // Chat List (Dummy Data)
              Expanded(
                child: ListView(
                  children: [
                    _buildChatItem("help my friend to grow his d...", primaryDark),
                    _buildChatItem("help my friend to grow his d...", primaryDark),
                    _buildChatItem("help my friend to grow his d...", primaryDark),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatItem(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: color.withValues(alpha: 0.8),
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Icon(Icons.delete_outline, color: color.withValues(alpha: 0.7), size: 20),
        ],
      ),
    );
  }
}
