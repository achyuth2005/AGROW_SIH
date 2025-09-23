import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class FullscreenMapScreen extends StatefulWidget {
  final List<LatLng> points;
  final double zoom;
  final LatLng center;

  const FullscreenMapScreen({
    Key? key,
    required this.points,
    required this.zoom,
    required this.center,
  }) : super(key: key);

  @override
  State<FullscreenMapScreen> createState() => _FullscreenMapScreenState();
}

class _FullscreenMapScreenState extends State<FullscreenMapScreen> {
  late final MapController _mapController;
  late double _zoom;
  late LatLng _center;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _zoom = widget.zoom;
    _center = widget.center;
  }

  @override
  Widget build(BuildContext context) {
    final List<Polygon<Object>> polygons = widget.points.length == 4
        ? <Polygon<Object>>[
      Polygon<Object>(
        points: widget.points,
        color: Colors.green.withOpacity(0.3),
        borderColor: Colors.green,
        borderStrokeWidth: 3,
      )
    ]
        : <Polygon<Object>>[];

    final markers = widget.points
        .map(
          (pt) => Marker(
        point: pt,
        width: 32,
        height: 32,
        alignment: Alignment.center,
        child: const Icon(
          Icons.location_on,
          color: Colors.red,
          size: 28,
        ),
      ),
    )
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Fullscreen Map"),
        backgroundColor: const Color(0xFF167339),
      ),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _center,
                initialZoom: _zoom,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all, // Enables all gestures including pinch zoom
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c'],
                ),
                PolygonLayer(
                  polygons: polygons,
                ),
                MarkerLayer(
                  markers: markers,
                ),
              ],
            ),
          ),
          Slider(
            label: "Zoom: ${_zoom.toStringAsFixed(1)}",
            min: 5,
            max: 18,
            divisions: 13,
            value: _zoom,
            onChanged: (value) {
              setState(() {
                _zoom = value;
                _mapController.move(_center, _zoom);
              });
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
      bottomNavigationBar: const _HomeBar(),
    );
  }
}

class _HomeBar extends StatelessWidget {
  const _HomeBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      decoration: const BoxDecoration(
        color: Color(0xFF167339),
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: const Center(
        child: Icon(
          Icons.home,
          color: Colors.white,
          size: 40,
        ),
      ),
    );
  }
}
