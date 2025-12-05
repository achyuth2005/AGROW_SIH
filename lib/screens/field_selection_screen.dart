import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FieldSelectionScreen extends StatefulWidget {
  final String destination; // 'Sentinel-2' or 'SAR'

  const FieldSelectionScreen({super.key, required this.destination});

  @override
  State<FieldSelectionScreen> createState() => _FieldSelectionScreenState();
}

class _FieldSelectionScreenState extends State<FieldSelectionScreen> {
  final _supabase = Supabase.instance.client;
  final _auth = FirebaseAuth.instance;
  
  List<Map<String, dynamic>> _farmlands = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchFarmlands();
  }

  Future<void> _fetchFarmlands() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() {
          _isLoading = false;
          _error = "User not logged in";
        });
        return;
      }

      final response = await _supabase
          .from('coordinates_quad')
          .select()
          .eq('user_id', user.uid);

      if (mounted) {
        setState(() {
          _farmlands = List<Map<String, dynamic>>.from(response as List);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE1EFEF),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF167339)))
                : _error != null
                    ? Center(child: Text("Error: $_error", style: const TextStyle(color: Colors.red)))
                    : _farmlands.isEmpty
                        ? _buildEmptyState()
                        : _buildFarmlandList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Stack(
      children: [
        Image.asset(
          'assets/backsmall.png',
          width: double.infinity,
          fit: BoxFit.fitWidth,
          alignment: Alignment.topCenter,
        ),
        Positioned(
          top: 50,
          left: 20,
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Padding(
              padding: EdgeInsets.all(8.0),
              child: Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 24),
            ),
          ),
        ),
        const Positioned(
          top: 50,
          left: 0,
          right: 0,
          child: Center(
            child: Text(
              "Select Field",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.landscape, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text("No saved fields found", style: TextStyle(fontSize: 18, color: Colors.grey)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, null), // Return null for manual entry
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF167339),
              foregroundColor: Colors.white,
            ),
            child: const Text("Enter Details Manually"),
          ),
        ],
      ),
    );
  }

  Widget _buildFarmlandList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _farmlands.length + 1, // +1 for "Manual Entry" option
      itemBuilder: (context, index) {
        if (index == _farmlands.length) {
          return _buildManualEntryCard();
        }
        final field = _farmlands[index];
        return _buildFieldCard(field);
      },
    );
  }

  Widget _buildFieldCard(Map<String, dynamic> field) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFE1EFEF),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.grass, color: Color(0xFF167339)),
        ),
        title: Text(
          field['name'] ?? 'Unnamed Field',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text("Crop: ${field['crop_type'] ?? 'Unknown'}"),
            Text("Size: ${field['area_acres']?.toString() ?? '--'} acres"),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: () {
          Navigator.pop(context, field);
        },
      ),
    );
  }

  Widget _buildManualEntryCard() {
    return Card(
      margin: const EdgeInsets.only(bottom: 12, top: 12),
      color: Colors.white.withOpacity(0.8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF167339), width: 1),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: const Icon(Icons.edit_note, color: Color(0xFF167339)),
        title: const Text(
          "Enter Details Manually",
          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF167339)),
        ),
        onTap: () {
          Navigator.pop(context, null);
        },
      ),
    );
  }
}
