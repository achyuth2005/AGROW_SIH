import 'dart:async';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'add_note_screen.dart';
import 'view_notes_screen.dart';

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
  List<Map<String, dynamic>> _farmlands = [];
  List<LatLng> _currentPoints = [];
  bool _isAddingField = false;
  bool _isLoading = false;

  // Map Objects
  Set<Polygon> _polygons = {};
  Set<Marker> _markers = {};

  // Initial Camera Position (IIT Guwahati)
  static const CameraPosition _kIITGuwahati = CameraPosition(
    target: LatLng(26.1878, 91.6916),
    zoom: 15,
  );

  @override
  void initState() {
    super.initState();
    _fetchFarmlands();
  }

  // --- Data Fetching & Map Updates ---

  Future<void> _fetchFarmlands() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final data = await _supabase
          .from('coordinates_quad')
          .select()
          .eq('user_id', user.uid)
          .order('id', ascending: true);

      if (mounted) {
        setState(() {
          _farmlands = List<Map<String, dynamic>>.from(data);
          _updateMapObjects();
        });
        _zoomToFitAll();
      }
    } catch (e) {
      debugPrint('Error fetching farmlands: $e');
    }
  }

  void _updateMapObjects() async {
    final Set<Polygon> newPolygons = {};
    final Set<Marker> newMarkers = {};

    // 1. Show Existing Fields (ONLY if NOT adding a new field)
    if (!_isAddingField) {
      for (var farm in _farmlands) {
        final List<LatLng> coords = _getCoordsFromFarm(farm);
        if (coords.isNotEmpty) {
          // Polygon
          newPolygons.add(Polygon(
            polygonId: PolygonId(farm['id'].toString()),
            points: coords,
            fillColor: Colors.green.withOpacity(0.3),
            strokeColor: Colors.greenAccent,
            strokeWidth: 2,
            consumeTapEvents: true,
            onTap: () => _showFieldDetails(farm),
          ));

          // Custom Text Marker with area-based scaling
          final center = _calculateCentroid(coords);
          final fieldName = farm['name'] ?? 'Field';
          final cropType = farm['crop_type'] ?? '';
          final area = farm['area_acres'] ?? _calculateArea(coords);
          
          final textIcon = await _createTextMarker(fieldName, cropType, area);
          newMarkers.add(Marker(
            markerId: MarkerId('label_${farm['id']}'),
            position: center,
            icon: textIcon,
            anchor: const Offset(0.5, 0.5),
            onTap: () => _showFieldDetails(farm),
          ));
        }
      }
    }

    // 2. Show Current Drawing (Always show if points exist)
    if (_currentPoints.isNotEmpty) {
      newPolygons.add(Polygon(
        polygonId: const PolygonId('current_drawing'),
        points: _currentPoints,
        fillColor: Colors.blue.withOpacity(0.2),
        strokeColor: Colors.blue,
        strokeWidth: 2,
      ));

      for (var i = 0; i < _currentPoints.length; i++) {
        newMarkers.add(Marker(
          markerId: MarkerId('point_$i'),
          position: _currentPoints[i],
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ));
      }
    }

    // Update State
    setState(() {
      _polygons = newPolygons;
      _markers = newMarkers;
    });
  }

  Future<void> _zoomToFitAll() async {
    if (_farmlands.isEmpty) return;

    double minLat = 90.0, maxLat = -90.0, minLng = 180.0, maxLng = -180.0;
    bool hasPoints = false;

    for (var farm in _farmlands) {
      final coords = _getCoordsFromFarm(farm);
      for (var p in coords) {
        minLat = math.min(minLat, p.latitude);
        maxLat = math.max(maxLat, p.latitude);
        minLng = math.min(minLng, p.longitude);
        maxLng = math.max(maxLng, p.longitude);
        hasPoints = true;
      }
    }

    if (hasPoints) {
      final bounds = LatLngBounds(
        southwest: LatLng(minLat, minLng),
        northeast: LatLng(maxLat, maxLng),
      );
      final controller = await _controller.future;
      controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
    }
  }

  // --- User Actions ---

  void _onMapTap(LatLng position) {
    if (!_isAddingField) return; // Only allow drawing in Add Mode

    if (_currentPoints.length < 4) {
      setState(() {
        _currentPoints.add(position);
        _updateMapObjects();
      });
    }
  }

  void _undoLastPoint() {
    if (_currentPoints.isNotEmpty) {
      setState(() {
        _currentPoints.removeLast();
        _updateMapObjects();
      });
    }
  }

  void _startAddingField() {
    setState(() {
      _isAddingField = true;
      _currentPoints.clear();
      _updateMapObjects(); // This will hide existing fields
    });
  }

  void _cancelAddingField() {
    setState(() {
      _isAddingField = false;
      _currentPoints.clear();
      _updateMapObjects(); // This will show existing fields again
    });
  }

  void _onFinishClicked() {
    if (_currentPoints.length == 4) {
      _showFieldDetailsSheet();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select 4 corners for the field.')),
      );
    }
  }

  void _showFieldDetailsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (context) => _FieldDetailsSheet(
        onSave: _saveField,
        onCancel: _cancelAddingField,
      ),
    );
  }

  Future<void> _saveField(String name, String crop) async {
    setState(() => _isLoading = true);

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final area = _calculateArea(_currentPoints);

      await _supabase.from('coordinates_quad').insert({
        'user_id': user.uid,
        'name': name,
        'crop_type': crop,
        'area_acres': area,
        'lat1': _currentPoints[0].latitude, 'lon1': _currentPoints[0].longitude,
        'lat2': _currentPoints[1].latitude, 'lon2': _currentPoints[1].longitude,
        'lat3': _currentPoints[2].latitude, 'lon3': _currentPoints[2].longitude,
        'lat4': _currentPoints[3].latitude, 'lon4': _currentPoints[3].longitude,
        // Directions (simplified logic)
        'lat1_dir': 'N', 'lon1_dir': 'E',
        'lat2_dir': 'N', 'lon2_dir': 'E',
        'lat3_dir': 'N', 'lon3_dir': 'E',
        'lat4_dir': 'N', 'lon4_dir': 'E',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Field saved successfully!')),
        );
        // RESET STATE TO INITIAL VIEW
        _cancelAddingField(); // This resets _isAddingField and re-fetches/shows all
        _fetchFarmlands(); // Ensure fresh data
      }
    } catch (e) {
      debugPrint('Error saving field: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving field: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // --- Helpers ---

  List<LatLng> _getCoordsFromFarm(Map<String, dynamic> farm) {
    List<LatLng> coords = [];
    if (farm['lat1'] != null) coords.add(LatLng(farm['lat1'], farm['lon1']));
    if (farm['lat2'] != null) coords.add(LatLng(farm['lat2'], farm['lon2']));
    if (farm['lat3'] != null) coords.add(LatLng(farm['lat3'], farm['lon3']));
    if (farm['lat4'] != null) coords.add(LatLng(farm['lat4'], farm['lon4']));
    return coords;
  }

  LatLng _calculateCentroid(List<LatLng> points) {
    double latSum = 0, lngSum = 0;
    for (var p in points) {
      latSum += p.latitude;
      lngSum += p.longitude;
    }
    return LatLng(latSum / points.length, lngSum / points.length);
  }

  double _calculateArea(List<LatLng> points) {
    if (points.length < 3) return 0;
    double area = 0.0;
    const R = 6378137.0;
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
    return area.abs() * 0.000247105; // Acres
  }

  Future<BitmapDescriptor> _createTextMarker(String fieldName, String cropType, double areaAcres) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    
    // Scale font size based on area (min: 10, max: 22 for name)
    final scaleFactor = (areaAcres / 5).clamp(0.6, 1.5);
    final nameFontSize = (16 * scaleFactor).clamp(10.0, 22.0);
    final cropFontSize = (11 * scaleFactor).clamp(8.0, 14.0);
    
    // Truncate text to prevent overflow
    final maxNameChars = (15 / scaleFactor).round();
    final maxCropChars = (18 / scaleFactor).round();
    final displayName = fieldName.length > maxNameChars ? '${fieldName.substring(0, maxNameChars)}...' : fieldName;
    final displayCrop = cropType.length > maxCropChars ? '${cropType.substring(0, maxCropChars)}...' : cropType;
    
    // Field name text painter (larger)
    final nameTextPainter = TextPainter(
      text: TextSpan(
        text: displayName,
        style: TextStyle(
          color: Colors.white,
          fontSize: nameFontSize,
          fontWeight: FontWeight.bold,
          shadows: const [
            Shadow(color: Colors.black, blurRadius: 3, offset: Offset(1, 1)),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    nameTextPainter.layout();
    
    // Crop type text painter (smaller)
    final cropTextPainter = TextPainter(
      text: TextSpan(
        text: displayCrop,
        style: TextStyle(
          color: Colors.white70,
          fontSize: cropFontSize,
          shadows: const [
            Shadow(color: Colors.black, blurRadius: 2, offset: Offset(1, 1)),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    cropTextPainter.layout();
    
    // Calculate total size
    final width = math.max(nameTextPainter.width, cropTextPainter.width) + 20;
    final height = nameTextPainter.height + cropTextPainter.height + 15;
    
    // Draw semi-transparent background
    final backgroundPaint = Paint()
      ..color = Colors.black.withOpacity(0.6)
      ..style = PaintingStyle.fill;
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, width, height),
        const Radius.circular(8),
      ),
      backgroundPaint,
    );
    
    // Draw field name
    nameTextPainter.paint(
      canvas,
      Offset((width - nameTextPainter.width) / 2, 5),
    );
    
    // Draw crop type
    if (displayCrop.isNotEmpty) {
      cropTextPainter.paint(
        canvas,
        Offset((width - cropTextPainter.width) / 2, nameTextPainter.height + 8),
      );
    }
    
    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    
    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  void _showFieldDetails(Map<String, dynamic> field) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF167339).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.agriculture, color: Color(0xFF167339), size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        field['name'] ?? 'Unnamed Field',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF167339),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        field['crop_type'] ?? 'No crop specified',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            
            // Area Info
            _buildDetailRow(
              Icons.square_foot,
              'Area',
              '${(field['area_acres'] ?? 0).toStringAsFixed(2)} acres',
            ),
            const SizedBox(height: 16),
            
            // Coordinates Info
            _buildDetailRow(
              Icons.location_on,
              'Coordinates',
              '${_getCoordsFromFarm(field).length} points',
            ),
            const SizedBox(height: 24),
            
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      // TODO: Add edit functionality
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF167339),
                      side: const BorderSide(color: Color(0xFF167339)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      // TODO: Add delete functionality
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF167339), size: 20),
        const SizedBox(width: 12),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[700],
            ),
          ),
        ),
      ],
    );
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            mapType: MapType.hybrid,
            initialCameraPosition: _kIITGuwahati,
            onMapCreated: (c) => _controller.complete(c),
            onTap: _onMapTap,
            polygons: _polygons,
            markers: _markers,
            zoomControlsEnabled: true,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            padding: EdgeInsets.only(
              top: _isAddingField ? 100 : 120,
              bottom: _isAddingField ? 100 : 100,
            ),
          ),

          // Top Bar
          if (_isAddingField)
            _buildSelectFieldTopBar()
          else
            _buildStandardTopBar(),

          // Bottom Bar
          if (_isAddingField)
            _buildUndoFinishBottomBar()
          else
            _buildAddFieldButton(),
            
          // Loading Overlay
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStandardTopBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    child: const Icon(Icons.arrow_back, color: Color(0xFF167339)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 54,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(27),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 16),
                        const Icon(Icons.search, color: Color(0xFF167339)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: "Search Fields...",
                              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 15),
                              border: InputBorder.none,
                            ),
                            onChanged: (val) {},
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.only(right: 6),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const ViewNotesScreen()),
                                );
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8F5F3),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.notes, color: Color(0xFF167339), size: 18),
                                    SizedBox(width: 6),
                                    Text(
                                      "View Notes",
                                      style: TextStyle(
                                        color: Color(0xFF167339),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectFieldTopBar() {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: Container(
        height: 110,
        padding: const EdgeInsets.only(top: 40, bottom: 20, left: 20, right: 20),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1B4D3E), Color(0xFF2E7D62)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))],
        ),
        child: Stack(
          children: [
            const Center(
              child: Text(
                "Select Field Boundaries",
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
              ),
            ),
            Positioned(
              right: 0, top: 0, bottom: 0,
              child: Center(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 20),
                    onPressed: _cancelAddingField,
                  ),
                ),
              ),
            ),
          ],
        ),
      ).animate().slideY(begin: -1, end: 0, curve: Curves.easeOut),
    );
  }

  Widget _buildAddFieldButton() {
    return Positioned(
      bottom: 40, left: 24, right: 24,
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF167339), Color(0xFF2E7D62)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF167339).withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(32),
            onTap: _startAddingField,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_location_alt_outlined, color: Colors.white, size: 26),
                SizedBox(width: 12),
                Text(
                  "Add New Field",
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                ),
              ],
            ),
          ),
        ),
      ).animate().slideY(begin: 1, end: 0, curve: Curves.easeOutBack),
    );
  }

  Widget _buildUndoFinishBottomBar() {
    return Positioned(
      bottom: 40, left: 40, right: 40,
      child: Container(
        height: 70,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(35),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: _undoLastPoint,
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(35)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.undo_rounded, color: Colors.grey[700], size: 24),
                    const SizedBox(width: 8),
                    Text("Undo", style: TextStyle(color: Colors.grey[800], fontSize: 16, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
            Container(width: 1, height: 40, color: Colors.grey[300]),
            Expanded(
              child: InkWell(
                onTap: _onFinishClicked,
                borderRadius: const BorderRadius.horizontal(right: Radius.circular(35)),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_outline_rounded, color: Color(0xFF167339), size: 24),
                    SizedBox(width: 8),
                    Text("Finish", style: TextStyle(color: Color(0xFF167339), fontSize: 16, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ).animate().slideY(begin: 1, end: 0, curve: Curves.easeOutBack),
    );
  }
}

// --- Sub-Widgets ---

class _FieldDetailsSheet extends StatefulWidget {
  final Function(String name, String crop) onSave;
  final VoidCallback onCancel;

  const _FieldDetailsSheet({required this.onSave, required this.onCancel});

  @override
  State<_FieldDetailsSheet> createState() => _FieldDetailsSheetState();
}

class _FieldDetailsSheetState extends State<_FieldDetailsSheet> {
  final TextEditingController _nameController = TextEditingController();
  String? _selectedCrop;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 20, left: 20, right: 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Field Details", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF167339))),
          const SizedBox(height: 20),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: "Field Name",
              prefixIcon: const Icon(Icons.edit, color: Color(0xFF167339)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
            ),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (c) => _CropSelectionModal(onCropSelected: (crop) {
                  setState(() => _selectedCrop = crop);
                }),
              );
            },
            borderRadius: BorderRadius.circular(15),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(15)),
              child: Row(
                children: [
                  const Icon(Icons.grass, color: Color(0xFF167339)),
                  const SizedBox(width: 12),
                  Text(_selectedCrop ?? "Select Crop", style: TextStyle(fontSize: 16, color: _selectedCrop == null ? Colors.grey[600] : Colors.black)),
                  const Spacer(),
                  const Icon(Icons.arrow_drop_down, color: Colors.grey),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onCancel();
                  },
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                  child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    if (_nameController.text.isNotEmpty && _selectedCrop != null) {
                      Navigator.pop(context);
                      widget.onSave(_nameController.text, _selectedCrop!);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter name and select crop")));
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF167339), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                  child: const Text("Save Field", style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CropSelectionModal extends StatefulWidget {
  final Function(String) onCropSelected;
  const _CropSelectionModal({required this.onCropSelected});

  @override
  State<_CropSelectionModal> createState() => _CropSelectionModalState();
}

class _CropSelectionModalState extends State<_CropSelectionModal> {
  final List<String> crops = ["Rice", "Wheat", "Maize", "Pulses", "Groundnut", "Cotton", "Jowar", "Bajra", "Sugarcane", "Mustard/Rapeseed", "Barley", "Sesame", "Chickpea", "Banana", "Coconut"];
  bool _isOtherSelected = false;
  final TextEditingController _otherController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(color: Color(0xFFE8F5F3), borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(icon: const Icon(Icons.arrow_back_ios, size: 20), onPressed: () {
                if (_isOtherSelected) setState(() => _isOtherSelected = false);
                else Navigator.pop(context);
              }),
              const Text("Select Crop", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              if (_isOtherSelected) TextButton(onPressed: () {
                if (_otherController.text.isNotEmpty) {
                  Navigator.pop(context);
                  widget.onCropSelected(_otherController.text);
                }
              }, child: const Text("Done", style: TextStyle(color: Color(0xFF167339), fontWeight: FontWeight.bold))),
              if (!_isOtherSelected) const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _isOtherSelected
                ? TextField(controller: _otherController, decoration: InputDecoration(labelText: "Enter Crop Name", border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)), prefixIcon: const Icon(Icons.edit)))
                : GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 2.5),
                    itemCount: crops.length + 1,
                    itemBuilder: (context, index) {
                      if (index == crops.length) {
                        return InkWell(
                          onTap: () => setState(() => _isOtherSelected = true),
                          child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300)), alignment: Alignment.center, child: const Text("Other", style: TextStyle(fontWeight: FontWeight.bold))),
                        );
                      }
                      return InkWell(
                        onTap: () {
                          Navigator.pop(context);
                          widget.onCropSelected(crops[index]);
                        },
                        child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300)), alignment: Alignment.center, child: Text(crops[index], style: const TextStyle(fontWeight: FontWeight.w500))),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
