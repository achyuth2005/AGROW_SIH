/// ===========================================================================
/// COORDINATE ENTRY SCREEN
/// ===========================================================================
///
/// PURPOSE: Manual entry of 4-point field boundary coordinates.
///          Legacy screen for precise polygon definition.
///
/// KEY FEATURES:
///   - 4 lat/lon input pairs with N/S/E/W direction selectors
///   - Interactive Google Map for visual confirmation
///   - Tap-to-add markers on map
///   - Polygon auto-ordering to prevent self-intersection
///
/// COORDINATE LOGIC:
///   - parseCoordinate(): Converts string + direction to signed value
///   - orderAsPolygon(): Sorts points by angle from centroid
///   - Points stored with 6 decimal precision
///
/// DATA PERSISTENCE:
///   - Saves to Supabase coordinates_quad table
///   - Fields: lat1-4, lon1-4, user_id, inserted_at
///
/// NAVIGATION:
///   - Proceed → SatelliteImageScreen with polygon
///
/// DEPENDENCIES:
///   - google_maps_flutter: Map display
///   - supabase_flutter: Data storage
///   - firebase_auth: User identification
/// ===========================================================================

import 'dart:math' as Math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../analytics/mapped_report_page.dart';
import '../misc/satellite_image_screen.dart';

class CoordinateEntryScreen extends StatefulWidget {
  const CoordinateEntryScreen({super.key});

  @override
  _CoordinateEntryScreenState createState() => _CoordinateEntryScreenState();
}

class _CoordinateEntryScreenState extends State<CoordinateEntryScreen> {
  late GoogleMapController _mapController;
  final _supabase = Supabase.instance.client;
  String? _avatarUrl;

  final List<TextEditingController> latControllers =
      List.generate(4, (_) => TextEditingController());
  final List<TextEditingController> lonControllers =
      List.generate(4, (_) => TextEditingController());

  final List<String> latDirections = List.generate(4, (_) => 'N');
  final List<String> lonDirections = List.generate(4, (_) => 'E');

  List<LatLng> points = [];

  // Default center (Guwahati approx)
  static const CameraPosition _initialCameraPosition = CameraPosition(
    target: LatLng(26.18, 91.0),
    zoom: 13.0,
  );

  LatLng center = const LatLng(26.18, 91.0);

  @override
  void initState() {
    super.initState();
    _loadAvatar();
  }

  Future<void> _loadAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _avatarUrl = prefs.getString('user_avatar_url');
      });
    }
  }

  @override
  void dispose() {
    for (final c in latControllers) c.dispose();
    for (final c in lonControllers) c.dispose();
    super.dispose();
  }

  double? parseCoordinate(String value, String direction) {
    final parsed = double.tryParse(value);
    if (parsed == null) return null;
    if (direction == 'S' || direction == 'W') return -parsed.abs();
    return parsed.abs();
  }

  // Order points around centroid to avoid self-intersections
  List<LatLng> orderAsPolygon(List<LatLng> pts) {
    if (pts.length <= 2) return List.of(pts);
    final cx = pts.fold<double>(0, (s, p) => s + p.latitude) / pts.length;
    final cy = pts.fold<double>(0, (s, p) => s + p.longitude) / pts.length;
    final sorted = List<LatLng>.from(pts)
      ..sort((a, b) {
        final angA = Math.atan2(a.longitude - cy, a.latitude - cx);
        final angB = Math.atan2(b.longitude - cy, b.latitude - cx);
        return angA.compareTo(angB);
      });
    return sorted;
  }

  Future<void> _insertFourPointRow(List<LatLng> pts) async {
    if (pts.length != 4) return;
    try {
      final user = FirebaseAuth.instance.currentUser;
      final userId = user?.uid; // Nullable if not logged in, but column is nullable for now

      await _supabase.from('coordinates_quad').insert({
        'user_id': userId,
        'lat1': pts[0].latitude,
        'lon1': pts[0].longitude,
        'lat2': pts[1].latitude,
        'lon2': pts[1].longitude,
        'lat3': pts[2].latitude,
        'lon3': pts[2].longitude,
        'lat4': pts[3].latitude,
        'lon4': pts[3].longitude,
        // 'inserted_at' is handled by default now() in Postgres
      });
    } on Exception catch (e) {
      debugPrint('Insert failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Insert failed: $e')),
      );
    }
  }

  Future<List<Map<String, dynamic>>> _fetchLatest() async {
    try {
      final response = await _supabase
          .from('coordinates_quad')
          .select()
          .order('inserted_at', ascending: false)
          .limit(10);
      return List<Map<String, dynamic>>.from(response);
    } on Exception catch (e) {
      debugPrint('Fetch failed: $e');
      return [];
    }
  }

  void updatePointsFromInput() {
    final newPoints = <LatLng>[];
    for (int i = 0; i < 4; i++) {
      final latText = latControllers[i].text.trim();
      final lonText = lonControllers[i].text.trim();
      if (latText.isEmpty || lonText.isEmpty) continue;
      final lat = parseCoordinate(latText, latDirections[i]);
      final lon = parseCoordinate(lonText, lonDirections[i]);
      if (lat != null && lon != null) {
        final precisePoint = LatLng(
          double.parse(lat.toStringAsFixed(6)),
          double.parse(lon.toStringAsFixed(6)),
        );
        newPoints.add(precisePoint);
      }
    }
    setState(() {
      points = orderAsPolygon(newPoints.take(4).toList());
      if (points.isNotEmpty) {
        _mapController.moveCamera(CameraUpdate.newLatLng(points.last));
      }
    });
  }

  void onTapMap(LatLng point) {
    if (points.length >= 4) return;

    final precisePoint = LatLng(
      double.parse(point.latitude.toStringAsFixed(6)),
      double.parse(point.longitude.toStringAsFixed(6)),
    );

    setState(() {
      final appended = [...points, precisePoint];
      // Keep form fields synced to the raw tap order
      final idx = appended.length - 1;
      if (idx < 4) {
        latControllers[idx].text = precisePoint.latitude.toStringAsFixed(6);
        lonControllers[idx].text = precisePoint.longitude.toStringAsFixed(6);
        latDirections[idx] = precisePoint.latitude >= 0 ? 'N' : 'S';
        lonDirections[idx] = precisePoint.longitude >= 0 ? 'E' : 'W';
      }
      // Order for rendering stability
      points = orderAsPolygon(appended);
    });
  }

  void clearPoints() {
    setState(() {
      points = [];
      for (final c in latControllers) c.clear();
      for (final c in lonControllers) c.clear();
      for (int i = 0; i < 4; i++) {
        latDirections[i] = 'N';
        lonDirections[i] = 'E';
      }
      _mapController.moveCamera(
          CameraUpdate.newCameraPosition(_initialCameraPosition));
    });
  }

  Set<Marker> get markers => points
      .map(
        (p) => Marker(
          markerId: MarkerId(p.toString()),
          position: p,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      )
      .toSet();

  Set<Polygon> get polygons {
    if (points.length < 3) return {};
    final ordered = orderAsPolygon(points);
    return {
      Polygon(
        polygonId: const PolygonId('field_polygon'),
        points: ordered,
        fillColor: Colors.green.withOpacity(0.15),
        strokeColor: Colors.green.shade700,
        strokeWidth: 3,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final canProceed = points.length == 4;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Co-ordinate Entry',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF167339),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              final rows = await _fetchLatest();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Latest stored rows: ${rows.length}')),
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D986A), Color(0xFF167339)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.white,
                        backgroundImage: _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
                        child: _avatarUrl == null 
                            ? const Icon(Icons.person, color: Color(0xFF167339))
                            : null,
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.green.shade300,
                            borderRadius: BorderRadius.circular(25),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: const Row(
                            children: [
                              Icon(Icons.search, color: Color(0xFF167339)),
                              SizedBox(width: 8),
                              Text('Search',
                                  style: TextStyle(color: Color(0xFF167339))),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const Text(
                  'Enter Co-ordinates',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),

                // Coordinate Inputs
                Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(25),
                    gradient: const LinearGradient(
                      colors: [Colors.black, Colors.transparent],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < 4; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Lat
                              Expanded(
                                flex: 9,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.green[100],
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: TextField(
                                    controller: latControllers[i],
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    textAlignVertical: TextAlignVertical.center,
                                    decoration: InputDecoration(
                                      hintText: 'Lat ${i + 1}',
                                      border: InputBorder.none,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 14, vertical: 12),
                                      hintStyle: const TextStyle(
                                        color: Color(0xFF167339),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.black,
                                    ),
                                    onChanged: (_) => updatePointsFromInput(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              // N/S
                              Container(
                                width: 60,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 6),
                                alignment: Alignment.center,
                                child: DropdownButton<String>(
                                  value: latDirections[i],
                                  isExpanded: true,
                                  underline: const SizedBox.shrink(),
                                  onChanged: (val) {
                                    setState(() {
                                      latDirections[i] = val!;
                                    });
                                    updatePointsFromInput();
                                  },
                                  items: const [
                                    DropdownMenuItem(
                                        child: Center(child: Text('N')),
                                        value: 'N'),
                                    DropdownMenuItem(
                                        child: Center(child: Text('S')),
                                        value: 'S'),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Lon
                              Expanded(
                                flex: 9,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.green[100],
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: TextField(
                                    controller: lonControllers[i],
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    textAlignVertical: TextAlignVertical.center,
                                    decoration: InputDecoration(
                                      hintText: 'Lon ${i + 1}',
                                      border: InputBorder.none,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 14, vertical: 12),
                                      hintStyle: const TextStyle(
                                        color: Color(0xFF167339),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.black,
                                    ),
                                    onChanged: (_) => updatePointsFromInput(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              // E/W
                              Container(
                                width: 60,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 6),
                                alignment: Alignment.center,
                                child: DropdownButton<String>(
                                  value: lonDirections[i],
                                  isExpanded: true,
                                  underline: const SizedBox.shrink(),
                                  onChanged: (val) {
                                    setState(() {
                                      lonDirections[i] = val!;
                                    });
                                    updatePointsFromInput();
                                  },
                                  items: const [
                                    DropdownMenuItem(
                                        child: Center(child: Text('E')),
                                        value: 'E'),
                                    DropdownMenuItem(
                                        child: Center(child: Text('W')),
                                        value: 'W'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                // Actions
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: canProceed
                              ? () async {
                                  await _insertFourPointRow(points);
                                  if (!mounted) return;
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          SatelliteImageScreen(
                                        points: points,
                                        center: center,
                                      ),
                                    ),
                                  );
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF167339),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Proceed',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: points.isEmpty ? null : clearPoints,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          padding: const EdgeInsets.symmetric(
                              vertical: 16, horizontal: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Clear Pins',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                const Text(
                  'Select Points on Map',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600),
                ),

                // Map
                Container(
                  height: 300,
                  margin:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.green.shade900, width: 2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: GoogleMap(
                      initialCameraPosition: _initialCameraPosition,
                      mapType: MapType.normal,
                      markers: markers,
                      polygons: polygons,
                      onMapCreated: (controller) {
                        _mapController = controller;
                      },
                      onTap: onTapMap,
                      zoomControlsEnabled: true,
                      myLocationButtonEnabled: false,
                    ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
