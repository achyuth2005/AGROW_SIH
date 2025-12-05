import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:agroww_sih/services/sentinel2_service.dart';
import 'package:agroww_sih/screens/sidebar_drawer.dart';
import 'package:agroww_sih/screens/notification_page.dart';
import 'package:agroww_sih/screens/soil_status_detail_screen.dart';
import 'package:agroww_sih/screens/crop_status_detail_screen.dart';
import 'package:agroww_sih/screens/bio_risk_status_detail_screen.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final Completer<GoogleMapController> _mapController = Completer();
  final _supabase = Supabase.instance.client;
  final _auth = FirebaseAuth.instance;
  final PageController _carouselController = PageController();

  // State
  List<Map<String, dynamic>> _farmlands = [];
  Map<String, dynamic>? _selectedField;
  int _currentCardIndex = 0;
  bool _isLoading = true;

  // Sentinel-2 Data
  bool _isLoadingS2 = false;
  Map<String, dynamic>? _s2LlmAnalysis;
  Map<String, dynamic>? _heatmapLayers;
  Map<String, dynamic>? _trends;

  // Map Objects
  Set<Polygon> _polygons = {};
  Set<Marker> _markers = {};
  Set<Polygon> _heatmapPolygons = {};
  String? _selectedHeatmapLayer;

  static const CameraPosition _kDefaultPosition = CameraPosition(
    target: LatLng(26.1878, 91.6916),
    zoom: 15,
  );

  @override
  void initState() {
    super.initState();
    _fetchFarmlands();
  }

  @override
  void dispose() {
    _carouselController.dispose();
    super.dispose();
  }

  // --- Data Fetching ---

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
          _isLoading = false;
          if (_farmlands.isNotEmpty) {
            _selectedField = _farmlands.first;
            _updateMapForField(_selectedField!);
            _fetchSentinel2Analysis(_selectedField!);
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching farmlands: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchSentinel2Analysis(Map<String, dynamic> fieldData) async {
    if (!mounted) return;
    
    setState(() {
      _isLoadingS2 = true;
      _heatmapPolygons = {}; // Clear previous heatmaps
      _selectedHeatmapLayer = null;
    });

    // Calculate center coordinates from field corners
    double centerLat = 0, centerLon = 0;
    int count = 0;
    
    for (int i = 1; i <= 4; i++) {
      if (fieldData['lat$i'] != null && fieldData['lon$i'] != null) {
        centerLat += (fieldData['lat$i'] as num).toDouble();
        centerLon += (fieldData['lon$i'] as num).toDouble();
        count++;
      }
    }
    
    if (count > 0) {
      centerLat /= count;
      centerLon /= count;
    }
    
    final fieldSizeHa = (fieldData['area_acres'] ?? 0.04) * 0.404686;
    debugPrint('📍 Field center: ($centerLat, $centerLon), size: $fieldSizeHa ha');

    try {

      final service = Sentinel2Service();
      final result = await service.analyzeField(
        centerLat: centerLat,
        centerLon: centerLon,
        cropType: fieldData['crop_type'] ?? 'Wheat',
        analysisDate: DateTime.now().toIso8601String().split('T')[0],
        fieldSizeHectares: (fieldData['area_acres'] ?? 0.04) * 0.404686,
        farmerContext: {
          'role': 'Owner-Operator',
          'years_farming': 10,
          'irrigation_method': 'Standard',
          'farming_goal': 'Optimize Yield'
        },
      );

      if (mounted) {
        setState(() {
          _s2LlmAnalysis = {
            ...?result['llm_analysis'],
            // Include field coordinates for heatmap
            'center_lat': centerLat,
            'center_lon': centerLon,
            'field_size_hectares': fieldSizeHa,
          };
          _heatmapLayers = result['heatmap_layers'];
          _trends = result['trends'];
          _isLoadingS2 = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching Sentinel-2 analysis: $e");
      if (mounted) {
        // Still set coordinates even if S2 analysis fails
        setState(() {
          _s2LlmAnalysis = {
            'center_lat': centerLat,
            'center_lon': centerLon,
            'field_size_hectares': fieldSizeHa,
          };
          _isLoadingS2 = false;
        });
      }
    }
  }

  /// Get coordinates from selected field for heatmap
  Map<String, dynamic> _getFieldCoordinates() {
    if (_selectedField == null) return {};
    
    final field = _selectedField!;
    double centerLat = 0, centerLon = 0;
    int count = 0;
    
    for (int i = 1; i <= 4; i++) {
      if (field['lat$i'] != null && field['lon$i'] != null) {
        centerLat += (field['lat$i'] as num).toDouble();
        centerLon += (field['lon$i'] as num).toDouble();
        count++;
      }
    }
    
    if (count > 0) {
      centerLat /= count;
      centerLon /= count;
    }
    
    final fieldSizeHa = (field['area_acres'] ?? 0.04) * 0.404686;
    debugPrint('📍 Passing to detail: ($centerLat, $centerLon), size: $fieldSizeHa ha');
    
    return {
      'center_lat': centerLat,
      'center_lon': centerLon,
      'field_size_hectares': fieldSizeHa,
    };
  }

  // --- Map Helpers ---

  void _updateMapForField(Map<String, dynamic> field) async {
    final coords = _getCoordsFromFarm(field);
    if (coords.isEmpty) return;

    final Set<Polygon> polygons = {
      Polygon(
        polygonId: PolygonId(field['id'].toString()),
        points: coords,
        fillColor: Colors.transparent, // Transparent to show heatmap
        strokeColor: Colors.greenAccent,
        strokeWidth: 3,
      ),
    };

    final center = _calculateCentroid(coords);
    final Set<Marker> markers = {
      Marker(
        markerId: MarkerId('center_${field['id']}'),
        position: center,
        infoWindow: InfoWindow(
          title: field['name'] ?? 'Field',
          snippet: field['crop_type'] ?? '',
        ),
      ),
    };

    setState(() {
      _polygons = polygons;
      _markers = markers;
    });

    // Zoom to field
    final controller = await _mapController.future;
    final bounds = _getBoundsFromCoords(coords);
    controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
  }



  void _generateHeatmap(String layerName) {
    if (_heatmapLayers == null || _heatmapLayers![layerName] == null || _selectedField == null) return;

    final gridData = _heatmapLayers![layerName];
    // Handle both direct grid (List<List>) and object with 'grid' key (for stress_zones)
    final List<dynamic> rawGrid = (gridData is Map && gridData.containsKey('grid')) 
        ? gridData['grid'] 
        : gridData;
        
    if (rawGrid is! List) return;

    final coords = _getCoordsFromFarm(_selectedField!);
    final bounds = _getBoundsFromCoords(coords);
    
    final rows = rawGrid.length;
    final cols = (rawGrid.first as List).length;
    
    final latStep = (bounds.northeast.latitude - bounds.southwest.latitude) / rows;
    final lonStep = (bounds.northeast.longitude - bounds.southwest.longitude) / cols;

    Set<Polygon> newPolygons = {};

    for (int i = 0; i < rows; i++) {
      for (int j = 0; j < cols; j++) {
        final val = rawGrid[i][j];
        if (val == null) continue;

        final double value = (val as num).toDouble();
        final color = _getColorForValue(value, layerName);

        final p1 = LatLng(bounds.northeast.latitude - (i * latStep), bounds.southwest.longitude + (j * lonStep));
        final p2 = LatLng(bounds.northeast.latitude - (i * latStep), bounds.southwest.longitude + ((j + 1) * lonStep));
        final p3 = LatLng(bounds.northeast.latitude - ((i + 1) * latStep), bounds.southwest.longitude + ((j + 1) * lonStep));
        final p4 = LatLng(bounds.northeast.latitude - ((i + 1) * latStep), bounds.southwest.longitude + (j * lonStep));

        newPolygons.add(Polygon(
          polygonId: PolygonId('hm_${layerName}_${i}_$j'),
          points: [p1, p2, p3, p4],
          fillColor: color.withOpacity(0.6),
          strokeWidth: 0,
          zIndex: 2,
          consumeTapEvents: true,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${_formatLayerName(layerName)}: ${value.toStringAsFixed(2)}'),
                duration: const Duration(milliseconds: 1000),
                behavior: SnackBarBehavior.floating,
                backgroundColor: const Color(0xFF1B4D3E),
              ),
            );
          },
        ));
      }
    }

    setState(() {
      _heatmapPolygons = newPolygons;
      _selectedHeatmapLayer = layerName;
    });
  }

  String _formatLayerName(String key) {
    return key.split('_').map((word) => word[0].toUpperCase() + word.substring(1)).join(' ');
  }

  Color _getColorForValue(double value, String layerName) {
    // Customize colors based on layer type if needed
    // Default: Red (Low) -> Green (High)
    return HSVColor.fromAHSV(1.0, value * 120, 1.0, 1.0).toColor();
  }

  List<LatLng> _getCoordsFromFarm(Map<String, dynamic> farm) {
    List<LatLng> coords = [];
    for (int i = 1; i <= 4; i++) {
      if (farm['lat$i'] != null && farm['lon$i'] != null) {
        coords.add(LatLng(farm['lat$i'], farm['lon$i']));
      }
    }
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

  LatLngBounds _getBoundsFromCoords(List<LatLng> coords) {
    double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
    for (var p in coords) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F9F5),
      drawer: const SidebarDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildFieldSelector(),
            Expanded(
              child: Column(
                children: [
                  // Map Section
                  Expanded(
                    flex: 3,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _buildMap(),
                    ),
                  ),
                  // Carousel Section
                  Expanded(
                    flex: 4,
                    child: Column(
                      children: [
                        Expanded(child: _buildCarousel()),
                        _buildCarouselDots(),
                        const SizedBox(height: 8),
                        _buildExpandArrow(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Stack(
      children: [
        Image.asset(
          'assets/backsmall.png',
          width: double.infinity,
          fit: BoxFit.fitWidth,
          alignment: Alignment.topCenter,
        ),
        Positioned(
          top: 50,
          left: 16,
          right: 16,
          child: Row(
            children: [
              Builder(
                builder: (context) => GestureDetector(
                  onTap: () => Scaffold.of(context).openDrawer(),
                  child: const Icon(Icons.menu, color: Colors.white, size: 28),
                ),
              ),
              const Expanded(
                child: Text(
                  "Analytics",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NotificationPage()),
                ),
                child: const Icon(Icons.notifications_outlined, color: Colors.white, size: 26),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFieldSelector() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: Color(0xFF167339)),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Map<String, dynamic>>(
                value: _selectedField,
                hint: const Text("Select Field"),
                isExpanded: true,
                items: _farmlands.map((field) {
                  return DropdownMenuItem<Map<String, dynamic>>(
                    value: field,
                    child: Text(field['name'] ?? 'Unnamed Field'),
                  );
                }).toList(),
                onChanged: (field) {
                  if (field != null) {
                    setState(() {
                      _selectedField = field;
                      _s2LlmAnalysis = null;
                    });
                    _updateMapForField(field);
                    _fetchSentinel2Analysis(field);
                  }
                },
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.tune, color: Color(0xFF167339)),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF167339)),
      );
    }

    return Stack(
      children: [
        GoogleMap(
          mapType: MapType.hybrid,
          initialCameraPosition: _kDefaultPosition,
          onMapCreated: (controller) => _mapController.complete(controller),
          polygons: _polygons.union(_heatmapPolygons).union({
            if (_selectedHeatmapLayer != null)
              Polygon(
                polygonId: const PolygonId('dimmer'),
                points: const [
                  LatLng(85, -180),
                  LatLng(85, 180),
                  LatLng(-85, 180),
                  LatLng(-85, -180),
                ],
                fillColor: Colors.black.withOpacity(0.3),
                strokeWidth: 0,
                zIndex: 0,
              ),
          }),
          markers: _markers,
          zoomControlsEnabled: false,
          myLocationButtonEnabled: false,
        ),
        // Field Label Overlay
        if (_selectedField != null)
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _selectedField!['name'] ?? 'Field',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        // Layer Control
        Positioned(
          top: 16,
          right: 16,
          child: _buildLayerControl(),
        ),
      ],
    );
  }

  Widget _buildLayerControl() {
    return PopupMenuButton<String>(
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 4,
            ),
          ],
        ),
        child: const Icon(Icons.layers, color: Color(0xFF167339)),
      ),
      onSelected: (value) {
        if (value == 'none') {
          setState(() {
            _heatmapPolygons = {};
            _selectedHeatmapLayer = null;
          });
        } else {
          _generateHeatmap(value);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'none', child: Text('None')),
        const PopupMenuItem(value: 'greenness', child: Text('Greenness (NDVI)')),
        const PopupMenuItem(value: 'soil_moisture', child: Text('Soil Moisture')),
        const PopupMenuItem(value: 'soil_fertility', child: Text('Soil Fertility')),
        const PopupMenuItem(value: 'pest_risk', child: Text('Pest Risk')),
        const PopupMenuItem(value: 'disease_risk', child: Text('Disease Risk')),
        const PopupMenuItem(value: 'nitrogen_level', child: Text('Nitrogen Level')),
      ],
    );
  }

  Widget _buildCarousel() {
    return PageView(
      controller: _carouselController,
      onPageChanged: (index) {
        setState(() => _currentCardIndex = index);
      },
      children: [
        _buildStatusCard("Soil Status", "Soil Moisture Trend", _getSoilStatus(), "soil_moisture"),
        _buildStatusCard("Crop Status", "Crop Health Trend (NDVI)", _getPestStatus(), "ndvi"),
        _buildStatusCard("Bio-risk Status", "Pest Risk Trend", _getBioRiskStatus(), "pest_risk"),
      ],
    );
  }

  Widget _buildStatusCard(String title, String trendTitle, Map<String, dynamic> statusData, String metricKey) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Card Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF1B4D3E),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const Icon(Icons.grid_view, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          // Status Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Bad", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const Text("Moderate", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const Text("Good", style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 4),
                _buildProgressBar(statusData['score'] ?? 0.5),
              ],
            ),
          ),
          // Trend Chart Section
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trendTitle,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F3C33),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _isLoadingS2
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF167339),
                              strokeWidth: 2,
                            ),
                          )
                        : _buildTrendChart(metricKey),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildProgressBar(double score) {
    return Stack(
      children: [
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        FractionallySizedBox(
          widthFactor: score.clamp(0.0, 1.0),
          child: Container(
            height: 8,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.red,
                  Colors.orange,
                  Colors.green,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTrendChart(String metricKey) {
    final trendData = _trends?[metricKey] as List?;
    if (trendData == null || trendData.isEmpty) {
      return const Center(child: Text("No trend data available"));
    }

    List<FlSpot> spots = [];
    for (int i = 0; i < trendData.length; i++) {
      final val = (trendData[i]['value'] as num).toDouble();
      spots.add(FlSpot(i.toDouble(), val));
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: false),
        titlesData: FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (trendData.length - 1).toDouble(),
        minY: 0,
        maxY: 1.0,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: const Color(0xFF167339),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: const Color(0xFF167339).withOpacity(0.1),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final index = spot.x.toInt();
                if (index >= 0 && index < trendData.length) {
                  final date = DateTime.parse(trendData[index]['date']);
                  final dateStr = "${date.day}/${date.month}";
                  return LineTooltipItem(
                    "$dateStr\n${spot.y.toStringAsFixed(2)}",
                    const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  );
                }
                return null;
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCarouselDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        return Container(
          width: _currentCardIndex == index ? 12 : 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: _currentCardIndex == index
                ? const Color(0xFF167339)
                : Colors.grey.shade400,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  Widget _buildExpandArrow() {
    return GestureDetector(
      onTap: () {
        if (_currentCardIndex == 0) { // Soil Status
          // Get coordinates from selected field
          final fieldData = _getFieldCoordinates();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SoilStatusDetailScreen(s2Data: {...?_s2LlmAnalysis, ...fieldData}),
            ),
          );
        } else if (_currentCardIndex == 1) { // Crop Status
          final fieldData = _getFieldCoordinates();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CropStatusDetailScreen(s2Data: {...?_s2LlmAnalysis, ...fieldData}),
            ),
          );
        } else if (_currentCardIndex == 2) { // Bio-risk Status
          final fieldData = _getFieldCoordinates();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BioRiskStatusDetailScreen(s2Data: {...?_s2LlmAnalysis, ...fieldData}),
            ),
          );
        }
      },
      child: Container(
        width: 60,
        height: 24,
        decoration: BoxDecoration(
          color: const Color(0xFF1B4D3E),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        ),
        child: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 20),
      ),
    );
  }

  // --- Status Data Helpers ---

  Map<String, dynamic> _getSoilStatus() {
    final llm = _s2LlmAnalysis;
    double score = 0.5;
    if (llm != null) {
      int count = 0;
      int total = 0;
      for (var key in ['soil_moisture', 'soil_salinity', 'organic_matter', 'soil_fertility']) {
        if (llm[key]?['level'] != null) {
          String level = llm[key]['level'].toString().toLowerCase();
          if (level == 'high') total += 3;
          else if (level == 'moderate') total += 2;
          else total += 1;
          count++;
        }
      }
      if (count > 0) score = (total / (count * 3)).clamp(0.0, 1.0);
    }
    return {'score': score, 'trend': [0.4, 0.5, 0.45, 0.6, score, 0.58, 0.62]};
  }

  Map<String, dynamic> _getPestStatus() {
    final llm = _s2LlmAnalysis;
    double score = 0.5;
    if (llm != null) {
      final pestRisk = llm['Pest Rsk'] ?? llm['pest_risk'];
      if (pestRisk?['level'] != null) {
        String level = pestRisk['level'].toString().toLowerCase();
        if (level == 'low') score = 0.8;
        else if (level == 'moderate') score = 0.5;
        else score = 0.2;
      }
    }
    return {'score': score, 'trend': [0.5, 0.55, 0.5, 0.6, score, 0.55, 0.58]};
  }

  Map<String, dynamic> _getBioRiskStatus() {
    final llm = _s2LlmAnalysis;
    double score = 0.5;
    if (llm != null) {
      int count = 0;
      int total = 0;
      for (var key in ['Pest Rsk', 'pest_risk', 'Nutrient Stress', 'nutrient_stress', 'Disease Risk', 'disease_risk', 'Stress Zone', 'stress_zone']) {
        if (llm[key]?['level'] != null) {
          String level = llm[key]['level'].toString().toLowerCase();
          // For risk, low is good
          if (level == 'low') total += 3;
          else if (level == 'moderate') total += 2;
          else total += 1;
          count++;
        }
      }
      if (count > 0) score = (total / (count * 3)).clamp(0.0, 1.0);
    }
    return {'score': score, 'trend': [0.45, 0.5, 0.48, 0.55, score, 0.52, 0.55]};
  }


}


