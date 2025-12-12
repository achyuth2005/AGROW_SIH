/// ===========================================================================
/// MANUAL COORDINATE ENTRY SCREEN
/// ===========================================================================
///
/// PURPOSE: Second step in farmland registration - refine coordinates and
///          add field metadata (name, crop type, calculated area).
///
/// KEY FEATURES:
///   - 4 lat/lon inputs with N/S/E/W direction dropdowns
///   - Field name and crop type selection (16 crops including "Other")
///   - Automatic area calculation using Shoelace formula
///   - Pre-population from LocateFarmlandScreen map selection
///
/// AREA CALCULATION:
///   - _calculateArea(): Uses Shoelace algorithm with Earth radius
///   - Converts square meters to acres for display
///
/// DATA PERSISTENCE:
///   - Saves to Supabase coordinates_quad with all metadata
///   - Links to Firebase user via user_id field
///
/// NAVIGATION:
///   - Submit → /main-menu (clears stack)
///
/// DEPENDENCIES:
///   - google_maps_flutter: LatLng type
///   - supabase_flutter: Data storage
///   - firebase_auth: User identification
///   - LocalizationProvider: i18n text
/// ===========================================================================

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'dart:math' as Math;
import 'package:agroww_sih/widgets/custom_bottom_nav_bar.dart';
import 'package:agroww_sih/services/localization_service.dart';


class ManualCoordinateEntryScreen extends StatefulWidget {
  final List<LatLng> initialPoints;

  const ManualCoordinateEntryScreen({
    super.key,
    this.initialPoints = const [],
  });

  @override
  State<ManualCoordinateEntryScreen> createState() => _ManualCoordinateEntryScreenState();
}

class _ManualCoordinateEntryScreenState extends State<ManualCoordinateEntryScreen> {
  final _supabase = Supabase.instance.client;
  final List<TextEditingController> _latControllers = [];
  final List<TextEditingController> _lonControllers = [];
  final List<String> _latDirections = []; // 'N' or 'S'
  final List<String> _lonDirections = []; // 'E' or 'W'
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _otherCropController = TextEditingController();
  String? _selectedCrop;
  final List<String> _crops = [
    "Rice", "Wheat", "Maize", "Pulses", "Groundnut", "Cotton", 
    "Jowar", "Bajra", "Sugarcane", "Mustard/Rapeseed", "Barley", 
    "Sesame", "Chickpea", "Banana", "Coconut", "Other"
  ];
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Initialize controllers for 4 points
    for (int i = 0; i < 4; i++) {
      double lat = 0;
      double lon = 0;
      String latDir = 'N';
      String lonDir = 'E';

      if (i < widget.initialPoints.length) {
        lat = widget.initialPoints[i].latitude;
        lon = widget.initialPoints[i].longitude;
        
        if (lat < 0) {
          latDir = 'S';
          lat = lat.abs();
        }
        if (lon < 0) {
          lonDir = 'W';
          lon = lon.abs();
        }
      }

      _latControllers.add(TextEditingController(text: lat == 0 ? '' : lat.toStringAsFixed(6)));
      _lonControllers.add(TextEditingController(text: lon == 0 ? '' : lon.toStringAsFixed(6)));
      _latDirections.add(latDir);
      _lonDirections.add(lonDir);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _otherCropController.dispose();
    for (var c in _latControllers) c.dispose();
    for (var c in _lonControllers) c.dispose();
    super.dispose();
  }

  double _calculateArea(List<LatLng> points) {
    if (points.length < 3) return 0.0;
    double area = 0.0;
    const double earthRadius = 6371000; // meters

    for (int i = 0; i < points.length; i++) {
      final p1 = points[i];
      final p2 = points[(i + 1) % points.length];

      final x1 = p1.longitude * (Math.pi / 180) * earthRadius * Math.cos(p1.latitude * (Math.pi / 180));
      final y1 = p1.latitude * (Math.pi / 180) * earthRadius;
      final x2 = p2.longitude * (Math.pi / 180) * earthRadius * Math.cos(p2.latitude * (Math.pi / 180));
      final y2 = p2.latitude * (Math.pi / 180) * earthRadius;

      area += (x1 * y2) - (x2 * y1);
    }
    
    final areaSqMeters = area.abs() / 2.0;
    return areaSqMeters * 0.000247105; // Convert to acres
  }

  Future<void> _submitCoordinates() async {
    setState(() => _isSubmitting = true);

    try {
      final points = <LatLng>[];
      for (int i = 0; i < 4; i++) {
        double? lat = double.tryParse(_latControllers[i].text.trim());
        double? lon = double.tryParse(_lonControllers[i].text.trim());
        
        if (lat == null || lon == null) {
          throw Exception("Invalid coordinates for Point ${i + 1}");
        }

        // Apply direction
        if (_latDirections[i] == 'S') lat = -lat;
        if (_lonDirections[i] == 'W') lon = -lon;

        points.add(LatLng(lat, lon));
      }

      if (_nameController.text.trim().isEmpty) {
        throw Exception("Please enter a field name");
      }
      if (_selectedCrop == null) {
        throw Exception("Please select a crop type");
      }
      
      String finalCrop = _selectedCrop!;
      if (_selectedCrop == 'Other') {
        if (_otherCropController.text.trim().isEmpty) {
          throw Exception("Please enter the crop name");
        }
        finalCrop = _otherCropController.text.trim();
      }

      // Calculate Area
      final areaAcres = _calculateArea(points);

      // Get current user ID
      final user = firebase_auth.FirebaseAuth.instance.currentUser;
      final prefs = await SharedPreferences.getInstance();
      final guestId = prefs.getString('guest_user_id');
      
      final userId = user?.uid ?? guestId;
      if (userId == null) {
        throw Exception("No user ID found. Please log in again.");
      }

      // Insert into Supabase
      final insertData = {
        'user_id': userId, // CRITICAL: This links the farmland to the user
        'name': _nameController.text.trim(),
        'crop_type': finalCrop,
        'area_acres': areaAcres,
        'lat1': points[0].latitude.abs(),
        'lat1_dir': _latDirections[0],
        'lon1': points[0].longitude.abs(),
        'lon1_dir': _lonDirections[0],
        
        'lat2': points[1].latitude.abs(),
        'lat2_dir': _latDirections[1],
        'lon2': points[1].longitude.abs(),
        'lon2_dir': _lonDirections[1],
        
        'lat3': points[2].latitude.abs(),
        'lat3_dir': _latDirections[2],
        'lon3': points[2].longitude.abs(),
        'lon3_dir': _lonDirections[2],
        
        'lat4': points[3].latitude.abs(),
        'lat4_dir': _latDirections[3],
        'lon4': points[3].longitude.abs(),
        'lon4_dir': _lonDirections[3],
      };
      
      debugPrint("Inserting data: $insertData");

      await _supabase.from('coordinates_quad').insert(insertData);

      if (!mounted) return;

      // Go directly to HomePage and clear navigation stack
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Field added successfully!'), backgroundColor: Color(0xFF0D986A)),
      );
      
      // Navigate to HomePage and remove all previous routes
      Navigator.pushNamedAndRemoveUntil(
        context, 
        '/main-menu', 
        (route) => false, // Remove all routes
      );

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F5F3), // Light mint background
      bottomNavigationBar: const CustomBottomNavBar(selectedIndex: 4),
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
                // Header content with SafeArea
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 0.0),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Expanded(
                          child: Builder(
                            builder: (context) {
                              final loc = context.watch<LocalizationProvider>();
                              return Text(
                                loc.tr('your_fields'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                ),

                // Content Section
                Expanded(
            child: Column(
              children: [
                // Header Title
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFAEF051),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Builder(
                        builder: (context) {
                          final loc = context.watch<LocalizationProvider>();
                          return Text(
                            loc.tr('enter_coordinates'),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F3C33),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Main Form Container
                Flexible(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(20, 10, 20, 40), // Increased bottom margin
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5F7E76),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Field Details Section
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withOpacity(0.2)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Builder(
                                  builder: (context) {
                                    final loc = context.watch<LocalizationProvider>();
                                    return Text(
                                      loc.tr('field_details'),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 16),
                                // Name Input
                                Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF0F5F3),
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: TextField(
                                    controller: _nameController,
                                    decoration: InputDecoration(
                                      hintText: "Enter Field Name",
                                      hintStyle: TextStyle(color: Colors.grey[600]),
                                      prefixIcon: const Icon(Icons.edit, color: Color(0xFF0F3C33)),
                                      border: InputBorder.none,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                // Crop Dropdown
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF0F5F3),
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _selectedCrop,
                                      hint: Text("Select Crop Type", style: TextStyle(color: Colors.grey[600])),
                                      isExpanded: true,
                                      icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF0F3C33)),
                                      items: _crops.map((String crop) {
                                        return DropdownMenuItem<String>(
                                          value: crop,
                                          child: Text(crop, style: const TextStyle(color: Colors.black87)),
                                        );
                                      }).toList(),
                                      onChanged: (val) => setState(() => _selectedCrop = val),
                                    ),
                                  ),
                                ),
                                if (_selectedCrop == 'Other') ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF0F5F3),
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    child: TextField(
                                      controller: _otherCropController,
                                      decoration: InputDecoration(
                                        hintText: "Enter Crop Name",
                                        hintStyle: TextStyle(color: Colors.grey[600]),
                                        prefixIcon: const Icon(Icons.grass, color: Color(0xFF0F3C33)),
                                        border: InputBorder.none,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 24),

                          for (int i = 0; i < 4; i++)
                            _buildPointRow(i),
                          
                          const SizedBox(height: 20),

                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _isSubmitting ? null : _submitCoordinates,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFAEF051),
                                foregroundColor: const Color(0xFF0F3C33),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                              ),
                              child: _isSubmitting
                                  ? const CircularProgressIndicator(color: Color(0xFF0F3C33))
                                  : const Text(
                                      "Submit",
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
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

  Widget _buildPointRow(int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Point Label Box
          Container(
            width: 80,
            height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFFAEF051), // Lime Green
              borderRadius: BorderRadius.circular(20),
            ),
            alignment: Alignment.center,
            child: Text(
              "Point ${index + 1}",
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F3C33),
              ),
            ),
          ),
          const SizedBox(width: 12),
          
          // Inputs Column
          Expanded(
            child: Column(
              children: [
                _buildInputRow(
                  _latControllers[index], 
                  "Lat", 
                  _latDirections[index], 
                  ['N', 'S'],
                  (val) => setState(() => _latDirections[index] = val!),
                ),
                const SizedBox(height: 8),
                _buildInputRow(
                  _lonControllers[index], 
                  "Lon", 
                  _lonDirections[index], 
                  ['E', 'W'],
                  (val) => setState(() => _lonDirections[index] = val!),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputRow(
    TextEditingController controller, 
    String hint, 
    String currentDir, 
    List<String> options,
    ValueChanged<String?> onChanged,
  ) {
    return Row(
      children: [
        // Text Field
        Expanded(
          child: Container(
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFF0F5F3),
              borderRadius: BorderRadius.circular(23),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.centerLeft,
            child: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Dropdown
        Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F5F3),
            borderRadius: BorderRadius.circular(23),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: currentDir,
              items: options.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F3C33),
                    ),
                  ),
                );
              }).toList(),
              onChanged: onChanged,
              icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF0F3C33)),
            ),
          ),
        ),
      ],
    );
  }
}


