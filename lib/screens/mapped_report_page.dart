import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MappedReportAnalysisScreen extends StatefulWidget {
  final List<LatLng> points; // pass selected pins
  final LatLng center;       // pass last center
  final double zoom;         // pass last zoom

  const MappedReportAnalysisScreen({
    Key? key,
    required this.points,
    required this.center,
    required this.zoom,
  }) : super(key: key);

  @override
  State<MappedReportAnalysisScreen> createState() => _MappedReportAnalysisScreenState();
}

class _MappedReportAnalysisScreenState extends State<MappedReportAnalysisScreen> {
  late final MapController _mapController;
  late List<LatLng> _points;
  late LatLng _center;
  late double _zoom;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _points = _sanitizePoints(widget.points);
    _center = widget.center;
    _zoom = widget.zoom;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_points.length >= 3) {
        _fitToPolygon(_points);
      } else {
        _mapController.move(_center, _zoom);
      }
    });
  }

  List<LatLng> _sanitizePoints(List<LatLng> pts) {
    final seen = <String>{};
    final out = <LatLng>[];
    for (final p in pts) {
      // Use higher precision (8 decimal places) to maintain accuracy
      // 8 decimal places gives ~1.1 meter accuracy at the equator
      final lat = double.parse(p.latitude.toStringAsFixed(8));
      final lon = double.parse(p.longitude.toStringAsFixed(8));
      final key = '$lat,$lon';
      if (seen.contains(key)) continue;
      seen.add(key);
      out.add(LatLng(lat, lon));
    }
    return out;
  }

  void _fitToPolygon(List<LatLng> pts) {
    double minLat = pts.first.latitude, maxLat = pts.first.latitude;
    double minLon = pts.first.longitude, maxLon = pts.first.longitude;
    for (final p in pts) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLon) minLon = p.longitude;
      if (p.longitude > maxLon) maxLon = p.longitude;
    }
    final sw = LatLng(minLat, minLon);
    final ne = LatLng(maxLat, maxLon);
    try {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds(sw, ne),
          padding: const EdgeInsets.all(32), // Increased padding for better view
        ),
      );
      _center = LatLng((minLat + maxLat) / 2.0, (minLon + maxLon) / 2.0);
    } catch (_) {
      _center = LatLng((minLat + maxLat) / 2.0, (minLon + maxLon) / 2.0);
      _mapController.move(_center, 14);
    }
  }

  List<Marker> get _markers => _points
      .map((pt) => Marker(
    point: pt,
    width: 24,
    height: 24,
    alignment: Alignment.center, // Changed to center for better accuracy
    child: Container(
      decoration: BoxDecoration(
        color: Colors.redAccent,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Icon(
        Icons.place,
        size: 16,
        color: Colors.white,
      ),
    ),
  ))
      .toList();

  List<Polygon> get _polygons => _points.length >= 3
      ? [
    Polygon(
      points: _points,
      color: Colors.green.withOpacity(0.25),
      borderColor: Colors.green,
      borderStrokeWidth: 2.0,
    ),
  ]
      : [];

  @override
  Widget build(BuildContext context) {
    Widget analyticsCard(String heading, String desc) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green.shade100.withOpacity(0.95),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(heading,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF167339))),
            const SizedBox(height: 6),
            Text(desc, style: const TextStyle(color: Color(0xFF167339))),
          ],
        ),
      );
    }

    final hasPolygon = _points.length >= 3;

    return Scaffold(
      backgroundColor: const Color(0xFF0D986A),
      appBar: AppBar(
        title: const Text("Mapped Detecting & Report Analysis"),
        backgroundColor: const Color(0xFF167339),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.all(18),
              clipBehavior: Clip.hardEdge,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: SizedBox(
                height: 220, // Increased height for better visibility
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _center,
                    initialZoom: _zoom,
                    minZoom: 5,
                    maxZoom: 20, // Increased max zoom for better accuracy verification
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                      subdomains: const ['a', 'b', 'c'],
                    ),
                    // Draw polygon first (underneath markers)
                    if (hasPolygon) PolygonLayer(polygons: _polygons),
                    // Draw markers on top
                    if (_markers.isNotEmpty) MarkerLayer(markers: _markers),
                  ],
                ),
              ),
            ),
            // Accuracy info card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade100.withOpacity(0.95),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Pins mark polygon corners with ${_points.length >= 3 ? '8-decimal' : 'high'} precision",
                      style: const TextStyle(color: Colors.blue, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                children: [
                  analyticsCard("Crop Health Status",
                      "Field shows moderate NDVI. Healthy with mild stress detected on NE boundary."),
                  analyticsCard("Pest Risk Alert",
                      "CNN model detected moderate risk zone on southern edge. Inspect early signs."),
                  analyticsCard("Soil Condition",
                      "Moisture 18-22%. Nutrient levels in safe zone. Consider slow-release fertilizer."),
                  analyticsCard("Yield Prediction",
                      "Projected 3.8 tons/hectare, 4% above regional mean."),
                  analyticsCard("Water Scheduling",
                      "Soil moisture optimal; no irrigation needed next 2 days."),
                  analyticsCard("Insurance Insight",
                      "Minimal storm risk this week based on satellite data."),
                  analyticsCard("NOTE",
                      "THIS IS DEMO DATA FOR SMART INDIA HACKATHON 2025. Refer to the deck for terms/methodology."),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 20, top: 8),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 28),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "Back to dashboard...",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}