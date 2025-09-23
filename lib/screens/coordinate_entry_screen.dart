import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'mapped_report_page.dart'; // Replace with your actual next page import

class CoordinateEntryScreen extends StatefulWidget {
  @override
  _CoordinateEntryScreenState createState() => _CoordinateEntryScreenState();
}

class _CoordinateEntryScreenState extends State<CoordinateEntryScreen> {
  final MapController _mapController = MapController();

  final List<TextEditingController> latControllers =
  List.generate(4, (_) => TextEditingController());
  final List<TextEditingController> lonControllers =
  List.generate(4, (_) => TextEditingController());

  final List<String> latDirections = List.generate(4, (_) => 'N');
  final List<String> lonDirections = List.generate(4, (_) => 'E');

  List<LatLng> points = [];

  double zoom = 13.0;
  LatLng center = LatLng(26.18, 91.0);

  double? parseCoordinate(String value, String direction) {
    final parsed = double.tryParse(value);
    if (parsed == null) return null;
    if (direction == 'S' || direction == 'W') return -parsed.abs();
    return parsed.abs();
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
      points = newPoints;
      if (points.isNotEmpty) {
        center = points.last;
        _mapController.move(center, zoom);
      }
    });
  }

  void onTapMap(TapPosition pos, LatLng point) {
    if (points.length >= 4) return;

    final precisePoint = LatLng(
      double.parse(point.latitude.toStringAsFixed(6)),
      double.parse(point.longitude.toStringAsFixed(6)),
    );

    setState(() {
      points = [...points, precisePoint];
      latControllers[points.length - 1].text =
          precisePoint.latitude.toStringAsFixed(6);
      lonControllers[points.length - 1].text =
          precisePoint.longitude.toStringAsFixed(6);

      latDirections[points.length - 1] =
      precisePoint.latitude >= 0 ? 'N' : 'S';
      lonDirections[points.length - 1] =
      precisePoint.longitude >= 0 ? 'E' : 'W';

      center = precisePoint;
      _mapController.move(center, zoom);
    });
  }

  void onZoomChange(double val) {
    setState(() {
      zoom = val;
      _mapController.move(center, zoom);
    });
  }

  void clearPoints() {
    setState(() {
      points = [];
      for (final c in latControllers) c.clear();
      for (final c in lonControllers) c.clear();
      center = LatLng(26.18, 91.0);
      _mapController.move(center, zoom);
    });
  }

  List<Marker> get markers => points
      .map(
        (p) => Marker(
      point: p,
      width: 30,
      height: 30,
      alignment: Alignment.center,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Offset the pin so its tip is at the point
          Transform.translate(
            offset: const Offset(0, -8),
            child: const Icon(
              Icons.location_on,
              size: 30,
              color: Colors.redAccent,
            ),
          ),
          // Exact coordinate dot
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.redAccent, width: 1),
            ),
          ),
        ],
      ),
    ),
  )
      .toList();

  List<Polygon> get polygons => points.length >= 3
      ? [
    Polygon(
      points: points,
      color: Colors.green.withOpacity(0.15),
      borderStrokeWidth: 3,
      borderColor: Colors.green.shade700,
    ),
  ]
      : [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Co-ordinate Entry',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF167339),
        iconTheme: const IconThemeData(color: Colors.white),
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
                      const CircleAvatar(
                        backgroundColor: Colors.white,
                        child: Icon(Icons.person, color: Color(0xFF167339)),
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
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MappedReportAnalysisScreen(
                                  points: points,
                                  center: center,
                                  zoom: zoom,
                                ),
                              ),
                            );
                          },
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
                  margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.green.shade900, width: 2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: center,
                        initialZoom: zoom,
                        minZoom: 5,
                        maxZoom: 18,
                        // Use interactiveFlags to support v5/v6

                        onTap: onTapMap,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                          'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                          subdomains: const ['a', 'b', 'c'],
                        ),
                        PolygonLayer(polygons: polygons),
                        MarkerLayer(markers: markers),
                      ],
                    ),
                  ),
                ),

                // Zoom slider
                Padding(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                  child: Row(
                    children: [
                      Text('Zoom: ${zoom.toStringAsFixed(1)}',
                          style: const TextStyle(color: Colors.white)),
                      Expanded(
                        child: Slider(
                          min: 5,
                          max: 18,
                          divisions: 13,
                          value: zoom,
                          onChanged: onZoomChange,
                          activeColor: Colors.green,
                          inactiveColor: Colors.grey,
                        ),
                      )
                    ],
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

// Optional bottom nav reused
class BottomNavBar extends StatelessWidget {
  const BottomNavBar({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      decoration: const BoxDecoration(
        color: Color(0xFF167339),
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: const Center(
        child: Icon(Icons.home, color: Colors.white, size: 40),
      ),
    );
  }
}
