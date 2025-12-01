import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'satellite_image_screen.dart';

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
    for (var c in _latControllers) c.dispose();
    for (var c in _lonControllers) c.dispose();
    super.dispose();
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

      // Insert into Supabase
      final insertData = {
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

      // Calculate center for next screen
      double latSum = 0, lonSum = 0;
      for (var p in points) {
        latSum += p.latitude;
        lonSum += p.longitude;
      }
      final center = LatLng(latSum / 4, lonSum / 4);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SatelliteImageScreen(
            points: points,
            center: center,
          ),
        ),
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
      body: Column(
        children: [
          // Header Section with Back Button
          Stack(
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
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                  ),
                ),
              ),
            ],
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
                      child: const Text(
                        "Enter Co-ordinates",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F3C33),
                        ),
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


