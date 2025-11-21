// screens/full_screen_map_page.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class FullScreenMapPage extends StatefulWidget {
  const FullScreenMapPage({super.key});

  @override
  State<FullScreenMapPage> createState() => _FullScreenMapPageState();
}

class _FullScreenMapPageState extends State<FullScreenMapPage> {
  late GoogleMapController _controller;
  static const LatLng _initialCenter = LatLng(26.18, 91.0);
  static const double _initialZoom = 13;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D986A),
      appBar: AppBar(
        title: const Text('Map', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF167339),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: GoogleMap(
        initialCameraPosition: const CameraPosition(
          target: _initialCenter,
          zoom: _initialZoom,
        ),
        onMapCreated: (controller) {
          _controller = controller;
        },
        zoomControlsEnabled: true,
        myLocationButtonEnabled: false,
      ),
    );
  }
}
