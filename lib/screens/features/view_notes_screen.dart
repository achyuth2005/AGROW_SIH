/// ===========================================================================
/// VIEW NOTES SCREEN
/// ===========================================================================
///
/// PURPOSE: Display all user's field notes in a searchable list.
///          Notes are linked to specific farmlands.
///
/// KEY FEATURES:
///   - Search/filter notes by field name or content
///   - Expandable note cards for long content
///   - Field name resolution from coordinates_quad table
///   - Date formatting with intl package
///   - FAB to add new notes
///
/// DATA FLOW:
///   1. Fetch notes from Supabase field_notes table
///   2. Fetch field names from coordinates_quad
///   3. Map field_id to field names for display
///   4. Support expand/collapse for long notes
///
/// DEPENDENCIES:
///   - supabase_flutter: Notes and fields data
///   - firebase_auth: User identification
///   - intl: Date formatting
/// ===========================================================================

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'add_note_screen.dart';

class ViewNotesScreen extends StatefulWidget {
  const ViewNotesScreen({super.key});

  @override
  State<ViewNotesScreen> createState() => _ViewNotesScreenState();
}

class _ViewNotesScreenState extends State<ViewNotesScreen> {
  final _supabase = Supabase.instance.client;
  final _auth = FirebaseAuth.instance;
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _notes = [];
  List<Map<String, dynamic>> _filteredNotes = [];
  bool _isLoading = true;
  Set<int> _expandedNotes = {}; // Track which notes are expanded

  @override
  void initState() {
    super.initState();
    _fetchNotes();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredNotes = _notes.where((note) {
        final fieldName = (note['title'] as String?)?.toLowerCase() ?? (note['field_name'] as String?)?.toLowerCase() ?? '';
        final content = (note['content'] as String?)?.toLowerCase() ?? '';
        return fieldName.contains(query) || content.contains(query);
      }).toList();
    });
  }

  Future<void> _fetchNotes() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Fetch notes
      final notesData = await _supabase
          .from('field_notes')
          .select()
          .eq('user_id', user.uid)
          .order('created_at', ascending: false);

      // Fetch all user's fields to map field_id to field names
      final fieldsData = await _supabase
          .from('coordinates_quad')
          .select('id, name')
          .eq('user_id', user.uid);

      // Create a map of field_id -> field_name
      final Map<String, String> fieldNames = {};
      for (final field in fieldsData) {
        final id = field['id']?.toString();
        final name = field['name'] as String?;
        if (id != null && name != null) {
          fieldNames[id] = name;
        }
      }

      // Attach field names to notes
      final notes = List<Map<String, dynamic>>.from(notesData).map((note) {
        final fieldId = note['field_id']?.toString();
        return {
          ...note,
          'field_name': fieldId != null ? fieldNames[fieldId] ?? 'General Note' : 'General Note',
        };
      }).toList();

      if (mounted) {
        setState(() {
          _notes = notes;
          _filteredNotes = _notes;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching notes: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return '';
    try {
      final date = DateTime.parse(dateString).toLocal();
      return DateFormat('MMM d').format(date);
    } catch (e) {
      return '';
    }
  }

  String _formatFullDate(String? dateString) {
    if (dateString == null) return '';
    try {
      final date = DateTime.parse(dateString).toLocal();
      return DateFormat('MMM d, yyyy • h:mm a').format(date);
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F5F3), // Light greenish background
      body: Stack(
        children: [
          // Background Image (Optional, mimicking the provided design)
          // For now, we'll use a solid color or gradient if needed, but the user image had a header image.
          // We'll stick to a clean UI as per the "Web Application Development" guidelines for now, 
          // but try to match the header style.

          Column(
            children: [
              // Custom Header
              Container(
                padding: const EdgeInsets.only(top: 50, bottom: 20, left: 20, right: 20),
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/backsmall.png'),
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                  ),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Expanded(
                          child: Center(
                            child: Text(
                              "Notes",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 48), // Balance the back button
                      ],
                    ),
                  ],
                ),
              ),

              // Search Bar
              Transform.translate(
                offset: const Offset(0, -25),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: "Search Fields",
                      prefixIcon: Icon(Icons.search, color: Colors.grey),
                      suffixIcon: Icon(Icons.tune, color: Colors.grey), // Filter icon
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
              ),

              // Notes List
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF1B4D3E)))
                    : _filteredNotes.isEmpty
                        ? const Center(
                            child: Text(
                              "No notes found",
                              style: TextStyle(color: Colors.grey, fontSize: 16),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                            itemCount: _filteredNotes.length,
                            itemBuilder: (context, index) {
                              final note = _filteredNotes[index];
                              final fieldName = note['title'] ?? note['field_name'] ?? 'Note';
                              final date = _formatDate(note['created_at']);
                              final fullDate = _formatFullDate(note['created_at']);
                              final content = note['content'] ?? '';

                              return Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.08),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Header row: Field name + date badge
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Field icon
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF1B4D3E).withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: const Icon(
                                              Icons.grass,
                                              color: Color(0xFF1B4D3E),
                                              size: 24,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          // Field name and date
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  fieldName,
                                                  style: const TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF1B4D3E),
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.access_time,
                                                      size: 14,
                                                      color: Colors.grey.shade500,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      fullDate,
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        color: Colors.grey.shade600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          // Date badge
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFAEF051).withOpacity(0.3),
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              date,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF1B4D3E),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 14),
                                      // Divider
                                      Container(
                                        height: 1,
                                        color: Colors.grey.shade200,
                                      ),
                                      const SizedBox(height: 14),
                                      // Note content - expandable
                                      GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            if (_expandedNotes.contains(index)) {
                                              _expandedNotes.remove(index);
                                            } else {
                                              _expandedNotes.add(index);
                                            }
                                          });
                                        },
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              content,
                                              maxLines: _expandedNotes.contains(index) ? null : 2,
                                              overflow: _expandedNotes.contains(index) ? null : TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 15,
                                                color: Colors.grey.shade800,
                                                height: 1.5,
                                              ),
                                            ),
                                            if (content.length > 100) ...[
                                              const SizedBox(height: 8),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    _expandedNotes.contains(index)
                                                        ? Icons.keyboard_arrow_up
                                                        : Icons.keyboard_arrow_down,
                                                    color: const Color(0xFF1B4D3E),
                                                    size: 20,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    _expandedNotes.contains(index) ? 'Show less' : 'Show more',
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                      color: Color(0xFF1B4D3E),
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddNoteScreen()),
          );
          _fetchNotes(); // Refresh list after adding
        },
        backgroundColor: const Color(0xFF1B4D3E),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
