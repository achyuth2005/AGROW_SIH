import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'coming_soon_screen.dart'; // Update with your actual import

class CoordinateEntryScreen extends StatefulWidget {
  @override
  _CoordinateEntryScreenState createState() => _CoordinateEntryScreenState();
}

class _CoordinateEntryScreenState extends State<CoordinateEntryScreen> {
  final List<TextEditingController> _latControllers = List.generate(4, (_) => TextEditingController());
  final List<TextEditingController> _lonControllers = List.generate(4, (_) => TextEditingController());
  final List<String> _latDirections = List.generate(4, (_) => 'N');
  final List<String> _lonDirections = List.generate(4, (_) => 'E');

  List<LatLng> _points = [];

  void _onTap(TapPosition tapPosition, LatLng point) {
    if (_points.length < 4) {
      setState(() {
        _points.add(point);
        _latControllers[_points.length - 1].text = point.latitude.toStringAsFixed(6);
        _lonControllers[_points.length - 1].text = point.longitude.toStringAsFixed(6);
      });
    }
  }

  void _clearPoints() {
    setState(() {
      _points.clear();
    });
    for (var c in _latControllers) c.clear();
    for (var c in _lonControllers) c.clear();
  }

  List<Marker> get _markers => _points.asMap().entries.map((entry) {
    return Marker(
      point: entry.value,
      width: 40,
      height: 40,
      alignment: Alignment.bottomCenter,
      child: const Icon(Icons.location_on, color: Colors.redAccent, size: 38),
    );
  }).toList();

  List<Polygon> get _polygons {
    if (_points.length == 4) {
      return [
        Polygon(
          points: _points,
          color: Colors.green.withOpacity(0.3),
          borderColor: Colors.green,
          borderStrokeWidth: 3,
        )
      ];
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.white,
                        child: Icon(Icons.person, color: const Color(0xFF0D986A)),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.green.shade300,
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: Row(
                            children: const [
                              SizedBox(width: 12),
                              Icon(Icons.search, color: Color(0xFF167339)),
                              SizedBox(width: 8),
                              Text("Search", style: TextStyle(color: Color(0xFF167339))),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  "Enter Coordinates",
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w500),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
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
                    children: List.generate(4, (i) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 10,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.green[100],
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: TextField(
                                  controller: _latControllers[i],
                                  keyboardType:
                                  const TextInputType.numberWithOptions(decimal: true),
                                  decoration: InputDecoration(
                                    hintText: 'Lat ${i + 1} (e.g., 26.18)',
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 12),
                                    hintStyle: const TextStyle(
                                        color: Color(0xFF167339),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14),
                                  ),
                                  style: const TextStyle(
                                      color: Colors.black87,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              decoration: BoxDecoration(
                                  color: Colors.white, borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: DropdownButton<String>(
                                value: _latDirections[i],
                                items: const [
                                  DropdownMenuItem(value: 'N', child: Text('N')),
                                  DropdownMenuItem(value: 'S', child: Text('S')),
                                ],
                                onChanged: (val) {
                                  setState(() {
                                    _latDirections[i] = val!;
                                  });
                                },
                                underline: const SizedBox.shrink(),
                                isDense: true,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 10,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.green[100],
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: TextField(
                                  controller: _lonControllers[i],
                                  keyboardType:
                                  const TextInputType.numberWithOptions(decimal: true),
                                  decoration: InputDecoration(
                                    hintText: 'Lon ${i + 1} (e.g., 91.73)',
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 12),
                                    hintStyle: const TextStyle(
                                        color: Color(0xFF167339),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14),
                                  ),
                                  style: const TextStyle(
                                      color: Colors.black87,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              decoration: BoxDecoration(
                                  color: Colors.white, borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: DropdownButton<String>(
                                value: _lonDirections[i],
                                items: const [
                                  DropdownMenuItem(value: 'E', child: Text('E')),
                                  DropdownMenuItem(value: 'W', child: Text('W')),
                                ],
                                onChanged: (val) {
                                  setState(() {
                                    _lonDirections[i] = val!;
                                  });
                                },
                                underline: const SizedBox.shrink(),
                                isDense: true,
                              ),
                            ),
                          ],
                        ),
                      );
                    }) +
                        [
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () {
                                      Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (_) => ComingSoonScreen()));
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF167339),
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    child: const Text(
                                      "Proceed",
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                if (_points.isNotEmpty)
                                  ElevatedButton(
                                    onPressed: _clearPoints,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.redAccent,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16, horizontal: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    child: const Text(
                                      "Clear Pins",
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16),
                                    ),
                                  ),
                              ],
                            ),
                          )
                        ],
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Select Points On Map",
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 20),
                ),
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
                      options: MapOptions(
                        //center: LatLng(26.18, 91.73),
                        //zoom: 13,
                        onTap: _onTap,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                          'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                          subdomains: const ['a', 'b', 'c'],
                        ),
                        PolygonLayer(
                          polygons: _polygons,
                        ),
                        MarkerLayer(
                          markers: _markers,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const _HomeBar(),
    );
  }
}

class _HomeBar extends StatelessWidget {
  const _HomeBar({Key? key}) : super(key: key);
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
