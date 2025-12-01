import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FarmlandMapScreen extends StatefulWidget {
  const FarmlandMapScreen({super.key});

  @override
  State<FarmlandMapScreen> createState() => _FarmlandMapScreenState();
}

class _FarmlandMapScreenState extends State<FarmlandMapScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  final _supabase = Supabase.instance.client;
  final _auth = FirebaseAuth.instance;

  // State
  List<LatLng> _currentPoints = [];
  bool _isAddingField = false;
  Set<Polygon> _polygons = {};
  Set<Marker> _markers = {};
  List<Map<String, dynamic>> _farmlands = [];

  // Initial Camera Position (India center approx)
  static const CameraPosition _kIndia = CameraPosition(
    target: LatLng(20.5937, 78.9629),
    zoom: 5,
  );

  @override
  void initState() {
    super.initState();
    _fetchFarmlands();
  }

  Future<void> _fetchFarmlands() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final data = await _supabase
          .from('coordinates_quad')
          .select()
          .eq('user_id', user.uid);

      if (mounted) {
        setState(() {
          _farmlands = List<Map<String, dynamic>>.from(data);
          _updateMapObjects();
        });
      }
    } catch (e) {
      debugPrint('Error fetching farmlands: $e');
    }
  }

  void _updateMapObjects() {
    final Set<Polygon> newPolygons = {};
    final Set<Marker> newMarkers = {};

    // Existing Farmlands
    for (var farm in _farmlands) {
      // Map flat coordinates to list
      final List<LatLng> coords = [];
      if (farm['lat1'] != null && farm['lon1'] != null) coords.add(LatLng(farm['lat1'], farm['lon1']));
      if (farm['lat2'] != null && farm['lon2'] != null) coords.add(LatLng(farm['lat2'], farm['lon2']));
      if (farm['lat3'] != null && farm['lon3'] != null) coords.add(LatLng(farm['lat3'], farm['lon3']));
      if (farm['lat4'] != null && farm['lon4'] != null) coords.add(LatLng(farm['lat4'], farm['lon4']));

      if (coords.isNotEmpty) {
        final polygonId = PolygonId(farm['id'].toString());
        newPolygons.add(
          Polygon(
            polygonId: polygonId,
            points: coords,
            fillColor: Colors.green.withOpacity(0.3),
            strokeColor: Colors.greenAccent,
            strokeWidth: 2,
          ),
        );

        // Calculate centroid for label
        double latSum = 0;
        double lngSum = 0;
        for (var p in coords) {
          latSum += p.latitude;
          lngSum += p.longitude;
        }
        final center = LatLng(latSum / coords.length, lngSum / coords.length);

        newMarkers.add(
          Marker(
            markerId: MarkerId('label_${farm['id']}'),
            position: center,
            infoWindow: InfoWindow(
              title: farm['name'] ?? 'Field',
              snippet: farm['crop_type'] ?? 'Crop',
            ),
          ),
        );
      }
    }

    // Current Drawing Polygon
    if (_currentPoints.isNotEmpty) {
      newPolygons.add(
        Polygon(
          polygonId: const PolygonId('current_drawing'),
          points: _currentPoints,
          fillColor: Colors.blue.withOpacity(0.2),
          strokeColor: Colors.blue,
          strokeWidth: 2,
        ),
      );

      for (var i = 0; i < _currentPoints.length; i++) {
        newMarkers.add(
          Marker(
            markerId: MarkerId('point_$i'),
            position: _currentPoints[i],
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          ),
        );
      }
    }

    setState(() {
      _polygons = newPolygons;
      _markers = newMarkers;
    });
  }

  void _onMapTap(LatLng position) {
    if (!_isAddingField) return;

    if (_currentPoints.length < 4) {
      setState(() {
        _currentPoints.add(position);
        _updateMapObjects();
      });

      if (_currentPoints.length == 4) {
        _showSaveDialog();
      }
    }
  }

  Future<void> _showSaveDialog() async {
    final nameController = TextEditingController();
    final cropController = TextEditingController();

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Save Field'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Field Name'),
            ),
            TextField(
              controller: cropController,
              decoration: const InputDecoration(labelText: 'Crop Type'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _currentPoints.clear();
                _isAddingField = false;
                _updateMapObjects();
              });
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty && cropController.text.isNotEmpty) {
                Navigator.pop(context);
                _saveField(nameController.text, cropController.text);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveField(String name, String crop) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Ensure we have exactly 4 points
      if (_currentPoints.length != 4) return;

      final area = _calculateArea(_currentPoints);

      await _supabase.from('coordinates_quad').insert({
        'user_id': user.uid,
        'name': name,
        'crop_type': crop,
        'area_acres': area,
        'lat1': _currentPoints[0].latitude,
        'lon1': _currentPoints[0].longitude,
        'lat2': _currentPoints[1].latitude,
        'lon2': _currentPoints[1].longitude,
        'lat3': _currentPoints[2].latitude,
        'lon3': _currentPoints[2].longitude,
        'lat4': _currentPoints[3].latitude,
        'lon4': _currentPoints[3].longitude,
        // Directions are optional/derived, skipping for now or can infer
        'lat1_dir': _currentPoints[0].latitude >= 0 ? 'N' : 'S',
        'lon1_dir': _currentPoints[0].longitude >= 0 ? 'E' : 'W',
        'lat2_dir': _currentPoints[1].latitude >= 0 ? 'N' : 'S',
        'lon2_dir': _currentPoints[1].longitude >= 0 ? 'E' : 'W',
        'lat3_dir': _currentPoints[2].latitude >= 0 ? 'N' : 'S',
        'lon3_dir': _currentPoints[2].longitude >= 0 ? 'E' : 'W',
        'lat4_dir': _currentPoints[3].latitude >= 0 ? 'N' : 'S',
        'lon4_dir': _currentPoints[3].longitude >= 0 ? 'E' : 'W',
      });

      setState(() {
        _currentPoints.clear();
        _isAddingField = false;
      });
      _fetchFarmlands(); // Refresh list
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Field saved successfully!')),
        );
      }
    } catch (e) {
      debugPrint('Error saving field: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving field: $e')),
        );
      }
    }
  }

  // Simple area calculation (Shoelace formula approximation for small areas)
  // Returns acres
  double _calculateArea(List<LatLng> points) {
    if (points.length < 3) return 0;
    double area = 0.0;
    const R = 6378137.0; // Earth radius in meters

    if (points.length > 2) {
      for (var i = 0; i < points.length; i++) {
        var p1 = points[i];
        var p2 = points[(i + 1) % points.length];
        
        var x1 = p1.longitude * math.pi / 180;
        var y1 = p1.latitude * math.pi / 180;
        var x2 = p2.longitude * math.pi / 180;
        var y2 = p2.latitude * math.pi / 180;

        area += (x2 - x1) * (2 + math.sin(y1) + math.sin(y2));
      }
      area = area * R * R / 2.0;
    }
    
    return area.abs() * 0.000247105; // Convert sq meters to acres
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Google Map
          GoogleMap(
            mapType: MapType.hybrid,
            initialCameraPosition: _kIndia,
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
            },
            onTap: _onMapTap,
            polygons: _polygons,
            markers: _markers,
            zoomControlsEnabled: false,
            myLocationButtonEnabled: true,
            myLocationEnabled: true,
          ),

          // Top Bar (Search & Notes)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  // Search Bar
                  Expanded(
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 16),
                          const Icon(Icons.search, color: Colors.grey),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              decoration: const InputDecoration(
                                hintText: "Search Fields",
                                border: InputBorder.none,
                              ),
                              onChanged: (val) {
                                // Implement search filter locally if needed
                              },
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.tune, color: Colors.grey),
                            onPressed: () {},
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Create Notes Button
                  Container(
                    height: 50,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.note_add_outlined, color: Color(0xFF167339)),
                        const SizedBox(width: 8),
                        const Text(
                          "Create notes",
                          style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Back Button (Custom)
          Positioned(
            top: 60, // Below top bar
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF167339),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: const Icon(Icons.arrow_back, color: Colors.white),
              ),
            ),
          ),

          // Bottom "Add Field" Bar
          Positioned(
            bottom: 30,
            left: 16,
            right: 16,
            child: Container(
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFF1B4D3E), // Dark green
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(30),
                  onTap: () {
                    setState(() {
                      _isAddingField = !_isAddingField;
                      if (!_isAddingField) _currentPoints.clear();
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(_isAddingField 
                          ? 'Tap 4 points on the map to define the field' 
                          : 'Cancelled adding field'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isAddingField ? Icons.close : Icons.location_on_outlined,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _isAddingField ? "Cancel Adding" : "Add field",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (!_isAddingField) ...[
                        const Spacer(),
                        const Icon(Icons.add, color: Colors.white, size: 28),
                        const SizedBox(width: 20),
                      ]
                    ],
                  ),
                ),
              ),
            ),
          ).animate().slideY(begin: 1, end: 0, curve: Curves.easeOutBack),
        ],
      ),
    );
  }
}
