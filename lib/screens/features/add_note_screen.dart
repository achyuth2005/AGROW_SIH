/// ===========================================================================
/// ADD NOTE SCREEN
/// ===========================================================================
///
/// PURPOSE: Create field-specific notes for farmer record-keeping.
///          Notes are saved to Supabase field_notes table.
///
/// KEY FEATURES:
///   - Field selector dropdown (fetches from coordinates_quad)
///   - Free-form text input with auto-save
///   - Voice/keyboard toolbar (visual placeholder)
///
/// DATA FLOW:
///   1. Fetch user's fields from Supabase coordinates_quad
///   2. User selects field (optional) and enters note
///   3. Save to Supabase field_notes with user_id and field_id
///
/// DEPENDENCIES:
///   - supabase_flutter: Data storage
///   - firebase_auth: User identification
/// ===========================================================================

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddNoteScreen extends StatefulWidget {
  const AddNoteScreen({super.key});

  @override
  State<AddNoteScreen> createState() => _AddNoteScreenState();
}

class _AddNoteScreenState extends State<AddNoteScreen> {
  final _supabase = Supabase.instance.client;
  final _auth = FirebaseAuth.instance;
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  
  bool _isLoading = false;
  List<Map<String, dynamic>> _fields = [];
  Map<String, dynamic>? _selectedField;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _fetchFields();
  }

  Future<void> _fetchFields() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final data = await _supabase
          .from('coordinates_quad')
          .select('id, name')
          .eq('user_id', user.uid)
          .order('name', ascending: true);

      if (mounted) {
        setState(() {
          _fields = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (e) {
      debugPrint('Error fetching fields: $e');
    }
  }

  Future<void> _saveNote() async {
    if (_noteController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter some content for the note.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _supabase.from('field_notes').insert({
        'user_id': user.uid,
        'field_id': _selectedField?['id'], // Nullable
        'content': _noteController.text.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Note saved successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error saving note: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving note: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showFieldSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text("Select Field", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: _fields.length,
                itemBuilder: (context, index) {
                  final field = _fields[index];
                  return ListTile(
                    title: Text(field['name'] ?? 'Unnamed Field'),
                    onTap: () {
                      setState(() {
                        _selectedField = field;
                      });
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F9F8), // Light greenish-grey background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF1B4D3E)),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          "Add Note",
          style: TextStyle(color: Color(0xFF1B4D3E), fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _saveNote,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B4D3E),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
              ),
              child: _isLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text("Save", style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              // Field Selector
              InkWell(
                onTap: _showFieldSelector,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _selectedField != null ? _selectedField!['name'] : "Search field",
                          style: TextStyle(
                            color: _selectedField != null ? Colors.black : Colors.grey,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const Icon(Icons.more_horiz, color: Colors.grey),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Note Content Area
              Container(
                height: MediaQuery.of(context).size.height * 0.5, // Fixed height instead of Expanded
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: TextField(
                  controller: _noteController,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(
                    hintText: "Start typing...",
                    border: InputBorder.none,
                  ),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 16),

              // Bottom Toolbar (Visual Only)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.keyboard, color: Colors.grey),
                    Spacer(),
                    Icon(Icons.mic_none, color: Colors.grey),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
