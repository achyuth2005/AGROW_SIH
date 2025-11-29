import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:io' show Platform;
import 'mapped_report_page.dart';

class SatelliteImageScreen extends StatefulWidget {
  final List<LatLng> points;
  final LatLng center;

  const SatelliteImageScreen({
    super.key,
    required this.points,
    required this.center,
  });

  @override
  State<SatelliteImageScreen> createState() => _SatelliteImageScreenState();
}

class _SatelliteImageScreenState extends State<SatelliteImageScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  Uint8List? _imageData;
  Map<String, dynamic>? _metadata;
  Map<String, dynamic>? _bbox;
  List<dynamic>? _dimensions;

  // Default to Android Emulator IP, but allow user to change it
  String _serverUrl = Platform.isAndroid ? 'http://10.0.2.2:5001/api/satellite' : 'http://127.0.0.1:5001/api/satellite';

  @override
  void initState() {
    super.initState();
    _fetchSatelliteImage();
  }

  Future<void> _fetchSatelliteImage() async {
    try {
      // Convert LatLng points to [[lon, lat], ...] format
      final polygon = widget.points.map((p) => [p.longitude, p.latitude]).toList();
      // Close the polygon if not closed
      if (polygon.isNotEmpty && polygon.first != polygon.last) {
        polygon.add(polygon.first);
      }

      final response = await http.post(
        Uri.parse(_serverUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'polygon': polygon,
          'days_back': 30,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            _imageData = base64Decode(data['image']);
            _metadata = {
              'timestamp': data['timestamp'],
              'cloud_cover': data['cloud_cover'],
            };
            _bbox = data['bbox'];
            _dimensions = data['dimensions'];
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = data['error'] ?? 'Unknown error';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Server error: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Connection failed: $e. Make sure the Python server is running.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D986A),
      appBar: AppBar(
        title: const Text('Satellite Analysis'),
        backgroundColor: const Color(0xFF0D986A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Satellite Image Analysis',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ).animate().fadeIn().slideY(begin: -0.2, end: 0),
              
              const SizedBox(height: 20),

              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: _isLoading
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(color: Colors.white),
                              SizedBox(height: 16),
                              Text(
                                'Fetching satellite data...',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        )
                      : _errorMessage != null
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                                    const SizedBox(height: 16),
                                    Text(
                                      _errorMessage!,
                                      style: const TextStyle(color: Colors.white),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton(
                                      onPressed: () {
                                        setState(() {
                                          _isLoading = true;
                                          _errorMessage = null;
                                        });
                                        _fetchSatelliteImage();
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: const Color(0xFF0D986A),
                                      ),
                                      child: const Text('Retry'),
                                    ),
                                    const SizedBox(width: 12),
                                    ElevatedButton(
                                      onPressed: _showUrlDialog,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white.withOpacity(0.2),
                                        foregroundColor: Colors.white,
                                      ),
                                      child: const Text('Change URL'),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : Column(
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                                    child: LayoutBuilder(
                                      builder: (context, constraints) {
                                        return Stack(
                                          children: [
                                            Image.memory(
                                              _imageData!,
                                              fit: BoxFit.fill,
                                              width: double.infinity,
                                              height: double.infinity,
                                            ),
                                            if (_bbox != null && _dimensions != null)
                                              Positioned.fill(
                                                child: CustomPaint(
                                                  painter: PolygonPainter(
                                                    points: widget.points,
                                                    bbox: _bbox!,
                                                    originalWidth: _dimensions![1], // Width is at index 1
                                                    originalHeight: _dimensions![0], // Height is at index 0
                                                  ),
                                                ),
                                              ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.3),
                                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                                    children: [
                                      _buildMetadataItem(
                                        Icons.calendar_today,
                                        'Date',
                                        _metadata?['timestamp'] ?? 'N/A',
                                      ),
                                      _buildMetadataItem(
                                        Icons.cloud,
                                        'Cloud Cover',
                                        '${(_metadata?['cloud_cover'] ?? 0).toStringAsFixed(1)}%',
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ).animate().fadeIn(),
                ),
              ),

              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MappedReportAnalysisScreen(
                        points: widget.points,
                        center: widget.center,
                        zoom: 14.0,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF0D986A),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Proceed to Analytics',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2, end: 0),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetadataItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
  void _showUrlDialog() {
    final urlController = TextEditingController(text: _serverUrl);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Configure Server URL'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter the full URL (e.g., https://xyz.ngrok-free.app/api/satellite)'),
            const SizedBox(height: 10),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: 'Server URL',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _serverUrl = urlController.text.trim();
                _isLoading = true;
                _errorMessage = null;
              });
              Navigator.pop(context);
              _fetchSatelliteImage();
            },
            child: const Text('Save & Retry'),
          ),
        ],
      ),
    );
  }
}

class PolygonPainter extends CustomPainter {
  final List<LatLng> points;
  final Map<String, dynamic> bbox;
  final int originalWidth;
  final int originalHeight;

  PolygonPainter({
    required this.points,
    required this.bbox,
    required this.originalWidth,
    required this.originalHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.green.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final path = Path();

    final minLon = bbox['min_lon'];
    final maxLon = bbox['max_lon'];
    final minLat = bbox['min_lat'];
    final maxLat = bbox['max_lat'];

    // Calculate scale factors
    // The image is displayed with BoxFit.cover, so we need to account for that.
    // However, since we are inside a Stack with Positioned.fill and the Image is also filling,
    // the CustomPaint canvas size should match the rendered image size.
    // But BoxFit.cover might crop the image if aspect ratios don't match.
    // For simplicity, let's assume the container aspect ratio matches or we use BoxFit.fill/contain.
    // Actually, to be precise with BoxFit.cover, we'd need to know the source aspect ratio vs destination.
    // Let's change the Image to BoxFit.contain to ensure the whole image (and thus the whole polygon) is visible
    // and the coordinate mapping is straightforward. Or better, use BoxFit.fill if we don't care about distortion,
    // but satellite images shouldn't be distorted.
    // Let's stick to the mapping logic assuming the canvas covers the full image area.
    
    // Wait, if I use BoxFit.cover, parts of the image are hidden.
    // If I use BoxFit.contain, there might be empty space.
    // The previous code used BoxFit.cover.
    // To map correctly, I should probably use BoxFit.contain for the image so the whole bbox is visible.
    
    // Let's assume the previous code change to BoxFit.contain is done (I will do it in a separate edit if needed, 
    // but here I'll assume the canvas size represents the full image dimensions).
    // Actually, if I use BoxFit.fill, the image is stretched to fill the container.
    // Then the canvas size == container size.
    // And the mapping is simple linear interpolation.
    
    if (points.isEmpty) return;

    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      
      // Map lon/lat to 0..1 range
      final xNorm = (p.longitude - minLon) / (maxLon - minLon);
      final yNorm = (maxLat - p.latitude) / (maxLat - minLat); // Invert Y because canvas Y goes down

      final x = xNorm * size.width;
      final y = yNorm * size.height;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    canvas.drawPath(path, paint);
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
