import 'dart:math' as Math;
import 'package:flutter/material.dart';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'manual_coordinate_entry_screen.dart';

class LocateFarmlandScreen extends StatefulWidget {
  const LocateFarmlandScreen({super.key});

  @override
  State<LocateFarmlandScreen> createState() => _LocateFarmlandScreenState();
}

class _LocateFarmlandScreenState extends State<LocateFarmlandScreen> {
  // GoogleMapController? _mapController; // Unused
  List<LatLng> _selectedPoints = [];
  
  // Default center (Guwahati approx)
  static const CameraPosition _initialCameraPosition = CameraPosition(
    target: LatLng(26.18, 91.0),
    zoom: 13.0,
  );

  void _onMapTap(LatLng point) {
    if (_selectedPoints.length < 4) {
      setState(() {
        _selectedPoints.add(point);
        _selectedPoints = _orderAsPolygon(_selectedPoints);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can only select 4 corners.')),
      );
    }
  }

  // Order points around centroid to avoid self-intersections
  List<LatLng> _orderAsPolygon(List<LatLng> pts) {
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

  void _clearPoints() {
    setState(() {
      _selectedPoints.clear();
    });
  }

  void _undoPoint() {
    if (_selectedPoints.isNotEmpty) {
      setState(() {
        _selectedPoints.removeLast();
        // Re-order remaining points if necessary, or just keep them as is.
        // If we want to maintain the polygon order logic, we might need to re-sort,
        // but removing the last added point (which was sorted) might disrupt the "last added" logic
        // if we are sorting every time.
        // However, since we sort on every add, removing the last item from the *sorted* list
        // might not be the "last added" chronologically.
        // For a simple undo, removing the last element of the current list is the expected behavior
        // for the user if they see the polygon shape.
        if (_selectedPoints.length >= 3) {
           _selectedPoints = _orderAsPolygon(_selectedPoints);
        }
      });
    }
  }

  void _navigateToEntry() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ManualCoordinateEntryScreen(
          initialPoints: _selectedPoints,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
              const Positioned(
                top: 50,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    "Locate your Farmland",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Scrollable Content Section
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Content (Now below the image)
                  // Removed as per request to move to header
                  const SizedBox(height: 10),

                  const SizedBox(height: 20),

                  // Instructions
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "How to locate?",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F3C33),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildInstructionStep(
                          "1. Tap on the map to select four corners of your farmland.",
                        ),
                        const SizedBox(height: 8),
                        _buildInstructionStep(
                          "2. Input the geographical coordinates (e.g., latitude/longitude) of your farm boundary manually.",
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 200.ms),

                  const SizedBox(height: 20),

                  // Enter Co-ordinates Button
                  Center(
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width * 0.8,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _navigateToEntry,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFAEF051),
                          foregroundColor: const Color(0xFF0F3C33),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          "Enter Co-ordinates",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ).animate().scale(delay: 300.ms),

                  const SizedBox(height: 20),

                  // Map Container
                  Container(
                    height: 500, // Increased height
                    margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5F7E76),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: Stack(
                      children: [
                        GoogleMap(
                          initialCameraPosition: _initialCameraPosition,
                          mapType: MapType.hybrid,
                          onMapCreated: (controller) {
                            // _mapController = controller;
                          },
                          onTap: _onMapTap,
                          markers: _selectedPoints.map((p) => Marker(
                            markerId: MarkerId(p.toString()),
                            position: p,
                            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                          )).toSet(),
                          polygons: _selectedPoints.length >= 3 ? {
                            Polygon(
                              polygonId: const PolygonId('field_area'),
                              points: _selectedPoints,
                              fillColor: const Color(0xFFAEF051).withValues(alpha: 0.3),
                              strokeColor: const Color(0xFFAEF051),
                              strokeWidth: 2,
                            ),
                          } : {},
                          polylines: _selectedPoints.length >= 2 && _selectedPoints.length < 4 ? {
                            Polyline(
                              polylineId: const PolylineId('field_line'),
                              points: _selectedPoints,
                              color: Colors.white,
                              width: 3,
                            ),
                          } : {},
                          zoomControlsEnabled: true,
                          myLocationButtonEnabled: false,
                          zoomGesturesEnabled: true,
                          scrollGesturesEnabled: true,
                          rotateGesturesEnabled: true,
                          tiltGesturesEnabled: true,
                        ),
                        if (_selectedPoints.isNotEmpty)
                          Positioned(
                            bottom: 16,
                            left: 16, // Moved to left
                            child: Row(
                              children: [
                                FloatingActionButton(
                                  mini: true,
                                  heroTag: 'clear_btn',
                                  backgroundColor: Colors.redAccent,
                                  onPressed: _clearPoints,
                                  child: const Icon(Icons.clear, color: Colors.white),
                                ),
                                const SizedBox(width: 12),
                                FloatingActionButton(
                                  mini: true,
                                  heroTag: 'undo_btn',
                                  backgroundColor: Colors.orangeAccent,
                                  onPressed: _undoPoint,
                                  child: const Icon(Icons.undo, color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2, end: 0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionStep(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        color: Color(0xFF0F3C33),
        height: 1.4,
      ),
    );
  }
}


